param dataCollectionRuleName string 
param logAnalyticsWorkspaceResourceId string 
param logAnalyticsWorkspaceId string 
param logAnalyticsCustomTable string 
param servicePrincipalId string
var location string = resourceGroup().location

resource dataCollectionRule 'Microsoft.Insights/dataCollectionRules@2023-03-11' = {
  name: dataCollectionRuleName
  location: location
  kind: 'Direct'
  properties: {
    streamDeclarations: {
            'Custom-Howler': {
                columns: [
                    {
                        name: 'TimeGenerated'
                        type: 'datetime'
                    }
                    {
                        name: 'Title'
                        type: 'string'
                    }
                    {
                        name: 'RawData'
                        type: 'dynamic'
                    }
                ]
            }
        }
        dataSources: {}
        destinations: {
            logAnalytics: [
                {
                    workspaceResourceId: logAnalyticsWorkspaceResourceId
                    workspaceId: logAnalyticsWorkspaceId
                    name: logAnalyticsWorkspaceId
                }
            ]
        }
        dataFlows: [
            {
                streams: [
                    'Custom-Howler'
                ]
                destinations: [
                    logAnalyticsWorkspaceId
                ]
                transformKql: 'source'
                outputStream: 'Custom-${logAnalyticsCustomTable}'
            }
        ]
  }
}

resource dataCollectionRulePublisher 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(dataCollectionRule.id, 'Monitoring Metrics Publisher')
  scope: dataCollectionRule
  properties: {
    principalId: servicePrincipalId
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '3913510d-42f4-4e42-8a64-420c390055eb')
    principalType: 'ServicePrincipal'
  }
}
