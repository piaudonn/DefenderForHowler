/*
  File: FromDefenderToHowler.bicep
  Version: 1.1
  Author: piaudonn
  Date: 2025-07-09

  Description:
  - This template deploys a consumption Logic App that ingests Defender incidents (that include Sentinel incidents) into Howler.
  - You need to provide an API key for Howler and the URL of the Howler API.
  - The Logic App runs every 5 minutes by default, but you can change the recurrence interval. It uses a storage table to keep track of the last ingestion time.
  */

@description('Name of the Logic App')
@maxLength(80)
param logicAppName string = 'SnowyOwl'

@description('Name of keyvault to store API key')
param keyVaultName string = 'Owlery'
param APIKEY string = 'your-api-key-here'

@description('URL of the Howler API')
param APIURL string = 'https://howler/api/v1/sentinel/ingest'

@description('Name of the storage account to store the cursor')
@minLength(3)
@maxLength(24)
param storageAccountName string = 'trunks'

@description('Name of the table to store the cursor')
param tableName string = 'SnowyOwlCursor'

@description('Recurrence interval in minutes for the Logic App')
param recurrenceInterval int = 5

param location string = resourceGroup().location

resource storageAccount 'Microsoft.Storage/storageAccounts@2024-01-01' = {
  name: storageAccountName
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
}


resource tableService 'Microsoft.Storage/storageAccounts/tableServices@2022-09-01' = {
  name: 'default'
  parent: storageAccount
}

resource table 'Microsoft.Storage/storageAccounts/tableServices/tables@2024-01-01' = {
  name: tableName
  parent: tableService
}

resource tableWebConnection 'Microsoft.Web/connections@2016-06-01' = {
  name: 'connection-${storageAccountName}-${tableName}'
  location: location
  properties: {
    displayName: 'connection-${storageAccountName}-${tableName}'
    customParameterValues: {}
    parameterValueSet: {
      name: 'managedIdentityAuth'
    }

    api: {
      id: '/subscriptions/${subscription().subscriptionId}/providers/Microsoft.Web/locations/${resourceGroup().location}/managedApis/azuretables'
    }
  }
}

resource keyVaultWebConnection 'Microsoft.Web/connections@2016-06-01' = {
  name: 'connection-${keyVaultName}'
  location: location
  properties: {
    displayName: 'connection-${keyVaultName}'
    customParameterValues: {}
    parameterValueType: 'Alternative'
    alternativeParameterValues: {
      vaultName: keyVaultName
    }
    api: {
      id: '/subscriptions/${subscription().subscriptionId}/providers/Microsoft.Web/locations/${resourceGroup().location}/managedApis/keyvault'
    }
  }
}


resource keyVault 'Microsoft.KeyVault/vaults@2024-12-01-preview' = {
  name: keyVaultName
  location: location
    properties: {
      sku: {
        family: 'A'
        name: 'standard'
      }
      tenantId: subscription().tenantId
      accessPolicies: []
  }
}

resource keyVaultSecret 'Microsoft.KeyVault/vaults/secrets@2024-12-01-preview' = {
  parent: keyVault
  name: 'APIKEY'
  properties: {
    value: APIKEY
    attributes: {
      enabled: true
    }
  }
}

