targetScope = 'subscription'

@minLength(1)
@maxLength(64)
param environmentName string

@minLength(1)
param location string

param sessionId string
param deployedBy string
param createdAt string
param deployerObjectId string

param containerImage string = 'mcr.microsoft.com/azuredocs/containerapps-helloworld:latest'

var resourceGroupName = 'rg-snowbridge-dev-624a'
var containerEnvironmentName = 'cae-snowbridge-dev-624a'
var containerAppName = 'ca-snowbridge-dev-624a'
var containerRegistryName = 'crsnowbridgedev624a'
var logAnalyticsName = 'log-snowbridge-dev-624a'
var applicationInsightsName = 'appi-snowbridge-dev-624a'
var keyVaultName = 'kv-snowbridge-dev-624a'
var foundryAccountName = 'rayfelipe-project1-resource'
var foundryResourceGroupName = 'rg-rayfelipe-project1'
var foundryDeploymentName = 'snowbridge-gpt-41-mini'

var tags = {
  'app-onboard-skill': 'true'
  'app-onboard-session-id': sessionId
  'created-at': createdAt
  environment: environmentName
  'deployed-by': deployedBy
}

resource rg 'Microsoft.Resources/resourceGroups@2023-07-01' = {
  name: resourceGroupName
  location: location
  tags: tags
}

module logAnalytics './modules/log-analytics.bicep' = {
  name: 'log-analytics'
  scope: rg
  params: {
    location: location
    name: logAnalyticsName
    tags: tags
  }
}

module applicationInsights './modules/application-insights.bicep' = {
  name: 'application-insights'
  scope: rg
  params: {
    location: location
    name: applicationInsightsName
    tags: tags
    workspaceName: logAnalyticsName
  }
  dependsOn: [
    logAnalytics
  ]
}

module containerRegistry './modules/container-registry.bicep' = {
  name: 'container-registry'
  scope: rg
  params: {
    location: location
    name: containerRegistryName
    tags: tags
  }
}

module keyVault './modules/key-vault.bicep' = {
  name: 'key-vault'
  scope: rg
  params: {
    location: location
    name: keyVaultName
    tags: tags
  }
}

module containerEnvironment './modules/container-app-environment.bicep' = {
  name: 'container-app-environment'
  scope: rg
  params: {
    location: location
    name: containerEnvironmentName
    tags: tags
    workspaceName: logAnalyticsName
  }
  dependsOn: [
    logAnalytics
  ]
}

module foundryDeployment './modules/foundry-deployment.bicep' = {
  name: 'foundry-deployment'
  scope: resourceGroup(foundryResourceGroupName)
  params: {
    accountName: foundryAccountName
    deploymentName: foundryDeploymentName
    modelVersion: '2025-04-14'
  }
}

module containerApp './modules/container-app.bicep' = {
  name: 'container-app'
  scope: rg
  params: {
    location: location
    name: containerAppName
    tags: tags
    environmentName: containerEnvironmentName
    registryName: containerRegistryName
    applicationInsightsName: applicationInsightsName
    foundryEndpoint: foundryDeployment.outputs.endpoint
    foundryDeploymentName: foundryDeploymentName
    containerImage: containerImage
    appPort: 8000
  }
  dependsOn: [
    applicationInsights
    containerEnvironment
    containerRegistry
    keyVault
  ]
}

module roleAssignments './modules/role-assignments.bicep' = {
  name: 'role-assignments'
  scope: rg
  params: {
    appPrincipalId: containerApp.outputs.principalId
    deployerObjectId: deployerObjectId
    registryName: containerRegistryName
    keyVaultName: keyVaultName
  }
  dependsOn: [
    containerRegistry
    keyVault
  ]
}

module foundryRoleAssignment './modules/foundry-role-assignment.bicep' = {
  name: 'foundry-role-assignment'
  scope: resourceGroup(foundryResourceGroupName)
  params: {
    appPrincipalId: containerApp.outputs.principalId
    accountName: foundryAccountName
  }
  dependsOn: [
    foundryDeployment
  ]
}

output containerAppName string = containerAppName
output containerAppFqdn string = containerApp.outputs.fqdn
output containerRegistryName string = containerRegistryName
output keyVaultName string = keyVaultName
output foundryDeploymentName string = foundryDeploymentName
