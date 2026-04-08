import json
import os
import re
import subprocess
from pathlib import Path

import agent


ENVIRONMENT_FILE = "environment"
SHARED_SECRETS_ENVFILE = "secrets.env"
SYSTEMD_ENVFILE = "systemd.env"
LEGACY_AGENTS_ENVFILE = "agents.env"
LEGACY_SMARTHOST_ENVFILE = "smarthost.env"
ALLOWED_ROLES = {"default", "developer"}
ALLOWED_STATUSES = {"start", "stop"}
NAME_PATTERN = re.compile(r"^[A-Za-z ]+$")
AGENT_ENVFILE_PATTERN = re.compile(r"^agent-(\d+)\.env$")
AGENT_SECRETS_ENVFILE_PATTERN = re.compile(r"^agent-(\d+)_secrets\.env$")
AGENT_OPENVIKING_CONFIG_PATTERN = re.compile(r"^agent-(\d+)_openviking\.conf$")
SYSTEMD_TARGET_PATTERN = re.compile(r"^hermes-agent@(\d+)\.target$")
OPENVIKING_CONFIG_PATH = "/app/ov.conf"
OPENVIKING_WORKSPACE_PATH = "/app/data"
SMTP_PUBLIC_KEYS = (
    "SMTP_ENABLED",
    "SMTP_HOST",
    "SMTP_PORT",
    "SMTP_USERNAME",
    "SMTP_ENCRYPTION",
    "SMTP_TLSVERIFY",
)
SMTP_SECRET_KEYS = ("SMTP_PASSWORD",)


def validate_agents(raw_agents):
    if raw_agents is None:
        return []

    if not isinstance(raw_agents, list):
        raise ValueError("agents must be a list")

    normalized_agents = []
    seen_ids = set()

    for index, raw_agent in enumerate(raw_agents):
        if not isinstance(raw_agent, dict):
            raise ValueError(f"agent at index {index} must be an object")

        agent_id = raw_agent.get("id")
        if not isinstance(agent_id, int) or agent_id < 1:
            raise ValueError(f"agent at index {index} has an invalid id")
        if agent_id in seen_ids:
            raise ValueError(f"agent id {agent_id} is duplicated")

        name = raw_agent.get("name")
        if not isinstance(name, str):
            raise ValueError(f"agent at index {index} has an invalid name")
        name = name.strip()
        if not name or not NAME_PATTERN.fullmatch(name):
            raise ValueError(f"agent at index {index} has an invalid name")

        role = raw_agent.get("role")
        if role not in ALLOWED_ROLES:
            raise ValueError(f"agent at index {index} has an invalid role")

        status = raw_agent.get("status")
        if status not in ALLOWED_STATUSES:
            raise ValueError(f"agent at index {index} has an invalid status")

        normalized_agents.append(
            {
                "id": agent_id,
                "name": name,
                "role": role,
                "status": status,
            }
        )
        seen_ids.add(agent_id)

    return sorted(normalized_agents, key=lambda item: item["id"])


def serialize_agents(agents):
    return ",".join(
        f"{agent_data['id']}:{agent_data['name']}:{agent_data['role']}:{agent_data['status']}"
        for agent_data in sorted(agents, key=lambda item: item["id"])
    )


def parse_agents_list(raw_agents_list):
    if not raw_agents_list:
        return []

    agents = []
    seen_ids = set()
    for raw_agent in raw_agents_list.split(","):
        serialized_agent = raw_agent.strip()
        if not serialized_agent:
            continue

        parts = serialized_agent.split(":", 3)
        if len(parts) == 3:
            agent_id, name, role = parts
            status = "start"
        elif len(parts) == 4:
            agent_id, name, role, status = parts
        else:
            raise ValueError(f"invalid AGENTS_LIST entry: {serialized_agent}")

        normalized_name = name.strip()

        if not agent_id.isdigit() or int(agent_id) < 1:
            raise ValueError(f"invalid AGENTS_LIST id: {agent_id}")

        normalized_id = int(agent_id)
        if normalized_id in seen_ids:
            raise ValueError(f"duplicated AGENTS_LIST id: {agent_id}")
        if not normalized_name or not NAME_PATTERN.fullmatch(normalized_name):
            raise ValueError(f"invalid AGENTS_LIST name: {name}")
        if role not in ALLOWED_ROLES:
            raise ValueError(f"invalid AGENTS_LIST role: {role}")
        if status not in ALLOWED_STATUSES:
            raise ValueError(f"invalid AGENTS_LIST status: {status}")

        agents.append(
            {
                "id": normalized_id,
                "name": normalized_name,
                "role": role,
                "status": status,
            }
        )
        seen_ids.add(normalized_id)

    return sorted(agents, key=lambda item: item["id"])


