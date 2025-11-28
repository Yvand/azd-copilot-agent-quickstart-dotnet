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

@description('List of the public IP addresses allowed to connect to the storage account and the key vault.')
param allowedIpAddresses array = []

@description('List of the environment variables to create in the Azure functions service.')
param appSettings object

param vnetEnabled bool = false
param addKeyVault bool = false
param webServiceName string = ''
@allowed(['SystemAssigned', 'UserAssigned'])
param webServiceIdentityType string = 'SystemAssigned'
param webUserAssignedIdentityName string = ''
param applicationInsightsName string = ''
param appServicePlanName string = ''
param logAnalyticsName string = ''
param resourceGroupName string = ''
param storageAccountName string = ''
param vNetName string = ''
param keyVaultName string = ''
param cosmosdbAccountName string = ''
@description('Id of the user identity to be used for testing and debugging. This is not required in production. Leave empty if not needed.')
param principalId string = deployer().objectId

// Bot services
@allowed(['SingleTenant', 'UserAssignedMSI'])
param botAppType string = 'SingleTenant'
param botUserAssignedIdentityName string = ''
param botServiceName string = ''
var botAppName = !empty(botServiceName) ? botServiceName : 'bot-${resourceToken}'

var appRegistrationName string = environmentName

var abbrs = loadJsonContent('./abbreviations.json')
var resourceToken = toLower(uniqueString(subscription().id, environmentName, location))
var tags = { 'azd-env-name': environmentName }
var functionAppName = !empty(webServiceName) ? webServiceName : '${abbrs.webSitesAppService}web-${resourceToken}'
var deploymentStorageContainerName = 'app-package-${take(functionAppName, 32)}-${take(toLower(uniqueString(functionAppName, resourceToken)), 7)}'
// Check if allowedIpAddresses is empty or contains only an empty string
var allowedIpAddressesNoEmptyString = empty(allowedIpAddresses) || (length(allowedIpAddresses) == 1 && contains(
    allowedIpAddresses,
    ''
  ))
  ? []
  : allowedIpAddresses


// Create the app registration in Entra ID
module resourceAppRegistration 'app/entraid-app.bicep' = if (botAppType == 'SingleTenant') {
  name: 'entraAppRegistration'
  scope: rg
  params: {
    appRegistrationName: appRegistrationName
  }
}

// Organize resources in a resource group
resource rg 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: !empty(resourceGroupName) ? resourceGroupName : '${abbrs.resourcesResourceGroups}${environmentName}'
  location: location
  tags: tags
}

// User assigned managed identity to be used by the function app to reach storage and other dependencies
// Assign specific roles to this identity in the RBAC module
module webUserAssignedIdentity 'br/public:avm/res/managed-identity/user-assigned-identity:0.4.2' = if (webServiceIdentityType == 'UserAssigned') {
  name: 'webUserAssignedIdentity'
  scope: rg
  params: {
    location: location
    tags: tags
    name: !empty(webUserAssignedIdentityName)
      ? webUserAssignedIdentityName
      : '${abbrs.managedIdentityUserAssignedIdentities}web-${resourceToken}'
  }
}

// Create an App Service Plan to group applications under the same payment plan and SKU
module appServicePlan 'br/public:avm/res/web/serverfarm:0.5.0' = {
  name: 'appserviceplan'
  scope: rg
  params: {
    name: !empty(appServicePlanName) ? appServicePlanName : '${abbrs.webServerFarms}${resourceToken}'
    reserved: true
    location: location
    tags: tags
    kind: 'linux'
    skuName: 'F1'
    skuCapacity: 1
  }
}

module appservice './app/appservice.bicep' = {
  name: 'appservice'
  scope: rg
  params: {
    name: functionAppName
    location: location
    tags: union(tags, {
      'azd-service-name': 'appservice'
    })
    applicationInsightsName: monitoring.outputs.name
    appServicePlanId: appServicePlan.outputs.resourceId
    runtimeName: 'dotnetcore'
    runtimeVersion: '8.0'
    storageAccountName: storage.outputs.name
    enableBlob: storageEndpointConfig.enableBlob
    enableQueue: storageEndpointConfig.enableQueue
    enableTable: storageEndpointConfig.enableTable
    identityType: webServiceIdentityType
    UserAssignedManagedIdentityId: webServiceIdentityType == 'UserAssigned'
      ? webUserAssignedIdentity!.outputs.resourceId
      : ''
    UserAssignedManagedIdentityClientId: webServiceIdentityType == 'UserAssigned'
      ? webUserAssignedIdentity!.outputs.clientId
      : ''
    appSettings: appSettings
    virtualNetworkSubnetId: vnetEnabled ? serviceVirtualNetwork!.outputs.appSubnetID : ''
  }
}

var ipRules = [
  for ipAddress in allowedIpAddressesNoEmptyString: {
    action: 'Allow'
    value: ipAddress
  }
]

