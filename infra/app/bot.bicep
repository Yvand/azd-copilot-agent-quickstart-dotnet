param name string
@allowed(['global', 'westeurope', 'westus', 'centralindia'])
param location string = 'westeurope'
param tags object = {}

param sku string = 'F0'
@allowed(['SingleTenant', 'UserAssignedMSI'])
param appType string
param UserAssignedManagedIdentityResourceId string
param applicationClientId string
param tenantId string
param endpoint string

resource bot 'Microsoft.BotService/botServices@2023-09-15-preview' = {
  location: location
  name: 'bot-service-${name}'
  tags: tags
  kind: 'azurebot'
  sku: {
    name: sku
  }
  properties: {
    displayName: name
    endpoint: endpoint
    msaAppId: applicationClientId
    msaAppMSIResourceId: UserAssignedManagedIdentityResourceId
    msaAppTenantId: tenantId
    msaAppType: appType
    openWithHint: ''
    appPasswordHint: ''
    tenantId: tenantId
  }
}

resource teamsChannel 'Microsoft.BotService/botServices/channels@2023-09-15-preview' = {
  parent: bot
  name: 'MsTeamsChannel'
  location: location
  properties: {
    channelName: 'MsTeamsChannel'
    properties: {
      acceptedTerms: true
      enableCalling: true
      isEnabled: true
    }
  }
}

output botServiceName string = bot.name
