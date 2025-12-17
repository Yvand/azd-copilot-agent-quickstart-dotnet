#!/bin/bash
# -e: immediately exit if any command has a non-zero exit status
# -o pipefail: prevents errors in a pipeline from being masked
set -eo pipefail

echo "Updating environment variables locally and in the Azure App Service..."
envVarsPrefix="M365AgentQuickstart_"
envVarKeyTenantId="${envVarsPrefix}TokenValidation__TenantId"
envVarKeyClientIdAudiences="${envVarsPrefix}TokenValidation__Audiences__0"
envVarKeyClientIdConnections="${envVarsPrefix}Connections__ServiceConnection__Settings__ClientId"

while IFS='=' read -r key value; do
   value=$(echo "$value" | sed 's/^"//' | sed 's/"$//')
   case "$key" in
      "AZURE_TENANT_ID")
         tenantId="$value"
         export "$envVarKeyTenantId=$value"
         ;;
      "AZURE_SUBSCRIPTION_ID")
         subscription="$value"
         ;;
      "AZURE_RESOURCE_GROUP_NAME")
         rg="$value"
         ;;
      "BOTSERVICE_CLIENT_ID")
         botServiceClientId="$value"
         export "$envVarKeyClientIdAudiences=$value"
         export "$envVarKeyClientIdConnections=$value"
         ;;
      "WEBAPP_NAME")
         webAppName="$value"
         ;;
      *)
         continue
         ;;
   esac
done <<EOF
$(azd env get-values)
EOF

az webapp config appsettings set --subscription "$subscription" --name "$webAppName" --resource-group "$rg" --settings $envVarKeyTenantId=$tenantId $envVarKeyClientIdAudiences=$botServiceClientId $envVarKeyClientIdConnections=$botServiceClientId > /dev/null
echo "Environment variables with prefix '$envVarsPrefix' have been set in the Azure App Service '$webAppName' and locally."
printenv | grep "$envVarsPrefix"
