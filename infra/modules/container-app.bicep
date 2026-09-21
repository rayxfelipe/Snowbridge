param location string
param name string
param tags object
param environmentName string
param registryName string
param applicationInsightsName string
param foundryEndpoint string
param foundryDeploymentName string
param containerImage string = 'mcr.microsoft.com/azuredocs/containerapps-helloworld:latest'
param appPort int

var placeholderImage = 'mcr.microsoft.com/azuredocs/containerapps-helloworld:latest'
var isPlaceholder = containerImage == placeholderImage
var effectivePort = isPlaceholder ? 80 : appPort

resource environment 'Microsoft.App/managedEnvironments@2026-01-01' existing = {
  name: environmentName
}

resource registry 'Microsoft.ContainerRegistry/registries@2025-11-01' existing = {
  name: registryName
}

resource applicationInsights 'Microsoft.Insights/components@2020-02-02' existing = {
  name: applicationInsightsName
}

resource containerApp 'Microsoft.App/containerApps@2026-01-01' = {
  name: name
  location: location
  tags: tags
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    managedEnvironmentId: environment.id
    configuration: {
      activeRevisionsMode: 'Single'
      ingress: {
        external: true
        targetPort: effectivePort
        allowInsecure: false
        transport: 'auto'
      }
      registries: isPlaceholder
        ? []
        : [
            {
              server: registry.properties.loginServer
              identity: 'system'
            }
          ]
      secrets: []
    }
    template: {
      containers: [
        {
          name: 'snowbridge'
          image: containerImage
          env: [
            {
              name: 'PORT'
              value: string(effectivePort)
            }
            {
              name: 'SNOWBRIDGE_APP_NAME'
              value: 'Snowbridge'
            }
            {
              name: 'SNOWBRIDGE_ENVIRONMENT'
              value: 'development'
            }
            {
              name: 'SNOWBRIDGE_SNOWFLAKE_BACKEND'
              value: 'mock'
            }
            {
              name: 'SNOWBRIDGE_AI_BACKEND'
              value: 'foundry'
            }
            {
              name: 'SNOWBRIDGE_FOUNDRY_ENDPOINT'
              value: foundryEndpoint
            }
            {
              name: 'SNOWBRIDGE_FOUNDRY_DEPLOYMENT'
              value: foundryDeploymentName
            }
            {
              name: 'SNOWBRIDGE_FOUNDRY_API_VERSION'
              value: '2025-04-01-preview'
            }
            {
              name: 'SNOWBRIDGE_SNOWFLAKE_LOGIN_TIMEOUT_SECONDS'
              value: '15'
            }
            {
              name: 'SNOWBRIDGE_SNOWFLAKE_NETWORK_TIMEOUT_SECONDS'
              value: '30'
            }
            {
              name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
              value: applicationInsights.properties.ConnectionString
            }
          ]
          probes: isPlaceholder
            ? []
            : [
                {
                  type: 'Liveness'
                  httpGet: {
                    path: '/health'
                    port: appPort
                    scheme: 'HTTP'
                  }
                  initialDelaySeconds: 10
                  periodSeconds: 30
                }
                {
                  type: 'Readiness'
                  httpGet: {
                    path: '/health'
                    port: appPort
                    scheme: 'HTTP'
                  }
                  initialDelaySeconds: 5
                  periodSeconds: 10
                }
              ]
          resources: {
            cpu: '0.5'
            memory: '1Gi'
          }
        }
      ]
      scale: {
        minReplicas: 0
        maxReplicas: 1
      }
    }
  }
}

output id string = containerApp.id
output principalId string = containerApp.identity.principalId
output fqdn string = containerApp.properties.configuration.ingress.fqdn
