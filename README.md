## Howler and Defender integration

This repository contains the resources to integrate the Defender platform (including Microsoft Sentinel) with the open-source platform Howler.

### Send Defender incidents to Howler

This synchronization is achieved through a Logic App that reads incidents created or modified in Defender and sends them to Howler.

By default, this sync runs every 5 minutes. To keep track of the last synchronization, a storage account table is used to store a cursor. This cursor can also be used to artificially set a starting point for synchronization.

The solution deploys the following resources:
- A consumption Logic App which runs every 5 minutes using its system managed identity
- A Storage Account to store the cursor in a table
- A Keyvault to store the secret for Howler ingestion API

It also grants the necessary permissions for the system managed identity to read and modify the table as well as read the secret. 

[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https://raw.githubusercontent.com/piaudonn/DefenderForHowler/refs/heads/main/FromDefenderToHowler.json)

A Bicep file is also available for manual deployment: [💪 Deploy the solution](https://raw.githubusercontent.com/piaudonn/DefenderForHowler/refs/heads/main/deploy/FromDefenderToHowler.bicep)


### Send Howler hits to Defender (Sentinel ingestion)

It is possible to configure Howler to send hits to Defender through custom log ingestion in the Log Analytics workspace used by Sentinel. To make it possible, a Data Collection Rule is create in Azure Monitor that maps to a custom table in Log Analytics. Then, a near-realtime analytics rule in Sentinel is configure to create an incident as soon as data arrives in this table.

The solution will deploy a Data Collection Rule, a Log Analytic custom table and an Analytic Rule in Sentinel. You will need to provide the workspace used by Sentinel as well as service principal that you have configured on the Howler side of this integration.

