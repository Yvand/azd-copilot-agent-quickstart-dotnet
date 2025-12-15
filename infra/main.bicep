targetScope = 'subscription'

@minLength(1)
@maxLength(64)
@description('Name of the the environment which is used to generate a short unique hash used in all resources.')
param environmentName string

@minLength(1)
@description('Primary location for all resources & Flex Consumption Function App')
@allowed([
  'australiaeast'
  'australiasoutheast'
  'brazilsouth'
  'canadacentral'
  'centralindia'
  'centralus'
  'eastasia'
  'eastus'
  'eastus2'
  'eastus2euap'
  'francecentral'
  'germanywestcentral'
  'italynorth'
  'japaneast'
  'koreacentral'
  'northcentralus'
  'northeurope'
  'norwayeast'
  'southafricanorth'
  'southcentralus'
  'southeastasia'
  'southindia'
  'spaincentral'
  'swedencentral'
  'uaenorth'
  'uksouth'
  'ukwest'
  'westcentralus'
  'westeurope'
  'westus'
  'westus2'
  'westus3'
])
@metadata({
  azd: {
    type: 'location'
  }
})
param location string
param resourceGroupName string = ''

@description('List of the public IP addresses allowed to connect to the storage account and the key vault.')
param allowedIpAddresses array = []

@description('List of the environment variables to create in the Azure functions service.')
param webAppEnvVars object

param vnetEnabled bool = false
param addKeyVault bool = false
param webAppName string = ''
@allowed(['SystemAssigned', 'UserAssigned'])
param webAppIdentityType string = 'UserAssigned'
param webAppUserAssignedIdentityName string = ''
param webAppPlanName string = ''
param webAppServicePlanSku string = 'F1'
param applicationInsightsName string = ''
param logAnalyticsName string = ''
param vNetName string = ''
param keyVaultName string = ''
@description('Id of the user identity to be used for testing and debugging. This is not required in production. Leave empty if not needed.')
param principalId string = deployer().objectId

// Bot services
@allowed(['SingleTenant', 'UserAssignedMSI'])
param botAppType string = 'UserAssignedMSI'
param botUserAssignedIdentityName string = ''
param botServiceName string = ''
var botAppName = !empty(botServiceName) ? botServiceName : 'bot-${resourceToken}'

var appRegistrationName string = environmentName

var abbrs = loadJsonContent('./abbreviations.json')
var resourceToken = toLower(uniqueString(subscription().id, environmentName, location))
var tags = { 'azd-env-name': environmentName }
var webAppServiceName = !empty(webAppName) ? webAppName : '${abbrs.webSitesAppService}web-${resourceToken}'

// Check if allowedIpAddresses is empty or contains only an empty string
var allowedIpAddressesNoEmptyString = empty(allowedIpAddresses) || (length(allowedIpAddresses) == 1 && contains(
    allowedIpAddresses,
    ''
  ))
  ? []
  : allowedIpAddresses


// Create the app registration in Entra ID
module botAppRegistration 'app/entraid-app.bicep' = if (botAppType == 'SingleTenant') {
  name: 'entraAppRegistration'
  scope: rg
  params: {
    appRegistrationName: appRegistrationName
  }
}

// Organize resources in a resource group
resource rg 'Microsoft.Resources/resourceGroups@2025-04-01' = {
  name: !empty(resourceGroupName) ? resourceGroupName : '${abbrs.resourcesResourceGroups}${environmentName}'
  location: location
  tags: tags
}

// User assigned managed identity to be used by the function app to reach storage and other dependencies
// Assign specific roles to this identity in the RBAC module
module webAppUserAssignedIdentity 'br/public:avm/res/managed-identity/user-assigned-identity:0.4.3' = if (webAppIdentityType == 'UserAssigned') {
  name: 'appServiceUserAssignedIdentity'
  scope: rg
  params: {
    location: location
    tags: tags
    name: !empty(webAppUserAssignedIdentityName)
      ? webAppUserAssignedIdentityName
      : '${abbrs.managedIdentityUserAssignedIdentities}web-${resourceToken}'
  }
}

// Create an App Service Plan to group applications under the same payment plan and SKU
module webAppServicePlan 'br/public:avm/res/web/serverfarm:0.5.0' = {
  name: 'appserviceplan'
  scope: rg
  params: {
    name: !empty(webAppPlanName) ? webAppPlanName : '${abbrs.webServerFarms}${resourceToken}'
    reserved: true
    location: location
    tags: tags
    kind: 'linux'
    skuName: webAppServicePlanSku
    skuCapacity: 1
  }
}

module webApp './app/webapp.bicep' = {
  name: 'webApp'
  scope: rg
  params: {
    name: webAppServiceName
    location: location
    tags: union(tags, {
      'azd-service-name': 'webApp'
    })
    applicationInsightsName: monitoring.outputs.name
    appServicePlanId: webAppServicePlan.outputs.resourceId
    runtimeName: 'dotnetcore'
    runtimeVersion: '8.0'
    appSettings: webAppEnvVars
    virtualNetworkSubnetId: vnetEnabled ? serviceVirtualNetwork!.outputs.appSubnetID : ''
    identityType: webAppIdentityType
    UserAssignedManagedIdentityId: webAppIdentityType == 'UserAssigned'
      ? webAppUserAssignedIdentity!.outputs.resourceId
      : ''
    UserAssignedManagedIdentityClientId: webAppIdentityType == 'UserAssigned'
      ? webAppUserAssignedIdentity!.outputs.clientId
      : ''
    botUserAssignedManagedIdentityId: botAppType == 'UserAssignedMSI'
      ? botUserAssignedIdentity!.outputs.resourceId
      : ''
  }
}

