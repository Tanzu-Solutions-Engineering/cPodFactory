#!/bin/bash

##init variables####
server_host=vrcs.cpod-vr.shwrfr.mooo.com
username=admin
password=VMware1!
tenant=vsphere.local
pipeline_name=$1
pipeline_params='{"description":"test run"}'

#echo -e $server_host
#echo -e $username
#echo -e $tenant
#echo -e $pipeline_name
#echo -e $pipeline_params

#echo "#### Sample script to query and trigger a pipeline execution ####"
#Server host address refers to the host on which Code Stream server is setup. Eg: codestream.abc.com
#read -p "vRealize Code Stream Server Host: " server_host

#user name and password with which you login on Code Stream server Eg: jane.doe@abc.com
#read -p "Username: " username
#read -p "Password: " password

#tenant name can be obtained from your system administrator if not known already
#read -p "Tenant: " tenant
#echo "-------------------------------------------------------"

#fetch the pipeline details and subsequently trigger an execution
#enter the pipeline name for which you want to trigger an execution
#read -p "Release pipeline name:" pipeline_name

#pipeline param JSON is the input required for the pipeline execution. for a single pipeline parameter 'token', the JSON input would look like:
# Eg: {"description":"test run","pipelineParams":[{"name":"token","type":"STRING","value":"4321"}]}
#read -p "Enter the pipeline param JSON:" pipeline_params

#A SSO token is required to make any calls to the Code Stream server. Token can be obtained easily by passing the credentials as follows
host_url="https://$server_host/identity/api/tokens"
response=$(curl -s -X POST -H 'Content-Type: application/json' -H 'Accept: application/json' --insecure -d '{"username": "'"$username"'", "password": "'"$password"'", "tenant": "'"$tenant"'"}' $host_url)
#token can be extracted from the JSON response as follows
token=`echo $response | sed -n 's/.*"id":"\([^}]*\)",.*}/\1/p'`

#with the token obtained, subsequent calls can be made to the code stream server (a token has an expiry so renewal might be required if the same token is reused beyond expiry)
pipeline_fetch_url="https://$server_host/release-management-service/api/release-pipelines?name=$pipeline_name"
response=$(curl -s -X GET -H "Content-Type: application/json" -H "Accept: application/json" -H "Authorization: Bearer $token" -k $pipeline_fetch_url)
pipeline_id=`echo $response | sed -n 's/.*"id":"\([^"]*\)",.*stages.*/\1/p'`
#echo "pipeline id: $pipeline_id"

#with the pipeline id, an execution can be triggered as follows
execute_pipeline_url="https://$server_host/release-management-service/api/release-pipelines/$pipeline_id/executions"
#echo "executing pipeline:$pipeline_name :[$pipeline_id]"
response=$(curl -s -X POST -H "Content-Type: application/json" -H "Accept: application/json" -H "Authorization: Bearer $token" -k -d "$pipeline_params" $execute_pipeline_url)
#echo "Response to execute pipeline => $response"
