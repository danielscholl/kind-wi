<#
.SYNOPSIS
  Pre Provision Script
.DESCRIPTION
  This script performs pre-provisioning tasks, ensuring an AD application is properly created.
.PARAMETER SubscriptionId
  Specify a particular SubscriptionId to use. Defaults to the value of the AZURE_SUBSCRIPTION_ID environment variable if set, or null if not.
.PARAMETER ApplicationId
  Optionally specify an ApplicationId. Defaults to the value of the AZURE_CLIENT_ID environment variable if set, otherwise creates one.
.PARAMETER AzureEnvName
  Optionally specify an Azure environment name. Defaults to the value of the AZURE_ENV_NAME environment variable if set, or "dev" if not.
.PARAMETER RequiredCliVersion
  Optionally specify the required Azure CLI version. Defaults to "2.60".
.EXAMPLE
  .\pre-provision.ps1 -SubscriptionId <SubscriptionId> -AzureEnvName <AzureEnvName> -RequiredCliVersion "2.60"
#>

#Requires -Version 7.4

param (
    [ValidateNotNullOrEmpty()]
    [string]$SubscriptionId = $env:AZURE_SUBSCRIPTION_ID,
    
    [ValidateNotNullOrEmpty()]
    [string]$ApplicationId = $env:AZURE_CLIENT_ID,
    
    [string]$AzureEnvName = $env:AZURE_ENV_NAME ? $env:AZURE_ENV_NAME : "dev",
    
    [version]$RequiredCliVersion = [version]"2.60",
    
    [switch]$Help
)

function Show-Help {
    Write-Host "Usage: .\pre-provision.ps1 [-RequiredCliVersion REQUIRED_CLI_VERSION] [-Help]"
    Write-Host "Options:"
    Write-Host " -RequiredCliVersion : Optionally specify the required Azure CLI version. Defaults to '2.60'."
    Write-Host " -Help : Print this help message and exit"
}

function Set-AzureCliVersion {
    try {
        $azVersionOutput = az version --output json | ConvertFrom-Json
        $azVersion = $azVersionOutput.'azure-cli'
        $azVersionComparable = [version]$azVersion

        Write-Host "`n=================================================================="
        Write-Host "Azure CLI Version: $azVersionComparable"
        Write-Host "=================================================================="

        if ($azVersionComparable -lt $RequiredCliVersion) {
            Write-Host "This script requires Azure CLI version $RequiredCliVersion or higher. You have version $azVersionComparable."
            exit 1
        }
    } catch {
        Write-Host "Error checking Azure CLI version: $_"
        exit 1
    }
}

function Update-AksExtensions {
    try {
        $requiredExtensions = @("aks-preview", "connectedk8s", "k8s-configuration")

        Write-Host "`n=================================================================="
        Write-Host "Azure CLI Extensions"
        Write-Host "=================================================================="

        $azVersionOutput = az version --output json | ConvertFrom-Json

        foreach ($extension in $requiredExtensions) {
            Write-Host "Checking extension: $extension"
            if ($azVersionOutput.extensions.$extension) {
                Write-Host "  Found [$extension] extension. Updating..."
                az extension update --name $extension --allow-preview true --only-show-errors
            } else {
                Write-Host "  Not Found [$extension] extension. Installing..."
                az extension add --name $extension --allow-preview true --only-show-errors

                if ($?) {
                    Write-Host "  [$extension] extension successfully installed"
                } else {
                    Write-Host "  Failed to install [$extension] extension"
                    exit 1
                }
            }
        }
    } catch {
        Write-Host "Error updating Azure CLI extensions: $_"
        exit 1
    }
}

function Check-DockerInstallation {
}

if ($Help) {
    Show-Help
    exit 0
}

Set-AzureCliVersion
Update-AksExtensions
Check-DockerInstallation