def read_optional_envfile(path):
    if not os.path.exists(path):
        return {}

    return agent.read_envfile(path)


def read_agents_list():
    agents_list = read_optional_envfile(ENVIRONMENT_FILE).get("AGENTS_LIST")
    if agents_list is not None:
        return agents_list

    legacy_agents_list = read_optional_envfile(LEGACY_AGENTS_ENVFILE).get("AGENTS_LIST")
    if legacy_agents_list is not None:
        return legacy_agents_list

    return ""


def read_agents_from_state():
    return parse_agents_list(read_agents_list())


def persist_agents(agents):
    agent.set_env("AGENTS_LIST", serialize_agents(agents))
    if os.path.exists(LEGACY_AGENTS_ENVFILE):
        os.remove(LEGACY_AGENTS_ENVFILE)


def agent_envfile(agent_id):
    return f"agent-{agent_id}.env"


def agent_secrets_envfile(agent_id):
    return f"agent-{agent_id}_secrets.env"


def agent_openviking_configfile(agent_id):
    return f"agent-{agent_id}_openviking.conf"


def pod_name(agent_id):
    return f"hermes-agent-{agent_id}"


def hermes_data_volume(agent_id):
    return f"hermes-agent-hermes-data-{agent_id}"


def openviking_data_volume(agent_id):
    return f"hermes-agent-openviking-data-{agent_id}"


def target_unit(agent_id):
    return f"hermes-agent@{agent_id}.target"


def pod_service_unit(agent_id):
    return f"hermes-agent-pod@{agent_id}.service"


def container_service_units(agent_id):
    return [
        f"hermes-agent-openviking@{agent_id}.service",
        f"hermes-agent-hermes@{agent_id}.service",
        f"hermes-agent-gateway@{agent_id}.service",
    ]


def managed_service_units(agent_id):
    return [pod_service_unit(agent_id), *container_service_units(agent_id)]


def run_command(command, check=True, capture_output=False):
    return subprocess.run(
        command,
        check=check,
        text=True,
        stdout=subprocess.PIPE if capture_output else None,
        stderr=subprocess.PIPE if capture_output else None,
    )


def systemctl_user(*args, check=True, capture_output=False):
    return run_command(
        ["systemctl", "--user", *args],
        check=check,
        capture_output=capture_output,
    )


def unit_is_active(unit_name):
    return systemctl_user("is-active", "--quiet", unit_name, check=False).returncode == 0


def list_systemd_agent_ids():
    ids = set()
    commands = [
        ["list-unit-files", "--type=target", "--all", "hermes-agent@*.target", "--no-legend", "--plain"],
        ["list-units", "--type=target", "--all", "hermes-agent@*.target", "--no-legend", "--plain"],
    ]

    for command in commands:
        result = systemctl_user(*command, check=False, capture_output=True)
        if not result.stdout:
            continue

        for line in result.stdout.splitlines():
            match = SYSTEMD_TARGET_PATTERN.match(line.strip().split()[0])
            if match:
                ids.add(int(match.group(1)))

    return ids


def scan_generated_agent_ids(base_path="."):
    ids = set()
    for path in Path(base_path).glob("agent-*.env"):
        match = AGENT_ENVFILE_PATTERN.fullmatch(path.name)
        if match:
            ids.add(int(match.group(1)))
            continue

        match = AGENT_SECRETS_ENVFILE_PATTERN.fullmatch(path.name)
        if match:
            ids.add(int(match.group(1)))

        match = AGENT_OPENVIKING_CONFIG_PATTERN.fullmatch(path.name)
        if match:
            ids.add(int(match.group(1)))

    for path in Path(base_path).glob("agent-*_secrets.env"):
        match = AGENT_SECRETS_ENVFILE_PATTERN.fullmatch(path.name)
        if match:
            ids.add(int(match.group(1)))

    for path in Path(base_path).glob("agent-*_openviking.conf"):
        match = AGENT_OPENVIKING_CONFIG_PATTERN.fullmatch(path.name)
        if match:
            ids.add(int(match.group(1)))

    return ids


