targetScope = 'resourceGroup'

@description('Azure location for the demo resources.')
param AZURE_LOCATION string = resourceGroup().location

@description('Name for the Container App that hosts the Foundry agent.')
param CONTAINER_APP_NAME string = 'claims-foundry-agent'

@description('Name for the Container Apps managed environment.')
param CONTAINER_APPS_ENVIRONMENT_NAME string = 'claims-foundry-env'

@description('Name for the Log Analytics workspace.')
param LOG_ANALYTICS_WORKSPACE_NAME string = 'claims-foundry-logs'

@description('Name for the user-assigned managed identity used by the container app.')
param MANAGED_IDENTITY_NAME string = 'claims-foundry-agent-mi'

@description('Container image to run inside the Foundry agent container app.')
param CONTAINER_IMAGE string = 'mcr.microsoft.com/azuredocs/containerapps-helloworld:latest'

@description('Name for the Azure Container Registry.')
param CONTAINER_REGISTRY_NAME string = 'claimsfoundryacr'

@description('Foundry project endpoint exposed to the container app as FOUNDRY_PROJECT_ENDPOINT.')
param FOUNDRY_PROJECT_ENDPOINT string

@description('Model deployment name exposed to the container app as AZURE_AI_MODEL_DEPLOYMENT_NAME.')
param AZURE_AI_MODEL_DEPLOYMENT_NAME string = 'gpt-4.1'

@description('Optional Azure OpenAI account name in the current resource group used for the Cognitive Services OpenAI User role assignment.')
param OPENAI_ACCOUNT_NAME string = ''

@description('CPU allocated to the container app.')
param CONTAINER_CPU int = 1

@description('Memory allocated to the container app.')
param CONTAINER_MEMORY string = '2Gi'

var cognitiveServicesOpenAiUserRoleDefinitionId = 'e7332f29-82ae-436f-8842-345e8de50dd3'
var acrPullRoleDefinitionId = '7f951dda-4ed3-4680-a7ca-43fe172d538d'

resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  name: LOG_ANALYTICS_WORKSPACE_NAME
  location: AZURE_LOCATION
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 30
  }
}

resource containerAppsEnvironment 'Microsoft.App/managedEnvironments@2024-03-01' = {
  name: CONTAINER_APPS_ENVIRONMENT_NAME
  location: AZURE_LOCATION
  properties: {
    appLogsConfiguration: {
      destination: 'log-analytics'
      logAnalyticsConfiguration: {
        customerId: logAnalytics.properties.customerId
        sharedKey: logAnalytics.listKeys().primarySharedKey
      }
    }
  }
}

resource managedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: MANAGED_IDENTITY_NAME
  location: AZURE_LOCATION
}

resource containerRegistry 'Microsoft.ContainerRegistry/registries@2023-07-01' = {
  name: CONTAINER_REGISTRY_NAME
  location: AZURE_LOCATION
  sku: {
    name: 'Basic'
  }
  properties: {
    adminUserEnabled: false
  }
}

resource openAiAccount 'Microsoft.CognitiveServices/accounts@2023-05-01' existing = if (!empty(OPENAI_ACCOUNT_NAME)) {
  name: OPENAI_ACCOUNT_NAME
}

resource openAiUserRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (!empty(OPENAI_ACCOUNT_NAME)) {
  name: guid(openAiAccount.id, managedIdentity.id, cognitiveServicesOpenAiUserRoleDefinitionId)
  scope: openAiAccount
  properties: {
    principalId: managedIdentity.properties.principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', cognitiveServicesOpenAiUserRoleDefinitionId)
  }
}

resource acrPullRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(containerRegistry.id, managedIdentity.id, acrPullRoleDefinitionId)
  scope: containerRegistry
  properties: {
    principalId: managedIdentity.properties.principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', acrPullRoleDefinitionId)
  }
}

resource containerApp 'Microsoft.App/containerApps@2024-03-01' = {
  name: CONTAINER_APP_NAME
  location: AZURE_LOCATION
  tags: {
    'azd-service-name': 'claims-foundry-agent'
  }
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${managedIdentity.id}': {}
    }
  }
  dependsOn: [
    acrPullRoleAssignment
  ]
  properties: {
    managedEnvironmentId: containerAppsEnvironment.id
    configuration: {
      activeRevisionsMode: 'Single'
      ingress: {
        external: true
        targetPort: 8088
        transport: 'auto'
        allowInsecure: false
      }
      registries: [
        {
          server: containerRegistry.properties.loginServer
          identity: managedIdentity.id
        }
      ]
    }
    template: {
      containers: [
        {
          name: 'foundry-agent'
          image: CONTAINER_IMAGE
          env: [
            {
              name: 'PORT'
              value: '8088'
            }
            {
              name: 'FOUNDRY_PROJECT_ENDPOINT'
              value: FOUNDRY_PROJECT_ENDPOINT
            }
            {
              name: 'AZURE_AI_MODEL_DEPLOYMENT_NAME'
              value: AZURE_AI_MODEL_DEPLOYMENT_NAME
            }
          ]
          resources: {
            cpu: CONTAINER_CPU
            memory: CONTAINER_MEMORY
          }
        }
      ]
      scale: {
        minReplicas: 1
        maxReplicas: 1
      }
    }
  }
}

output containerAppId string = containerApp.id
output containerAppName string = containerApp.name
output containerAppFqdn string = containerApp.properties.configuration.ingress.fqdn
output containerAppsEnvironmentId string = containerAppsEnvironment.id
output logAnalyticsWorkspaceId string = logAnalytics.id
output managedIdentityClientId string = managedIdentity.properties.clientId
output managedIdentityPrincipalId string = managedIdentity.properties.principalId
output AZURE_CONTAINER_REGISTRY_ENDPOINT string = containerRegistry.properties.loginServer
