param name string
@allowed(['global', 'westeurope', 'westus', 'centralindia'])
param location string = 'global'
param tags object = {}

@allowed(['SingleTenant', 'UserAssignedMSI'])
param appType string
param UserAssignedManagedIdentityResourceId string
param applicationClientId string
param UserAssignedManagedIdentityTenantId string
param endpoint string = 'https://example.com/api/messages'

resource bot 'Microsoft.BotService/botServices@2023-09-15-preview' = {
  location: location
  name: 'bot-service-${name}'
  tags: tags
  kind: 'azurebot'
  sku: {
    name: 'F0'
  }
  properties: {
    displayName: name
    endpoint: endpoint
    msaAppId: applicationClientId
    msaAppMSIResourceId: UserAssignedManagedIdentityResourceId
    msaAppTenantId: UserAssignedManagedIdentityTenantId
    msaAppType: appType
    openWithHint: ''
  }
}
