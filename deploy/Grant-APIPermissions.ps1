param(
    [Parameter(Mandatory=$true)]
    [string] $TenantId,
    [Parameter(Mandatory=$true)]
    [string] $IdentityName, #Name of logic app or managed identity
    [Parameter(Mandatory=$false)]
    [bool] $DeviceCodeFlow = $false
)

#Requires -Modules Microsoft.Graph.Applications

# Required Permissions
#  - Entra ID Global Administrator or an Entra ID Privileged Role Administrator to execute the Set-APIPermissions function

# Check if the script is running in Azure Cloud Shell
if( $env:AZUREPS_HOST_ENVIRONMENT -like "cloud-shell*" ) {
    Write-Host "[+] The script is running in Azure Cloud Shell, Device Code flow will be used for authentication." 
    Write-Host "[+] It will look like the connection is coming from the Azure data center and not your client's location." -ForegroundColor Yellow
    $DeviceCodeFlow = $true
}

# Connect to the Microsoft Graph API and Azure Management API
Write-Host "[+] Connect to the Entra ID tenant: $TenantId"
if ( $DeviceCodeFlow -eq $true ) {
    Connect-MgGraph -TenantId $TenantId -Scopes AppRoleAssignment.ReadWrite.All, Application.Read.All -NoWelcome -ErrorAction Stop
} else {
    Connect-MgGraph -TenantId $TenantId -Scopes AppRoleAssignment.ReadWrite.All, Application.Read.All -NoWelcome -ErrorAction Stop | Out-Null
}
function Set-APIPermissions ($MSIName, $AppId, $PermissionName) {
    Write-Host "[+] Setting permission $PermissionName on $MSIName"
    $MSI = Get-AppIds -AppName $MSIName
    if ( $MSI.count -gt 1 )
    {
        Write-Host "[-] Found multiple principals with the same name." -ForegroundColor Red
        return 
    } elseif ( $MSI.count -eq 0 ) {
        Write-Host "[-] Principal not found." -ForegroundColor Red
        return 
    }
    Start-Sleep -Seconds 2 # Wait in case the MSI identity creation take some time
    $GraphServicePrincipal = Get-MgServicePrincipal -Filter "appId eq '$AppId'"
    $AppRole = $GraphServicePrincipal.AppRoles | Where-Object {$_.Value -eq $PermissionName -and $_.AllowedMemberTypes -contains "Application"}
    try
    {
        New-MgServicePrincipalAppRoleAssignment -ServicePrincipalId $MSI.Id -PrincipalId $MSI.Id -ResourceId $GraphServicePrincipal.Id -AppRoleId $AppRole.Id -ErrorAction Stop | Out-Null
    }
    catch
    {
        if ( $_.Exception.Message -eq "Permission being assigned already exists on the object" )
        {
            Write-Host "[-] $($_.Exception.Message)"
        } else {
            Write-Host "[-] $($_.Exception.Message)" -ForegroundColor Red
        }
        return
    }
    Write-Host "[+] Permission granted" -ForegroundColor Green
}

function Get-AppIds ($AppName) {
    Get-MgServicePrincipal -Filter "displayName eq '$AppName'"
}

Set-APIPermissions -MSIName $IdentityName -AppId "00000003-0000-0000-c000-000000000000" -PermissionName "SecurityAlert.Read.All"
Set-APIPermissions -MSIName $IdentityName -AppId "00000003-0000-0000-c000-000000000000" -PermissionName "SecurityIncident.Read.All"

Write-Host "[+] End of the script. Please review the output and check for potential failures."