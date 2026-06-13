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

@description('Name for the Azure AI Services account.')
param AI_SERVICES_NAME string = 'claims-foundry-ai'

@description('Name for the Microsoft Foundry project.')
param FOUNDRY_PROJECT_NAME string = 'claims-foundry-project'

@description('Model to deploy (e.g. gpt-4.1, gpt-4o).')
param AZURE_AI_MODEL_DEPLOYMENT_NAME string = 'gpt-4.1'

@description('Model version to deploy.')
param AI_MODEL_VERSION string = '2025-04-14'

@description('Model SKU capacity (thousands of tokens per minute).')
param AI_MODEL_CAPACITY int = 10

@description('CPU allocated to the container app.')
param CONTAINER_CPU int = 1

@description('Memory allocated to the container app.')
param CONTAINER_MEMORY string = '2Gi'

var cognitiveServicesOpenAiUserRoleDefinitionId = '5e0bd9bd-7b93-4f28-af87-19fc36ad61bd'
var acrPullRoleDefinitionId = '7f951dda-4ed3-4680-a7ca-43fe172d538d'

// --- AI Services ---

resource aiServices 'Microsoft.CognitiveServices/accounts@2025-04-01-preview' = {
  name: AI_SERVICES_NAME
  location: AZURE_LOCATION
  kind: 'AIServices'
  sku: {
    name: 'S0'
  }
  properties: {
    customSubDomainName: AI_SERVICES_NAME
    publicNetworkAccess: 'Enabled'
    allowProjectManagement: true
  }
}

resource modelDeployment 'Microsoft.CognitiveServices/accounts/deployments@2025-04-01-preview' = {
  parent: aiServices
  name: AZURE_AI_MODEL_DEPLOYMENT_NAME
  sku: {
    name: 'Standard'
    capacity: AI_MODEL_CAPACITY
  }
  properties: {
    model: {
      format: 'OpenAI'
      name: AZURE_AI_MODEL_DEPLOYMENT_NAME
      version: AI_MODEL_VERSION
    }
  }
}

resource foundryProject 'Microsoft.CognitiveServices/accounts/projects@2025-04-01-preview' = {
  parent: aiServices
  name: FOUNDRY_PROJECT_NAME
  location: AZURE_LOCATION
  properties: {
    projectKind: 'Foundry'
    description: 'Claims Foundry agent project'
  }
}

// --- Logging & Environment ---

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

// --- Identity & RBAC ---

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

resource openAiUserRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(aiServices.id, managedIdentity.id, cognitiveServicesOpenAiUserRoleDefinitionId)
  scope: aiServices
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

// --- Container App ---

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
    openAiUserRoleAssignment
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
              value: '${aiServices.properties.endpoint}api/projects/${FOUNDRY_PROJECT_NAME}'
            }
            {
              name: 'AZURE_AI_MODEL_DEPLOYMENT_NAME'
              value: AZURE_AI_MODEL_DEPLOYMENT_NAME
            }
            {
              name: 'AZURE_CLIENT_ID'
              value: managedIdentity.properties.clientId
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

// --- Outputs ---

output containerAppId string = containerApp.id
output containerAppName string = containerApp.name
output containerAppFqdn string = containerApp.properties.configuration.ingress.fqdn
output containerAppsEnvironmentId string = containerAppsEnvironment.id
output logAnalyticsWorkspaceId string = logAnalytics.id
output managedIdentityClientId string = managedIdentity.properties.clientId
output managedIdentityPrincipalId string = managedIdentity.properties.principalId
output AZURE_CONTAINER_REGISTRY_ENDPOINT string = containerRegistry.properties.loginServer
output aiServicesEndpoint string = aiServices.properties.endpoint
output aiServicesName string = aiServices.name
output foundryProjectEndpoint string = '${aiServices.properties.endpoint}api/projects/${FOUNDRY_PROJECT_NAME}'
