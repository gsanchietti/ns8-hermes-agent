*** Settings ***
Library    SSHLibrary

*** Test Cases ***
Check if hermes-agent is installed correctly
    ${output}  ${rc} =    Execute Command    add-module ${IMAGE_URL} 1
    ...    return_rc=True
    Should Be Equal As Integers    ${rc}  0
    &{output} =    Evaluate    ${output}
    Set Suite Variable    ${module_id}    ${output.module_id}
    ${module_home} =    Execute Command    getent passwd ${module_id} | cut -d: -f6
    Set Suite Variable    ${module_home}    ${module_home}

Check if hermes-agent can be configured with mixed agent states
    ${configure_payload} =    Set Variable    {"agents":[{"id":1,"name":"Foo Bar","role":"developer","status":"start"},{"id":2,"name":"Alice User","role":"default","status":"stop"}]}
    ${rc} =    Execute Command    api-cli run module/${module_id}/configure-module --data '${configure_payload}'
    ...    return_rc=True  return_stdout=False
    Should Be Equal As Integers    ${rc}  0

Check if hermes-agent creates per-agent runtime files
    ${agent1_env} =    Execute Command    find ${module_home} -maxdepth 8 -name 'agent-1.env' -print -quit
    ${agent1_secrets} =    Execute Command    find ${module_home} -maxdepth 8 -name 'agent-1_secrets.env' -print -quit
    ${agent1_openviking} =    Execute Command    find ${module_home} -maxdepth 8 -name 'agent-1_openviking.conf' -print -quit
    ${agent2_env} =    Execute Command    find ${module_home} -maxdepth 8 -name 'agent-2.env' -print -quit
    ${agent2_secrets} =    Execute Command    find ${module_home} -maxdepth 8 -name 'agent-2_secrets.env' -print -quit
    ${agent2_openviking} =    Execute Command    find ${module_home} -maxdepth 8 -name 'agent-2_openviking.conf' -print -quit
    Should Not Be Empty    ${agent1_env}
    Should Not Be Empty    ${agent1_secrets}
    Should Not Be Empty    ${agent1_openviking}
    Should Not Be Empty    ${agent2_env}
    Should Not Be Empty    ${agent2_secrets}
    Should Not Be Empty    ${agent2_openviking}

Check if hermes-agent returns actual agent states
    ${output} =    Execute Command    api-cli run module/${module_id}/get-configuration --data '{}'
    ${agent_count} =    Evaluate    len(json.loads(r'''${output}''')["agents"])    json
    ${agent1_name} =    Evaluate    next(item["name"] for item in json.loads(r'''${output}''')["agents"] if item["id"] == 1)    json
    ${agent1_role} =    Evaluate    next(item["role"] for item in json.loads(r'''${output}''')["agents"] if item["id"] == 1)    json
    ${agent1_status} =    Evaluate    next(item["status"] for item in json.loads(r'''${output}''')["agents"] if item["id"] == 1)    json
    ${agent2_name} =    Evaluate    next(item["name"] for item in json.loads(r'''${output}''')["agents"] if item["id"] == 2)    json
    ${agent2_role} =    Evaluate    next(item["role"] for item in json.loads(r'''${output}''')["agents"] if item["id"] == 2)    json
    ${agent2_status} =    Evaluate    next(item["status"] for item in json.loads(r'''${output}''')["agents"] if item["id"] == 2)    json
    Should Be Equal As Integers    ${agent_count}  2
    Should Be Equal    ${agent1_name}  Foo Bar
    Should Be Equal    ${agent1_role}  developer
    Should Be Equal    ${agent1_status}  start
    Should Be Equal    ${agent2_name}  Alice User
    Should Be Equal    ${agent2_role}  default
    Should Be Equal    ${agent2_status}  stop

