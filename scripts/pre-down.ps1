#Requires -Version 7.4

param (
    [ValidateNotNullOrEmpty()]
    [string]$AZURE_SUBSCRIPTION_ID = $env:AZURE_SUBSCRIPTION_ID,
    
    [ValidateNotNullOrEmpty()]
    [string]$AZURE_RESOURCE_GROUP = $env:AZURE_RESOURCE_GROUP,

    [ValidateNotNullOrEmpty()]
    [string]$CLUSTER_NAME = "kind-wi",

    [switch]$Help
)

function Show-Help {
    Write-Host "Usage: .\pre-down.ps1 [-Help]"
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

function Remove-AksArc {
    try {
        Write-Host "`n=================================================================="
        Write-Host "Removing Arc-enabled Kubernetes Kind Cluster"
        Write-Host "=================================================================="

        # Check if the cluster exists in Azure
        $existingCluster = az connectedk8s show --name $CLUSTER_NAME --resource-group $AZURE_RESOURCE_GROUP 2>$null
        if ($existingCluster) {
            $result = az connectedk8s delete --name $CLUSTER_NAME --resource-group $AZURE_RESOURCE_GROUP --yes
            
            if ($LASTEXITCODE -eq 0) {
                Write-Host "Successfully deleted Arc-enabled Kubernetes Cluster" -ForegroundColor Green
            } else {
                Write-Host "Failed to delete Arc-enabled Kubernetes Cluster. Error: $result"
                Write-Host "Continuing with cleanup..."
            }
        } else {
            Write-Host "Arc-enabled Kubernetes Cluster $CLUSTER_NAME not found in Azure."
        }
    } catch {
        Write-Host "Error removing Arc-enabled Kubernetes cluster: $_"
    }
}

# Ensure Azure CLI is logged in and the correct subscription is set
Set-Login

# Remove the Arc-enabled Kubernetes cluster
Remove-AksArc

Write-Host "`n=================================================================="
Write-Host "Stopping and removing Docker containers"
Write-Host "=================================================================="

try {
    docker compose down
    if ($LASTEXITCODE -eq 0) {
        Write-Host "Docker containers stopped and removed successfully."
    } else {
        Write-Host "Error stopping Docker containers. Exit code: $LASTEXITCODE"
        exit 1
    }
} catch {
    Write-Host "Error during Docker compose down: $_"
    exit 1
}

Write-Host "`n=================================================================="
Write-Host "Removing generated files"
Write-Host "=================================================================="

# Remove sa.key and sa.pub from the keys folder
$keysPath = Join-Path $PSScriptRoot ".." "cluster" "keys"
Remove-Item -Path (Join-Path $keysPath "sa.key") -ErrorAction SilentlyContinue
Remove-Item -Path (Join-Path $keysPath "sa.pub") -ErrorAction SilentlyContinue

# Remove config from the kubeconfig folder
$kubeconfigPath = Join-Path $PSScriptRoot ".." "cluster" "kubeconfig"
Remove-Item -Path (Join-Path $kubeconfigPath "config") -ErrorAction SilentlyContinue

Write-Host "Generated files removed successfully."
