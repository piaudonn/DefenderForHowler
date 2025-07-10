param dataCollectionRuleName string = 'DCR-Howler'

param logAnalyticsWorkspaceResourceId string = '/subscriptions/397cdfbc-d326-412f-acdd-f3a40db4aaee/resourceGroups/oi-default-east-us/providers/microsoft.operationalinsights/workspaces/briandel'
param logAnalyticsWorkspaceId string = '6ba2759c-1c00-4aa0-88e8-138379ea383c'

param logAnalyticsCustomTable string = 'Howler_CL'
param queryRuleName string = 'Create Incident from Hit'

var deploymentScopeData = split(logAnalyticsWorkspaceResourceId, '/')

param servicePrincipalId string = 'b3f0c8d2-1a4e-4b5c-9f6d-7c8e1f2a3b4c' // Replace with your service principal ID

module logAnalyticsPart './FromHowlerToDefender_part1.bicep' = {
  name: 'logAnalyticsPart'
  scope: resourceGroup(deploymentScopeData[2], deploymentScopeData[4])
  params: {
    logAnalyticsWorkspaceResourceId: logAnalyticsWorkspaceResourceId
    logAnalyticsCustomTable: logAnalyticsCustomTable
    logAnalyticsWorkspaceId: logAnalyticsWorkspaceId
    queryRuleName: queryRuleName
  }
}

module dataCollectionRulePart './FromHowlerToDefender_part2.bicep' = {
  name: 'dataCollectionRulePart'
  scope: resourceGroup()
  params: {
    dataCollectionRuleName: dataCollectionRuleName
    logAnalyticsWorkspaceId: logAnalyticsWorkspaceId
    logAnalyticsCustomTable: logAnalyticsCustomTable
    logAnalyticsWorkspaceResourceId: logAnalyticsWorkspaceResourceId
    servicePrincipalId: servicePrincipalId
  }
  dependsOn: [
    logAnalyticsPart
  ]
}

