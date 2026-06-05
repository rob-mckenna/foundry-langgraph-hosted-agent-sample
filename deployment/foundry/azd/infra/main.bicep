targetScope = 'resourceGroup'

@description('Azure location for the demo resources.')
param location string = resourceGroup().location

@description('Name for the Container Apps managed environment.')
param containerAppsEnvironmentName string = 'claims-foundry-env'

@description('Name for the Log Analytics workspace.')
param logAnalyticsWorkspaceName string = 'claims-foundry-logs'

resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  name: logAnalyticsWorkspaceName
  location: location
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 30
  }
}

resource containerAppsEnvironment 'Microsoft.App/managedEnvironments@2024-03-01' = {
  name: containerAppsEnvironmentName
  location: location
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

output containerAppsEnvironmentId string = containerAppsEnvironment.id
output logAnalyticsWorkspaceId string = logAnalytics.id
