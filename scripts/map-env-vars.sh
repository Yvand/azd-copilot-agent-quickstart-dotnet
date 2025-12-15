#!/bin/bash

# -e: immediately exit if any command has a non-zero exit status
# -o pipefail: prevents errors in a pipeline from being masked
set -eo pipefail

echo "Mapping current azd environment variables to local environment variables and Azure Web App settings..."
envVarsPrefix="M365AgentQuickstart_"
envVarKeyTenantId="${envVarsPrefix}TokenValidation__TenantId"
envVarKeyClientIdAudiences="${envVarsPrefix}TokenValidation__Audiences__0"
envVarKeyClientIdConnections="${envVarsPrefix}Connections__ServiceConnection__Settings__ClientId"

while IFS='=' read -r key value; do
   value=$(echo "$value" | sed 's/^"//' | sed 's/"$//')
   if [ "$key" == "AZURE_TENANT_ID" ] ; then
      tenantId="$value"
      export "$envVarKeyTenantId=$value"
   elif [ "$key" == "AZURE_RESOURCE_GROUP_NAME" ] ; then
      rg="$value"
   elif [ "$key" == "BOTSERVICE_CLIENT_ID" ] ; then
      botServiceClientId="$value"
      export "$envVarKeyClientIdAudiences=$value"
      export "$envVarKeyClientIdConnections=$value"
   elif [ "$key" == "WEBAPP_NAME" ] ; then
      webAppName="$value"
   else
      continue
   fi
done <<EOF
$(azd env get-values)
EOF

az webapp config appsettings set --name "$webAppName" --resource-group "$rg" --settings $envVarKeyTenantId=$tenantId $envVarKeyClientIdAudiences=$botServiceClientId $envVarKeyClientIdConnections=$botServiceClientId
echo "Environment variables with prefix '$envVarsPrefix' have been set in the Web App '$webAppName' and in the local environment."
printenv | grep "$envVarsPrefix"
