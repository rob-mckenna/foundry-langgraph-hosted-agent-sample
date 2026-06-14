targetScope = 'resourceGroup'

@description('Azure location for the demo resources.')
param AZURE_LOCATION string = resourceGroup().location

@description('Name for the standalone Container App (Azure OpenAI direct, no Foundry).')
param STANDALONE_CONTAINER_APP_NAME string = 'claims-standalone-agent'

@description('Name for the ACA-hosted Container App (calls models via Foundry project).')
param ACA_HOSTED_CONTAINER_APP_NAME string = 'claims-aca-agent'

@description('Name for the Container Apps managed environment.')
param CONTAINER_APPS_ENVIRONMENT_NAME string = 'claims-foundry-env'

@description('Name for the Log Analytics workspace.')
param LOG_ANALYTICS_WORKSPACE_NAME string = 'claims-foundry-logs'

@description('Name for the user-assigned managed identity used by the container apps.')
param MANAGED_IDENTITY_NAME string = 'claims-foundry-agent-mi'

@description('Placeholder container image (replaced by azd deploy).')
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

@description('CPU allocated to each container app.')
param CONTAINER_CPU int = 1

@description('Memory allocated to each container app.')
param CONTAINER_MEMORY string = '2Gi'

var cognitiveServicesOpenAiUserRoleDefinitionId = '5e0bd9bd-7b93-4f28-af87-19fc36ad61bd'
var acrPullRoleDefinitionId = '7f951dda-4ed3-4680-a7ca-43fe172d538d'
var acrPushRoleDefinitionId = '8311e382-0749-4cb8-b61a-304f252e45ec'
// Foundry User (formerly Azure AI User) — required for project identity to access account
var foundryUserRoleDefinitionId = '53ca6127-db72-4b80-b1b0-d745d6d5456d'
// Foundry Project Manager — required to deploy hosted agents
var foundryProjectManagerRoleDefinitionId = 'eadc314b-1a2d-4efa-be10-5d325db5065e'

// --- AI Services ---

resource aiServices 'Microsoft.CognitiveServices/accounts@2025-06-01' = {
  name: AI_SERVICES_NAME
  location: AZURE_LOCATION
  kind: 'AIServices'
  sku: {
    name: 'S0'
  }
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    allowProjectManagement: true
    customSubDomainName: AI_SERVICES_NAME
    disableLocalAuth: false
    publicNetworkAccess: 'Enabled'
  }
}

resource modelDeployment 'Microsoft.CognitiveServices/accounts/deployments@2025-06-01' = {
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

resource foundryProject 'Microsoft.CognitiveServices/accounts/projects@2025-06-01' = {
  parent: aiServices
  name: FOUNDRY_PROJECT_NAME
  location: AZURE_LOCATION
  identity: {
    type: 'SystemAssigned'
  }
  properties: {}
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

resource applicationInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: '${FOUNDRY_PROJECT_NAME}-appinsights'
  location: AZURE_LOCATION
  kind: 'web'
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: logAnalytics.id
  }
}

// --- Foundry Project Connections (required for Hosted Agent deployment) ---

resource acrConnection 'Microsoft.CognitiveServices/accounts/projects/connections@2025-06-01' = {
  parent: foundryProject
  name: 'acr-connection'
  properties: {
    category: 'ContainerRegistry'
    target: containerRegistry.properties.loginServer
    authType: 'ManagedIdentity'
    credentials: {
      resourceId: foundryProject.id
      clientId: foundryProject.identity.principalId
    }
    metadata: {
      ResourceId: containerRegistry.id
    }
  }
}

resource appInsightsConnection 'Microsoft.CognitiveServices/accounts/projects/connections@2025-06-01' = {
  parent: foundryProject
  name: 'appinsights-connection'
  properties: {
    category: 'AppInsights'
    target: applicationInsights.properties.ConnectionString
    authType: 'ApiKey'
    credentials: {
      key: applicationInsights.properties.InstrumentationKey
    }
    metadata: {
      ResourceId: applicationInsights.id
    }
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
    name: 'Standard'
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

// Grant the Foundry project identity AcrPull so Hosted Agent Service can pull images
resource acrPullForProjectRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(containerRegistry.id, foundryProject.id, acrPullRoleDefinitionId)
  scope: containerRegistry
  properties: {
    principalId: foundryProject.identity.principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', acrPullRoleDefinitionId)
  }
}

// Grant the Foundry project identity Foundry User on the AI Services account
// Required for the hosted agent to access models via the project endpoint
resource foundryUserForProjectRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(aiServices.id, foundryProject.id, foundryUserRoleDefinitionId)
  scope: aiServices
  properties: {
    principalId: foundryProject.identity.principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', foundryUserRoleDefinitionId)
  }
}

// Grant the deploying identity AcrPush so azd can push container images
resource acrPushForDeployerRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(containerRegistry.id, managedIdentity.id, acrPushRoleDefinitionId)
  scope: containerRegistry
  properties: {
    principalId: managedIdentity.properties.principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', acrPushRoleDefinitionId)
  }
}

// --- Container App: Standalone (Azure OpenAI direct, no Foundry) ---

resource standaloneContainerApp 'Microsoft.App/containerApps@2024-03-01' = {
  name: STANDALONE_CONTAINER_APP_NAME
  location: AZURE_LOCATION
  tags: {
    'azd-service-name': 'claims-standalone-agent'
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
        targetPort: 8080
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
          name: 'standalone-agent'
          image: CONTAINER_IMAGE
          env: [
            {
              name: 'AZURE_OPENAI_ENDPOINT'
              value: aiServices.properties.endpoint
            }
            {
              name: 'AZURE_OPENAI_DEPLOYMENT'
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

// --- Container App: ACA-hosted (calls models via Foundry project) ---

resource acaHostedContainerApp 'Microsoft.App/containerApps@2024-03-01' = {
  name: ACA_HOSTED_CONTAINER_APP_NAME
  location: AZURE_LOCATION
  tags: {
    'azd-service-name': 'claims-aca-agent'
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
          name: 'aca-hosted-agent'
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

output standaloneContainerAppFqdn string = standaloneContainerApp.properties.configuration.ingress.fqdn
output acaHostedContainerAppFqdn string = acaHostedContainerApp.properties.configuration.ingress.fqdn
output containerAppsEnvironmentId string = containerAppsEnvironment.id
output logAnalyticsWorkspaceId string = logAnalytics.id
output managedIdentityClientId string = managedIdentity.properties.clientId
output managedIdentityPrincipalId string = managedIdentity.properties.principalId
output AZURE_CONTAINER_REGISTRY_ENDPOINT string = containerRegistry.properties.loginServer
output aiServicesEndpoint string = aiServices.properties.endpoint
output aiServicesName string = aiServices.name
output FOUNDRY_PROJECT_ENDPOINT string = '${aiServices.properties.endpoint}api/projects/${FOUNDRY_PROJECT_NAME}'
output FOUNDRY_PROJECT_NAME string = FOUNDRY_PROJECT_NAME
output AZURE_AI_PROJECT_ID string = foundryProject.id
output AZURE_AI_MODEL_DEPLOYMENT_NAME string = AZURE_AI_MODEL_DEPLOYMENT_NAME
output AZURE_TENANT_ID string = tenant().tenantId
