*** Settings ***
Library    SSHLibrary

*** Test Cases ***
Check if hermes-agent is installed correctly
    ${output}  ${rc} =    Execute Command    add-module ${IMAGE_URL} 1
    ...    return_rc=True
    Should Be Equal As Integers    ${rc}  0
    &{output} =    Evaluate    ${output}
    Set Suite Variable    ${module_id}    ${output.module_id}

Check if hermes-agent can be configured
    ${configure_payload} =    Set Variable    {"agents":[{"id":1,"name":"Foo Bar","role":"developer","status":"start"}]}
    ${rc} =    Execute Command    api-cli run module/${module_id}/configure-module --data '${configure_payload}'
    ...    return_rc=True  return_stdout=False
    Should Be Equal As Integers    ${rc}  0

Check if hermes-agent returns configured agents
    ${output} =    Execute Command    api-cli run module/${module_id}/get-configuration --data '{}'
    ${agent_count} =    Evaluate    len(json.loads(r'''${output}''')["agents"])    json
    ${agent_name} =    Evaluate    json.loads(r'''${output}''')["agents"][0]["name"]    json
    ${agent_role} =    Evaluate    json.loads(r'''${output}''')["agents"][0]["role"]    json
    ${agent_status} =    Evaluate    json.loads(r'''${output}''')["agents"][0]["status"]    json
    Should Be Equal As Integers    ${agent_count}  1
    Should Be Equal    ${agent_name}  Foo Bar
    Should Be Equal    ${agent_role}  developer
    Should Be Equal    ${agent_status}  start

Check if hermes-agent works as expected
    ${rc} =    Execute Command    curl -f http://127.0.0.1/hermes-agent/
    ...    return_rc=True  return_stdout=False
    Should Be Equal As Integers    ${rc}  0

Check if hermes-agent is removed correctly
    ${rc} =    Execute Command    remove-module --no-preserve ${module_id}
    ...    return_rc=True  return_stdout=False
    Should Be Equal As Integers    ${rc}  0