var ipRules = [
  for ipAddress in allowedIpAddressesNoEmptyString: {
    action: 'Allow'
    value: ipAddress
  }
]

// Consolidated Role Assignments
module rbac 'app/rbac.bicep' = {
  name: 'rbacAssignments'
  scope: rg
  params: {
    // storageAccountName: storage.outputs.name
    appInsightsName: monitoring.outputs.name
    managedIdentityPrincipalId: webAppIdentityType == 'UserAssigned'
      ? webAppUserAssignedIdentity!.outputs.principalId
      : webApp.outputs.serviceIdentityPrincipalId
    userIdentityPrincipalId: principalId
    keyVaultName: addKeyVault ? vault!.outputs.name : ''
  }
}

// Virtual Network & private endpoint to blob storage
module serviceVirtualNetwork 'app/vnet.bicep' = if (vnetEnabled) {
  name: 'serviceVirtualNetwork'
  scope: rg
  params: {
    location: location
    tags: tags
    vNetName: !empty(vNetName) ? vNetName : '${abbrs.networkVirtualNetworks}${resourceToken}'
  }
}

// Monitor application with Azure Monitor - Log Analytics and Application Insights
module logAnalytics 'br/public:avm/res/operational-insights/workspace:0.14.2' = {
  name: '${uniqueString(deployment().name, location)}-loganalytics'
  scope: rg
  params: {
    name: !empty(logAnalyticsName) ? logAnalyticsName : '${abbrs.operationalInsightsWorkspaces}${resourceToken}'
    location: location
    tags: tags
    dataRetention: 30
  }
}

module monitoring 'br/public:avm/res/insights/component:0.7.1' = {
  name: '${uniqueString(deployment().name, location)}-appinsights'
  scope: rg
  params: {
    name: !empty(applicationInsightsName) ? applicationInsightsName : '${abbrs.insightsComponents}${resourceToken}'
    location: location
    tags: tags
    workspaceResourceId: logAnalytics.outputs.resourceId
    disableLocalAuth: true
  }
}

// Azure key-vault
module vault 'br/public:avm/res/key-vault/vault:0.13.3' = if (addKeyVault) {
  name: '${uniqueString(deployment().name, location)}-vault'
  scope: rg
  params: {
    name: !empty(keyVaultName) ? keyVaultName : '${abbrs.keyVaultVaults}${resourceToken}'
    location: location
    tags: tags
    enablePurgeProtection: false
    publicNetworkAccess: vnetEnabled ? 'Disabled' : 'Enabled'
    networkAcls: vnetEnabled
      ? {
          defaultAction: 'Deny'
          bypass: 'AzureServices'
          ipRules: empty(allowedIpAddressesNoEmptyString) ? [] : ipRules
        }
      : {
          defaultAction: 'Allow'
          bypass: 'AzureServices'
          ipRules: empty(allowedIpAddressesNoEmptyString) ? [] : ipRules
        }
    enableSoftDelete: false
  }
}

module vaultPrivateEndpoint 'app/vault-PrivateEndpoint.bicep' = if (vnetEnabled && addKeyVault) {
  name: 'vaultPrivateEndpoint'
  scope: rg
  params: {
    location: location
    tags: tags
    virtualNetworkName: !empty(vNetName) ? vNetName : '${abbrs.networkVirtualNetworks}${resourceToken}'
    subnetName: vnetEnabled ? serviceVirtualNetwork.outputs.peSubnetName : '' // Keep conditional check for safety, though module won't run if !vnetEnabled
    resourceName: vault.outputs.name
  }
}

// User assigned managed identity to be used by the bot service
module botUserAssignedIdentity 'br/public:avm/res/managed-identity/user-assigned-identity:0.4.3' = if (botAppType == 'UserAssignedMSI') {
  name: 'botUserAssignedIdentity'
  scope: rg
  params: {
    location: location
    tags: tags
    name: !empty(botUserAssignedIdentityName)
      ? botUserAssignedIdentityName
      : '${abbrs.managedIdentityUserAssignedIdentities}bot-${resourceToken}'
  }
}

module bot './app/bot.bicep' = {
  name: 'bot'
  scope: rg
  params: {
    name: botAppName
    location: 'global'
    tags: tags
    appType: botAppType
    UserAssignedManagedIdentityResourceId: botAppType == 'UserAssignedMSI' ? botUserAssignedIdentity!.outputs.resourceId : ''
    applicationClientId: botAppType == 'UserAssignedMSI' ? botUserAssignedIdentity!.outputs.clientId : botAppRegistration!.outputs.clientId
    tenantId: tenant().tenantId
    endpoint: 'https://${webApp.outputs.serviceDefaultHostName}/api/messages'
  }
}

// App outputs
output AZURE_LOCATION string = location
output AZURE_TENANT_ID string = tenant().tenantId
output WEBAPP_NAME string = webApp.outputs.serviceName
output WEBAPP_DEFAULT_HOST_NAME string = webApp.outputs.serviceDefaultHostName
output BOTSERVICE_CLIENT_ID string = botAppType == 'UserAssignedMSI' ? botUserAssignedIdentity!.outputs.clientId : botAppRegistration!.outputs.clientId
output BOTSERVICE_NAME string = bot.outputs.botServiceName
