/*
  File: FromHowlerToDefender_main.bicep
  Version: 1.0
  Author: piaudonn
  Date: 2025-07-10

  Description:
   - This template deploys:
    - A Data Collection Rule of Direct kind (no need to create a Data Collection Endpoint for API ingestion then)
    - A custom table in an existing Log Analytics Workspace where Sentinel is enabled
    - An analytic rule in Sentinel that creates an incident from a howler hit with limited entity mapping
   - This also grant an existing service principal the Monitoring Metrics Publisher role on the Data Collection Rule
  
*/


@description('Name of the Data Collection Rule')
param dataCollectionRuleName string = 'DCR-Howler'

@description('Resource ID of the Log Analytics Workspace where Sentinel is enabled')
param logAnalyticsWorkspaceResourceId string = '/subscriptions/397cdfbc-d326-412f-acdd-f3a40db4aaee/resourceGroups/oi-default-east-us/providers/microsoft.operationalinsights/workspaces/briandel'

@description('Workspace ID of the Log Analytics Workspace where Sentinel is enabled')
param logAnalyticsWorkspaceId string = '6ba2759c-1c00-4aa0-88e8-138379ea383c'

@description('Name of the custom table for howler hit (it needs to ends with _CL)')
param logAnalyticsCustomTable string = 'Howler_CL'

@description('Name of the analytic rule in Sentinel that will create an incident from a howler hit')
param queryRuleName string = 'Create Incident from Hit'

@description('Client ID of the service principal that will be used to send data from Howler')
param servicePrincipalId string = 'b3f0c8d2-1a4e-4b5c-9f6d-7c8e1f2a3b4c'

//Used to split the deployement into two parts in case Sentinel is not in the same resource group as the Data Collection Rule
var deploymentScopeData = split(logAnalyticsWorkspaceResourceId, '/')

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

