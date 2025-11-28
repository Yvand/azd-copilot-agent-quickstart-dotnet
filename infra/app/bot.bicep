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

// resource botCreated 'Microsoft.BotService/botServices@2023-09-15-preview' existing = {
//   dependsOn: [
//     bot
//   ]
//   scope: resourceGroup()
//   name: bot.name
// }

// resource teamsChannel 'Microsoft.BotService/botServices/channels@2023-09-15-preview' = {
//   parent: botCreated
//   name: 'MsTeamsChannel'
//   properties: {
//     channelName: 'MsTeamsChannel'
//     properties: {
//       acceptedTerms: true
//       callingWebhook: 'string'
//       deploymentEnvironment: 'string'
//       enableCalling: true
//       incomingCallRoute: 'string'
//       isEnabled: true
//     }
//   }
// }

// resource directLineChannel 'Microsoft.BotService/botServices/channels@2023-09-15-preview' = {
//   parent: botCreated
//   name: 'DirectLineChannel'
//   properties: {
//     channelName: 'DirectLineChannel'
//     properties: {
//       extensionKey1: 'string'
//       extensionKey2: 'string'
//       sites: [
//         {
//           appId: 'string'
//           eTag: 'string'
//           isBlockUserUploadEnabled: bool
//           isDetailedLoggingEnabled: true
//           isEnabled: true
//           isEndpointParametersEnabled: bool
//           isNoStorageEnabled: bool
//           isSecureSiteEnabled: bool
//           isV1Enabled: bool
//           isV3Enabled: bool
//           isWebchatPreviewEnabled: true
//           isWebChatSpeechEnabled: bool
//           siteName: 'Default Site'
//           tenantId: tenant().tenantId
//           trustedOrigins: [
//             'string'
//           ]
//         }
//       ]
//     }
//   }
// }

// resource webChatChannel 'Microsoft.BotService/botServices/channels@2023-09-15-preview' = {
//   parent: botCreated
//   name: 'WebChatChannel'
//   properties: {
//     channelName: 'WebChatChannel'
//     properties: {
//       sites: [
//         {
//           appId: 'string'
//           eTag: 'string'
//           isBlockUserUploadEnabled: bool
//           isDetailedLoggingEnabled: true
//           isEnabled: true
//           isEndpointParametersEnabled: bool
//           isNoStorageEnabled: bool
//           isSecureSiteEnabled: bool
//           isV1Enabled: bool
//           isV3Enabled: bool
//           isWebchatPreviewEnabled: true
//           isWebChatSpeechEnabled: bool
//           siteName: 'Default Site'
//           tenantId: tenant().tenantId
//           trustedOrigins: [
//             'string'
//           ]
//         }
//       ]
//     }
//   }
// }
