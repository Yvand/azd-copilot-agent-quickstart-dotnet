param name string
@allowed(['global', 'westeurope', 'westus', 'centralindia'])
param location string = 'global'
param tags object = {}

param UserAssignedManagedIdentityResourceId string
param UserAssignedManagedIdentityClientId string
param UserAssignedManagedIdentityTenantId string
param endpoint string = 'https://example.com/api/messages'

resource symbolicname 'Microsoft.BotService/botServices@2023-09-15-preview' = {
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
    msaAppId: UserAssignedManagedIdentityClientId
    msaAppMSIResourceId: UserAssignedManagedIdentityResourceId
    msaAppTenantId: UserAssignedManagedIdentityTenantId
    msaAppType: 'UserAssignedMSI'
    openWithHint: ''
  }
}
