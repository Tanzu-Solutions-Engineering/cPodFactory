#!/bin/bash
#vmeoc

export api_token=88e1999e-b9d1-4dcb-ac55-6d30076e61db
export bearer=`curl -X POST 'https://api.mgmt.cloud.vmware.com/iaas/login' -H 'Accept: application/json' -H 'Content-Type: application/json' -d '{ 'refreshToken': '$api_token' }' | jq -r '.token'`
export PipelineID=778edaf8cba12675589e3a5de871a

curl -X POST 'https://api.mgmt.cloud.vmware.com/pipeline/api/pipelines/'$PipelineID'/executions' -H 'Content-Type: application/json' -H 'Authorization: Bearer '$bearer'' -d '{}'