resource logicApp 'Microsoft.Logic/workflows@2017-07-01' = {
  name: logicAppName
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    state: 'Enabled'
    definition: {
      '$schema': 'https://schema.management.azure.com/providers/Microsoft.Logic/schemas/2016-06-01/workflowdefinition.json#'
      contentVersion: '1.0.0.0'
      parameters: {
        GRAPH_API_BASE: {
          defaultValue: 'https://graph.microsoft.com'
          type: 'String'
        }
        HOWLER_API_URL: {
          defaultValue: APIURL
          type: 'String'
        }
        '$connections': {
          defaultValue: {}
          type: 'Object'
        }
      }
      triggers: {
        Recurrence: {
          recurrence: {
            interval: recurrenceInterval
            frequency: 'Minute'
          }
          evaluatedRecurrence: {
            interval: recurrenceInterval
            frequency: 'Minute'
          }
          type: 'Recurrence'
          description: 'Every ${recurrenceInterval} minutes'
        }
      }
      actions: {
        Get_current_time: {
          runAfter: {}
          type: 'Expression'
          kind: 'CurrentTime'
          inputs: {}
        }
        Get_cursor: {
          runAfter: {}
          type: 'ApiConnection'
          inputs: {
            host: {
              connection: {
                name: '@parameters(\'$connections\')[\'azuretables\'][\'connectionId\']'
              }
            }
            method: 'get'
            path: '/v2/storageAccounts/@{encodeURIComponent(encodeURIComponent(\'trunks\'))}/tables/@{encodeURIComponent(\'${tableName}\')}/entities'
            queries: {
              '$select': 'PointInTime'
            }
          }
        }
        Get_all_incident_updates: {
          runAfter: {
            Get_cursor: [
              'Succeeded'
            ]
            Get_current_time: [
              'Succeeded'
            ]
            Get_secret: [
              'Succeeded'
            ]
          }
          type: 'Http'
          inputs: {
            uri: '@{parameters(\'GRAPH_API_BASE\')}/v1.0/security/incidents'
            method: 'GET'
            queries: {
              '$filter': 'lastUpdateDateTime ge @{coalesce(body(\'Get_cursor\')[\'value\'][0][\'PointInTime\'],addHours(utcNow(),-1))}'
              '$expand': 'alerts'
            }
            authentication: {
              type: 'ManagedServiceIdentity'
              audience: '@{parameters(\'GRAPH_API_BASE\')}'
            }
          }
          description: ''
          runtimeConfiguration: {
            paginationPolicy: {
              minimumItemCount: 10000
            }
            contentTransfer: {
              transferMode: 'Chunked'
            }
          }
        }
        Get_secret: {
          runAfter: {}
          type: 'ApiConnection'
          inputs: {
            host: {
              connection: {
                name: '@parameters(\'$connections\')[\'keyvault\'][\'connectionId\']'
              }
            }
            method: 'get'
            path: '/secrets/@{encodeURIComponent(\'APIKEY\')}/value'
          }
          runtimeConfiguration: {
            secureData: {
              properties: [
                'inputs'
                'outputs'
              ]
            }
          }
        }
        Data_Ingest: {
          actions: {
            For_each_incident: {
              foreach: '@body(\'Get_all_incident_updates\')[\'value\']'
              actions: {
                Push_incident_to_Howler: {
                  runAfter: {
                    Incident_Details: [
                      'Succeeded'
                    ]
                  }
                  type: 'Http'
                  inputs: {
                    uri: '@parameters(\'HOWLER_API_URL\')'
                    method: 'POST'
                    headers: {
                      'Content-Type': 'application/json'
                      Authorization: 'basic @{body(\'Get_secret\')?[\'value\']}'
                    }
                    body: '@items(\'For_each_incident\')'
                  }
                  description: 'No chunking'
                }
                Incident_Details: {
                  type: 'Compose'
                  inputs: '@items(\'For_each_incident\')'
                }
              }
              type: 'Foreach'
            }
          }
          runAfter: {
            Get_all_incident_updates: [
              'Succeeded'
            ]
          }
          type: 'Scope'
        }
        Update_cursor_with_execution_time: {
          runAfter: {
            Data_Ingest: [
              'Succeeded'
            ]
          }
          type: 'ApiConnection'
          inputs: {
            host: {
              connection: {
                name: '@parameters(\'$connections\')[\'azuretables\'][\'connectionId\']'
              }
            }
            method: 'put'
            body: {
              PointInTime: '@{body(\'Get_current_time\')}'
            }
            path: '/v2/storageAccounts/@{encodeURIComponent(encodeURIComponent(\'trunks\'))}/tables/@{encodeURIComponent(\'${tableName}\')}/entities(PartitionKey=\'@{encodeURIComponent(\'Cursor\')}\',RowKey=\'@{encodeURIComponent(\'Recurrence\')}\')'
          }
        }
        In_case_of_failure: {
          runAfter: {
            Data_Ingest: [
              'Failed'
              'TimedOut'
            ]
          }
          type: 'Compose'
          inputs: 'Do something'
        }
      }
      outputs: {}
    }
    parameters: {
      '$connections': {
        value: {
          azuretables: {
            id: '/subscriptions/${subscription().subscriptionId}/providers/Microsoft.Web/locations/${resourceGroup().location}/managedApis/azuretables'
            connectionId: tableWebConnection.id
            connectionName: 'azuretables'
            connectionProperties: {
              authentication: {
                type: 'ManagedServiceIdentity'
              }
            }
          }
          keyvault: {
            id: '/subscriptions/${subscription().subscriptionId}/providers/Microsoft.Web/locations/${resourceGroup().location}/managedApis/keyvault'
            connectionId: keyVaultWebConnection.id
            connectionName: 'keyvault'
            connectionProperties: {
              authentication: {
                type: 'ManagedServiceIdentity'
              }
            }
          }
        }
      }
    }
  }
}

resource tableContributorRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(storageAccount.id, 'Storage Table Data Contributor')
  scope: storageAccount
  properties: {
    principalId: logicApp.identity.principalId
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '0a9a7e1f-b9d0-4cc4-a60d-0319b160aaa3')
    principalType: 'ServicePrincipal'
  }
}

resource keyVaultReaderRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(keyVault.id, 'Key Vault Secrets User')
  scope: keyVault
  properties: {
    principalId: logicApp.identity.principalId
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '4633458b-17de-408a-b874-0445c86b69e6')
    principalType: 'ServicePrincipal'
  }
}
