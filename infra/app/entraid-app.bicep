extension microsoftGraphV1

param appRegistrationName string

// https://learn.microsoft.com/en-us/graph/templates/reference/applications?view=graph-bicep-1.0
resource resourceApp 'Microsoft.Graph/applications@v1.0' = {
  displayName: appRegistrationName
  uniqueName: appRegistrationName

  // Create a client secret
  passwordCredentials: [
    {
      displayName: 'generated during template deployment'
    }
  ]
}

// Create the service principal
resource servicePrincipal 'Microsoft.Graph/servicePrincipals@v1.0' = {
  appId: resourceApp.appId
}

output clientId string = resourceApp.appId
output displayName string = resourceApp.displayName
output uniqueName string = resourceApp.uniqueName
