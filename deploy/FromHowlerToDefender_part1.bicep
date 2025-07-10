param logAnalyticsWorkspaceResourceId string
param logAnalyticsCustomTable string 
param logAnalyticsWorkspaceId string 
param queryRuleName string 

resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2025-02-01' existing = {
 name: last(split(logAnalyticsWorkspaceResourceId, '/'))
}

resource logAnalyticsTable 'Microsoft.OperationalInsights/workspaces/tables@2025-02-01' = {
  name: '${logAnalyticsCustomTable}'
  parent: logAnalyticsWorkspace
  properties: {
    plan: 'Analytics'
    schema: {
     name: '${logAnalyticsCustomTable}'
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
}

resource queryRule 'Microsoft.SecurityInsights/alertRules@2023-12-01-preview' = {
  name: guid(logAnalyticsWorkspaceId, queryRuleName)
  scope: logAnalyticsWorkspace
  dependsOn: [
    logAnalyticsTable
  ]
  kind: 'NRT'
  properties: {
   displayName: queryRuleName
   description: 'Creates an incident from a HOWLER promoted hit.'
   severity: 'Informational'
   enabled: true
   query: '${logAnalyticsCustomTable}\r\n| extend HowlerId = RawData.Hit.howler.id\r\n| where isnotempty(HowlerId)\r\n| extend Severity = toint(RawData.Hit.event.severity)\r\n| extend Severity = case( Severity in (75,50), \'High\', Severity == 25, \'Medium\', Severity == 10, \'Low\', \'Informational\')\r\n| extend IPSource = RawData.Hit.source.ip\r\n| extend IPDestination = RawData.Hit.destination.ip\r\n| extend User = RawData.Hit.related.user[0]\r\n| extend Host = RawData.Hit.related.hosts[0]\r\n| extend File = RawData.Hit.related.hash[0]\r\n| extend Description = RawData.Hit.rule.description\r\n| extend Source = \'Howler\''
   suppressionDuration: 'PT5H'
   suppressionEnabled: false
   tactics: []
   techniques: []
   subTechniques: []
   alertRuleTemplateName: null
   incidentConfiguration: {
    createIncident: true
    groupingConfiguration: {
      enabled: false
      reopenClosedIncident: false
      lookbackDuration: 'PT5H'
      matchingMethod: 'AllEntities'
      groupByEntities: []
      groupByAlertDetails: []
      groupByCustomDetails: []
    }
  }
  eventGroupingSettings: {
   aggregationKind: 'AlertPerResult'
  }
  alertDetailsOverride: {
   alertDisplayNameFormat: 'HOWLER Promoted Hit - {{Title}}'
   alertDescriptionFormat: '{{Description}} '
   alertSeverityColumnName: 'Severity'
   alertDynamicProperties: [
    {
     alertProperty: 'ProductName'
     value: 'Source'
    }
    {
     alertProperty: 'ProviderName'
     value: 'Source'
    }
   ]
  }
  customDetails: {
   HowlerId: 'HowlerId'
  }
  entityMappings: [
   {
    entityType: 'IP'
    fieldMappings: [
     {
      identifier: 'Address'
      columnName: 'IPSource'
     }
    ]
   }
   {
    entityType: 'IP'
    fieldMappings: [
     {
      identifier: 'Address'
      columnName: 'IPDestination'
     }
    ]
   }
   {
    entityType: 'Host'
    fieldMappings: [
     {
      identifier: 'HostName'
      columnName: 'Host'
     }
    ]
   }
   {
    entityType: 'Account'
    fieldMappings: [
     {
      identifier: 'FullName'
      columnName: 'User'
     }
    ]
   }
   {
    entityType: 'FileHash'
    fieldMappings: [
     {
      identifier: 'Value'
      columnName: 'File'
     }
    ] 
  }
  ]
  sentinelEntitiesMappings: null
  templateVersion: null
 }
}