Check if hermes-agent starts one pod per running agent
    ${target1_output}  ${target1_rc} =    Execute Command    runuser -u ${module_id} -- bash -lc 'systemctl --user is-active hermes-agent@1.target'
    ...    return_rc=True
    ${pod_output}  ${pod_rc} =    Execute Command    runuser -u ${module_id} -- bash -lc 'systemctl --user is-active hermes-agent-pod@1.service'
    ...    return_rc=True
    ${openviking_output}  ${openviking_rc} =    Execute Command    runuser -u ${module_id} -- bash -lc 'systemctl --user is-active hermes-agent-openviking@1.service'
    ...    return_rc=True
    ${hermes_output}  ${hermes_rc} =    Execute Command    runuser -u ${module_id} -- bash -lc 'systemctl --user is-active hermes-agent-hermes@1.service'
    ...    return_rc=True
    ${gateway_output}  ${gateway_rc} =    Execute Command    runuser -u ${module_id} -- bash -lc 'systemctl --user is-active hermes-agent-gateway@1.service'
    ...    return_rc=True
    ${pod_exists_rc} =    Execute Command    runuser -u ${module_id} -- bash -lc 'podman pod exists hermes-agent-1'
    ...    return_rc=True  return_stdout=False
    Should Be Equal As Integers    ${target1_rc}  0
    Should Be Equal As Integers    ${pod_rc}  0
    Should Be Equal As Integers    ${openviking_rc}  0
    Should Be Equal As Integers    ${hermes_rc}  0
    Should Be Equal As Integers    ${gateway_rc}  0
    Should Be Equal As Integers    ${pod_exists_rc}  0
    Should Be Equal    ${target1_output}  active
    Should Be Equal    ${pod_output}  active
    Should Be Equal    ${openviking_output}  active
    Should Be Equal    ${hermes_output}  active
    Should Be Equal    ${gateway_output}  active

Check if hermes-agent creates persistent volumes and keeps data across restart
    ${hermes_volume_rc} =    Execute Command    runuser -u ${module_id} -- bash -lc 'podman volume exists hermes-agent-hermes-data-1'
    ...    return_rc=True  return_stdout=False
    ${openviking_volume_rc} =    Execute Command    runuser -u ${module_id} -- bash -lc 'podman volume exists hermes-agent-openviking-data-1'
    ...    return_rc=True  return_stdout=False
    ${write_gateway_rc} =    Execute Command    runuser -u ${module_id} -- bash -lc 'podman exec hermes-agent-gateway-1 sh -lc "printf persistent > /opt/data/persist-sentinel"'
    ...    return_rc=True  return_stdout=False
    ${write_openviking_rc} =    Execute Command    runuser -u ${module_id} -- bash -lc 'podman exec hermes-agent-openviking-1 sh -lc "mkdir -p /app/data/test && printf persistent > /app/data/test/persist-sentinel"'
    ...    return_rc=True  return_stdout=False
    ${restart_rc} =    Execute Command    runuser -u ${module_id} -- bash -lc 'systemctl --user restart hermes-agent@1.target'
    ...    return_rc=True  return_stdout=False
    ${gateway_restart_output}  ${gateway_restart_rc} =    Execute Command    runuser -u ${module_id} -- bash -lc 'systemctl --user is-active hermes-agent-gateway@1.service'
    ...    return_rc=True
    ${openviking_restart_output}  ${openviking_restart_rc} =    Execute Command    runuser -u ${module_id} -- bash -lc 'systemctl --user is-active hermes-agent-openviking@1.service'
    ...    return_rc=True
    ${gateway_sentinel} =    Execute Command    runuser -u ${module_id} -- bash -lc 'podman exec hermes-agent-gateway-1 sh -lc "cat /opt/data/persist-sentinel"'
    ${openviking_sentinel} =    Execute Command    runuser -u ${module_id} -- bash -lc 'podman exec hermes-agent-openviking-1 sh -lc "cat /app/data/test/persist-sentinel"'
    Should Be Equal As Integers    ${hermes_volume_rc}  0
    Should Be Equal As Integers    ${openviking_volume_rc}  0
    Should Be Equal As Integers    ${write_gateway_rc}  0
    Should Be Equal As Integers    ${write_openviking_rc}  0
    Should Be Equal As Integers    ${restart_rc}  0
    Should Be Equal As Integers    ${gateway_restart_rc}  0
    Should Be Equal As Integers    ${openviking_restart_rc}  0
    Should Be Equal    ${gateway_restart_output}  active
    Should Be Equal    ${openviking_restart_output}  active
    Should Be Equal    ${gateway_sentinel}  persistent
    Should Be Equal    ${openviking_sentinel}  persistent