def list_known_agent_ids(base_path="."):
    return sorted(scan_generated_agent_ids(base_path) | list_systemd_agent_ids())


def write_envfile(path, env_data):
    if env_data:
        agent.write_envfile(path, env_data)
        return

    Path(path).write_text("", encoding="utf-8")


def write_jsonfile(path, data):
    Path(path).write_text(f"{json.dumps(data, indent=2)}\n", encoding="utf-8")


def build_agent_public_env(agent_data, shared_environment):
    env_data = {
        "AGENT_ID": str(agent_data["id"]),
        "AGENT_NAME": agent_data["name"],
        "AGENT_ROLE": agent_data["role"],
        "AGENT_STATUS": agent_data["status"],
    }

    module_id = os.environ.get("MODULE_ID")
    if module_id:
        env_data["MODULE_ID"] = module_id

    for key in SMTP_PUBLIC_KEYS:
        value = shared_environment.get(key)
        if value is not None:
            env_data[key] = value

    return env_data


def build_agent_secrets_env(shared_secrets):
    return {
        key: value
        for key in SMTP_SECRET_KEYS
        if (value := shared_secrets.get(key)) is not None
    }


def build_systemd_environment(shared_environment):
    return {
        key: value
        for key, value in shared_environment.items()
        if key.endswith("_IMAGE")
    }


def build_openviking_config(agent_data):
    return {
        "server": {
            "host": "127.0.0.1",
            "port": 1933,
        },
        "storage": {
            "workspace": OPENVIKING_WORKSPACE_PATH,
            "agfs": {
                "backend": "local",
            },
            "vectordb": {
                "backend": "local",
            },
        },
        "log": {
            "level": "INFO",
            "output": "stdout",
        },
        "default_account": "default",
        "default_user": agent_data["name"].lower().replace(" ", "-"),
        "default_agent": f"agent-{agent_data['id']}",
    }


def remove_agent_runtime_files(agent_id):
    for path in (
        agent_envfile(agent_id),
        agent_secrets_envfile(agent_id),
        agent_openviking_configfile(agent_id),
    ):
        if os.path.exists(path):
            os.remove(path)


def remove_agent_volumes(agent_id):
    for volume_name in (hermes_data_volume(agent_id), openviking_data_volume(agent_id)):
        run_command(["podman", "volume", "rm", "--force", volume_name], check=False)


def sync_agent_runtime_files(agent_id=None):
    agents = read_agents_from_state()
    shared_environment = read_optional_envfile(ENVIRONMENT_FILE)
    shared_secrets = read_optional_envfile(SHARED_SECRETS_ENVFILE)

    write_envfile(SYSTEMD_ENVFILE, build_systemd_environment(shared_environment))

    if agent_id is not None:
        filtered_agents = [item for item in agents if item["id"] == agent_id]
        if not filtered_agents:
            raise ValueError(f"agent {agent_id} not found")
        agents = filtered_agents

    current_ids = {item["id"] for item in read_agents_from_state()}

    for agent_data in agents:
        write_envfile(
            agent_envfile(agent_data["id"]),
            build_agent_public_env(agent_data, shared_environment),
        )
        write_envfile(
            agent_secrets_envfile(agent_data["id"]),
            build_agent_secrets_env(shared_secrets),
        )
        write_jsonfile(
            agent_openviking_configfile(agent_data["id"]),
            build_openviking_config(agent_data),
        )

    if agent_id is None:
        for stale_id in scan_generated_agent_ids():
            if stale_id not in current_ids:
                remove_agent_runtime_files(stale_id)

    return agents


def stop_disable_agent(agent_id):
    systemctl_user("disable", "--now", target_unit(agent_id), check=False)
    run_command(["podman", "pod", "rm", "--force", pod_name(agent_id)], check=False)


def cleanup_agent_runtime(agent_id):
    stop_disable_agent(agent_id)
    remove_agent_volumes(agent_id)
    remove_agent_runtime_files(agent_id)


def actual_agent_status(agent_id):
    services = managed_service_units(agent_id)
    if all(unit_is_active(unit_name) for unit_name in services):
        return "start"
    return "stop"