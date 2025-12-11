param appInsightsName string
param keyVaultName string = ''
param managedIdentityPrincipalId string // Principal ID for the Managed Identity
param userIdentityPrincipalId string = '' // Principal ID for the User Identity
param allowUserIdentityPrincipal bool = false // Flag to enable user identity role assignments

// Define Role Definition IDs internally
var monitoringRoleDefinitionId = '3913510d-42f4-4e42-8a64-420c390055eb' // Monitoring Metrics Publisher role ID
var keyVaultSecretsUserRoleDefinitionId = '4633458b-17de-408a-b874-0445c86b69e6' // Key Vault Secrets User role ID
var keyVaultAdministratorRoleDefinitionId = '00482a5a-887f-4fb3-b363-3b7fe8e74483' // Key Vault Administrator role ID

resource applicationInsights 'Microsoft.Insights/components@2020-02-02' existing = {
  name: appInsightsName
}

resource keyVault 'Microsoft.KeyVault/vaults@2025-05-01' existing = if (!empty(keyVaultName)) {
  name: keyVaultName
}

// Role assignment for Application Insights - Managed Identity
resource appInsightsRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(applicationInsights.id, managedIdentityPrincipalId, monitoringRoleDefinitionId) // Use managed identity ID
  scope: applicationInsights
  properties: {
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', monitoringRoleDefinitionId)
    principalId: managedIdentityPrincipalId // Use managed identity ID
    principalType: 'ServicePrincipal' // Managed Identity is a Service Principal
  }
}

// Role assignment for Application Insights - User Identity
resource appInsightsRoleAssignment_User 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (allowUserIdentityPrincipal && !empty(userIdentityPrincipalId)) {
  name: guid(applicationInsights.id, userIdentityPrincipalId, monitoringRoleDefinitionId)
  scope: applicationInsights
  properties: {
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', monitoringRoleDefinitionId)
    principalId: userIdentityPrincipalId // Use user identity ID
    principalType: 'User' // User Identity is a User Principal
  }
}

// Role assignment for the key-vault - Managed Identity
resource vaultRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (!empty(keyVaultName)) {
  name: guid(keyVault.id, managedIdentityPrincipalId, keyVaultSecretsUserRoleDefinitionId)
  scope: keyVault
  properties: {
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', keyVaultSecretsUserRoleDefinitionId)
    principalId: managedIdentityPrincipalId
    principalType: 'ServicePrincipal'
  }
}

// Role assignment for the key-vault - User Identity
resource vaultRoleAssignment_User 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (!empty(keyVaultName)) {
  name: guid(keyVault.id, userIdentityPrincipalId, keyVaultAdministratorRoleDefinitionId)
  scope: keyVault
  properties: {
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', keyVaultAdministratorRoleDefinitionId)
    principalId: userIdentityPrincipalId
    principalType: 'User'
  }
}