// Backing storage for Azure app service
module storage 'br/public:avm/res/storage/storage-account:0.8.3' = {
  name: 'storage'
  scope: rg
  params: {
    name: !empty(storageAccountName) ? storageAccountName : '${abbrs.storageStorageAccounts}${resourceToken}'
    allowBlobPublicAccess: false
    allowSharedKeyAccess: false // Disable local authentication methods as per policy
    dnsEndpointType: 'Standard'
    publicNetworkAccess: vnetEnabled ? 'Disabled' : 'Enabled'
    networkAcls: vnetEnabled
      ? {
          defaultAction: 'Deny'
          bypass: 'None'
          ipRules: empty(allowedIpAddressesNoEmptyString) ? [] : ipRules
        }
      : {
          defaultAction: 'Allow'
          bypass: 'AzureServices'
          ipRules: empty(allowedIpAddressesNoEmptyString) ? [] : ipRules
        }
    blobServices: {
      containers: [{ name: deploymentStorageContainerName }]
    }
    minimumTlsVersion: 'TLS1_2' // Enforcing TLS 1.2 for better security
    location: location
    tags: tags
  }
}

// Define the configuration object locally to pass to the modules
var storageEndpointConfig = {
  enableBlob: true // Required for AzureWebJobsStorage, .zip deployment, Event Hubs trigger and Timer trigger checkpointing
  enableQueue: false // Required for Durable Functions and MCP trigger
  enableTable: false // Required for Durable Functions and OpenAI triggers and bindings
  enableFiles: false // Not required, used in legacy scenarios
  allowUserIdentityPrincipal: true // Allow interactive user identity to access for testing and debugging
}

// Consolidated Role Assignments
module rbac 'app/rbac.bicep' = {
  name: 'rbacAssignments'
  scope: rg
  params: {
    storageAccountName: storage.outputs.name
    appInsightsName: monitoring.outputs.name
    managedIdentityPrincipalId: webServiceIdentityType == 'UserAssigned'
      ? webUserAssignedIdentity!.outputs.principalId
      : appservice.outputs.serviceIdentityPrincipalId
    userIdentityPrincipalId: principalId
    enableBlob: storageEndpointConfig.enableBlob
    enableQueue: storageEndpointConfig.enableQueue
    enableTable: storageEndpointConfig.enableTable
    allowUserIdentityPrincipal: storageEndpointConfig.allowUserIdentityPrincipal
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

module storagePrivateEndpoint 'app/storage-PrivateEndpoint.bicep' = if (vnetEnabled) {
  name: 'servicePrivateEndpoint'
  scope: rg
  params: {
    location: location
    tags: tags
    virtualNetworkName: !empty(vNetName) ? vNetName : '${abbrs.networkVirtualNetworks}${resourceToken}'
    subnetName: vnetEnabled ? serviceVirtualNetwork.outputs.peSubnetName : '' // Keep conditional check for safety, though module won't run if !vnetEnabled
    resourceName: storage.outputs.name
    enableBlob: storageEndpointConfig.enableBlob
    enableQueue: storageEndpointConfig.enableQueue
    enableTable: storageEndpointConfig.enableTable
  }
}

// Monitor application with Azure Monitor - Log Analytics and Application Insights
module logAnalytics 'br/public:avm/res/operational-insights/workspace:0.11.1' = {
  name: '${uniqueString(deployment().name, location)}-loganalytics'
  scope: rg
  params: {
    name: !empty(logAnalyticsName) ? logAnalyticsName : '${abbrs.operationalInsightsWorkspaces}${resourceToken}'
    location: location
    tags: tags
    dataRetention: 30
  }
}

module monitoring 'br/public:avm/res/insights/component:0.6.0' = {
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
module vault 'br/public:avm/res/key-vault/vault:0.12.1' = if (addKeyVault) {
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
module botUserAssignedIdentity 'br/public:avm/res/managed-identity/user-assigned-identity:0.4.2' = if (botAppType == 'UserAssignedMSI') {
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
    applicationClientId: botAppType == 'UserAssignedMSI' ? botUserAssignedIdentity!.outputs.clientId : resourceAppRegistration!.outputs.clientId
    tenantId: tenant().tenantId
    endpoint: 'https://${appservice.outputs.serviceDefaultHostName}/api/messages'
  }
}


// App outputs
output AZURE_LOCATION string = location
output AZURE_TENANT_ID string = tenant().tenantId
output APPSERVICE_NAME string = appservice.outputs.serviceName
output APPSERVICE_DEFAULT_HOST_NAME string = appservice.outputs.serviceDefaultHostName
output BOTSERVICE_MSI_CLIENT_ID string = botAppType == 'UserAssignedMSI' ? botUserAssignedIdentity!.outputs.clientId : ''
output APP_CLIENT_ID string = botAppType == 'SingleTenant' ? resourceAppRegistration!.outputs.clientId : ''
output APP_DISPLAY_NAME string = botAppType == 'SingleTenant' ? resourceAppRegistration!.outputs.displayName : ''
output APP_UNIQUE_NAME string = botAppType == 'SingleTenant' ? resourceAppRegistration!.outputs.uniqueName : ''