Check if hermes-agent keeps stopped agents inactive
    ${target2_output}  ${target2_rc} =    Execute Command    runuser -u ${module_id} -- bash -lc 'systemctl --user is-active hermes-agent@2.target'
    ...    return_rc=True
    ${pod2_exists_rc} =    Execute Command    runuser -u ${module_id} -- bash -lc 'podman pod exists hermes-agent-2'
    ...    return_rc=True  return_stdout=False
    Should Not Be Equal As Integers    ${target2_rc}  0
    Should Not Be Equal As Integers    ${pod2_exists_rc}  0
    Should Be Equal    ${target2_output}  inactive

Check if hermes-agent cleans removed agents and starts remaining ones
    ${configure_payload} =    Set Variable    {"agents":[{"id":2,"name":"Alice User","role":"default","status":"start"}]}
    ${rc} =    Execute Command    api-cli run module/${module_id}/configure-module --data '${configure_payload}'
    ...    return_rc=True  return_stdout=False
    Should Be Equal As Integers    ${rc}  0
    ${output} =    Execute Command    api-cli run module/${module_id}/get-configuration --data '{}'
    ${agent_count} =    Evaluate    len(json.loads(r'''${output}''')["agents"])    json
    ${remaining_id} =    Evaluate    json.loads(r'''${output}''')["agents"][0]["id"]    json
    ${remaining_status} =    Evaluate    json.loads(r'''${output}''')["agents"][0]["status"]    json
    ${agent1_env} =    Execute Command    find ${module_home} -maxdepth 8 -name 'agent-1.env' -print -quit
    ${agent1_secrets} =    Execute Command    find ${module_home} -maxdepth 8 -name 'agent-1_secrets.env' -print -quit
    ${agent1_openviking} =    Execute Command    find ${module_home} -maxdepth 8 -name 'agent-1_openviking.conf' -print -quit
    ${target1_output}  ${target1_rc} =    Execute Command    runuser -u ${module_id} -- bash -lc 'systemctl --user is-active hermes-agent@1.target'
    ...    return_rc=True
    ${target2_output}  ${target2_rc} =    Execute Command    runuser -u ${module_id} -- bash -lc 'systemctl --user is-active hermes-agent@2.target'
    ...    return_rc=True
    ${pod1_exists_rc} =    Execute Command    runuser -u ${module_id} -- bash -lc 'podman pod exists hermes-agent-1'
    ...    return_rc=True  return_stdout=False
    ${pod2_exists_rc} =    Execute Command    runuser -u ${module_id} -- bash -lc 'podman pod exists hermes-agent-2'
    ...    return_rc=True  return_stdout=False
    ${hermes_volume1_rc} =    Execute Command    runuser -u ${module_id} -- bash -lc 'podman volume exists hermes-agent-hermes-data-1'
    ...    return_rc=True  return_stdout=False
    ${openviking_volume1_rc} =    Execute Command    runuser -u ${module_id} -- bash -lc 'podman volume exists hermes-agent-openviking-data-1'
    ...    return_rc=True  return_stdout=False
    ${hermes_volume2_rc} =    Execute Command    runuser -u ${module_id} -- bash -lc 'podman volume exists hermes-agent-hermes-data-2'
    ...    return_rc=True  return_stdout=False
    ${openviking_volume2_rc} =    Execute Command    runuser -u ${module_id} -- bash -lc 'podman volume exists hermes-agent-openviking-data-2'
    ...    return_rc=True  return_stdout=False
    Should Be Equal As Integers    ${agent_count}  1
    Should Be Equal As Integers    ${remaining_id}  2
    Should Be Equal    ${remaining_status}  start
    Should Be Empty    ${agent1_env}
    Should Be Empty    ${agent1_secrets}
    Should Be Empty    ${agent1_openviking}
    Should Not Be Equal As Integers    ${target1_rc}  0
    Should Be Equal    ${target1_output}  inactive
    Should Be Equal As Integers    ${target2_rc}  0
    Should Be Equal    ${target2_output}  active
    Should Not Be Equal As Integers    ${pod1_exists_rc}  0
    Should Be Equal As Integers    ${pod2_exists_rc}  0
    Should Not Be Equal As Integers    ${hermes_volume1_rc}  0
    Should Not Be Equal As Integers    ${openviking_volume1_rc}  0
    Should Be Equal As Integers    ${hermes_volume2_rc}  0
    Should Be Equal As Integers    ${openviking_volume2_rc}  0

Check if hermes-agent is removed correctly
    ${rc} =    Execute Command    remove-module --no-preserve ${module_id}
    ...    return_rc=True  return_stdout=False
    Should Be Equal As Integers    ${rc}  0
