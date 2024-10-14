#Requires -Version 7.4

param (
    [ValidateNotNullOrEmpty()]
    [string]$AZURE_SUBSCRIPTION_ID = $env:AZURE_SUBSCRIPTION_ID,
    
    [ValidateNotNullOrEmpty()]
    [string]$AZURE_RESOURCE_GROUP = $env:AZURE_RESOURCE_GROUP,

    [ValidateNotNullOrEmpty()]
    [string]$AZURE_LOCATION = $env:AZURE_LOCATION,

    [switch]$Help
)

function Show-Help {
    Write-Host "Usage: .\post-down.ps1 [-Help]"
    Write-Host "Options:"
    Write-Host " -Help : Print this help message and exit"
}

if ($Help) {
    Show-Help
    exit 0
}

function Set-Login {
    try {
        # Check if already logged in
        $account = az account show 2>$null | ConvertFrom-Json
        if ($null -eq $account) {
            Write-Host "Logging in to Azure..."
            az login --use-device-code
        }

        # Set the subscription
        if ($AZURE_SUBSCRIPTION_ID) {
            az account set --subscription $AZURE_SUBSCRIPTION_ID
        }

        Write-Host "Current Azure account:"
        az account show
    } catch {
        Write-Host "Error logging in to Azure: $_"
        exit 1
    }
}


# Ensure Azure CLI is logged in and the correct subscription is set
Set-Login

Write-Host "`n=================================================================="
Write-Host "Removing Resource Group"
Write-Host "=================================================================="

az group delete --name $AZURE_RESOURCE_GROUP --location $AZURE_LOCATION --yes