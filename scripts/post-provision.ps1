<#
.SYNOPSIS
  Post Provision Script
.DESCRIPTION
  This script performs post-provisioning tasks, waiting for software to install, and then updating the Application.
.PARAMETER AZURE_SUBSCRIPTION_ID
  Specify a particular AZURE_SUBSCRIPTION_ID to use.
.PARAMETER AZURE_RESOURCE_GROUP
  Specify a particular Resource Group to use.
.PARAMETER Help
  Print help message and exit.
.EXAMPLE
  .\post-provision.ps1 -AZURE_SUBSCRIPTION_ID <AZURE_SUBSCRIPTION_ID>
#>

#Requires -Version 7.4

param (
    [ValidateNotNullOrEmpty()]
    [string]$AZURE_SUBSCRIPTION_ID = $env:AZURE_SUBSCRIPTION_ID,
    
    [ValidateNotNullOrEmpty()]
    [string]$AZURE_RESOURCE_GROUP = $env:AZURE_RESOURCE_GROUP,

    [ValidateNotNullOrEmpty()]
    [string]$AZURE_LOCATION = $env:AZURE_LOCATIONß,
    
    [ValidateNotNullOrEmpty()]
    [string]$CLUSTER_NAME = "kind-wi",

    [switch]$Help
)

function Show-Help {
    Write-Host "Usage: .\hook-postprovision.ps1 [-AZURE_SUBSCRIPTION_ID SUBSCRIPTION_ID]"
    Write-Host "Options:"
    Write-Host " -AZURE_SUBSCRIPTION_ID : Specify a particular Subscription ID to use."
    Write-Host " -AZURE_RESOURCE_GROUP : Specify a particular AZURE_RESOURCE_GROUP to use."
    Write-Host " -AZURE_LOCATION : Specify a particular AZURE_LOCATION to use."
    Write-Host " -Help : Print this help message and exit"
}

function Set-Login {
    try {
        # Check if the user is logged in
        $user = az ad signed-in-user show --query userPrincipalName -o tsv
        $accountInfo = az account show -o json 2>$null | ConvertFrom-Json
        if ($user) {
            Write-Host "`n=================================================================="
            Write-Host "Logged in as: $user"
            Write-Host "=================================================================="
        } else {
            Write-Host "`n=================================================================="
            Write-Host "Azure CLI Login Required"
            Write-Host "=================================================================="
            az login --scope https://graph.microsoft.com//.default
            # Recheck if the user is logged in
            $accountInfo = az account show -o json | ConvertFrom-Json
            if ($accountInfo) {
                Write-Host "`n=================================================================="
                Write-Host "Logged in as: $($accountInfo.user.name)"
                Write-Host "=================================================================="
            } else {
                Write-Host "  Failed to log in. Exiting."
                exit 1
            }
        }
        # Ensure the subscription ID is set
        Write-Host "`n=================================================================="
        Write-Host "Azure Subscription: $($AZURE_SUBSCRIPTION_ID)"
        Write-Host "=================================================================="
        az account set --subscription $AZURE_SUBSCRIPTION_ID
    } catch {
        Write-Host "Error during login check: $_" -ForegroundColor Red
        exit 1
    }
}

function Register-AksArc {

    try {
        Write-Host "`n=================================================================="
        Write-Host "Registering Kind Cluster as Azure Arc-enabled Kubernetes"
        Write-Host "=================================================================="

        # Set the kubeconfig for the local Kind cluster
        $env:KUBECONFIG = "./cluster/kubeconfig/config"


        # Check if the cluster is already connected
        $existingCluster = az connectedk8s show --name $CLUSTER_NAME --resource-group $AZURE_RESOURCE_GROUP 2>$null
        if ($existingCluster) {
            Write-Host "Cluster $CLUSTER_NAME is already registered as AKS Arc-enabled" -ForegroundColor Green
            Start-Sleep -Seconds 2
            return
        }
        Write-Host $existingCluster

        # Connect the local Kind cluster to Azure Arc
        Write-Host "Connecting cluster $CLUSTER_NAME to Azure Arc..."
        $result = az connectedk8s connect --name $CLUSTER_NAME --resource-group $AZURE_RESOURCE_GROUP --location $AZURE_LOCATION
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "Successfully connected cluster to Azure Arc" -ForegroundColor Green
        } else {
            Write-Host "Failed to connect cluster to Azure Arc. Error: $result" -ForegroundColor Red
        }

    } catch {
        Write-Host "Error registering local Kind cluster as AKS Arc-enabled: $_" -ForegroundColor Red
    }
}

function Create-ServiceAccount {
    try {
        Write-Host "`n=================================================================="
        Write-Host "Checking and Creating ServiceAccount in Kind Cluster"
        Write-Host "=================================================================="

        $SERVICE_ACCOUNT_NAME = "workload-identity-sa"
        $SERVICE_ACCOUNT_NAMESPACE = "default"
        $USER_ASSIGNED_IDENTITY_CLIENT_ID = $env:USER_ASSIGNED_IDENTITY_CLIENT_ID

        if (-not $USER_ASSIGNED_IDENTITY_CLIENT_ID) {
            Write-Host "Error: USER_ASSIGNED_IDENTITY_CLIENT_ID environment variable is not set." -ForegroundColor Red
            return
        }

        # Check if the ServiceAccount already exists
        $existingServiceAccount = kubectl get serviceaccount $SERVICE_ACCOUNT_NAME -n $SERVICE_ACCOUNT_NAMESPACE -o json 2>$null

        if ($existingServiceAccount) {
            Write-Host "ServiceAccount $SERVICE_ACCOUNT_NAME already exists in namespace $SERVICE_ACCOUNT_NAMESPACE" -ForegroundColor Yellow
        } else {
            $serviceAccountYaml = @"
apiVersion: v1
kind: ServiceAccount
metadata:
  annotations:
    azure.workload.identity/client-id: $USER_ASSIGNED_IDENTITY_CLIENT_ID
  name: $SERVICE_ACCOUNT_NAME
  namespace: $SERVICE_ACCOUNT_NAMESPACE
"@

            $serviceAccountYaml | kubectl apply -f -

            if ($LASTEXITCODE -eq 0) {
                Write-Host "ServiceAccount created successfully" -ForegroundColor Green
            } else {
                Write-Host "Failed to create ServiceAccount" -ForegroundColor Red
                return
            }
        }

        # Create ClusterRoleBinding
        Write-Host "`nCreating ClusterRoleBinding..."
        $clusterRoleBindingResult = kubectl create clusterrolebinding workload-identity-binding --clusterrole cluster-admin --serviceaccount ${SERVICE_ACCOUNT_NAMESPACE}:${SERVICE_ACCOUNT_NAME} 2>&1

        if ($LASTEXITCODE -eq 0) {
            Write-Host "ClusterRoleBinding created successfully" -ForegroundColor Green
        } else {
            if ($clusterRoleBindingResult -like "*already exists*") {
                Write-Host "ClusterRoleBinding already exists" -ForegroundColor Yellow
            } else {
                Write-Host "Failed to create ClusterRoleBinding. Error: $clusterRoleBindingResult" -ForegroundColor Red
                return
            }
        }

        # Create Secret
        Write-Host "`nCreating Secret..."
        $secretYaml = @"
apiVersion: v1
kind: Secret
metadata:
  name: ${SERVICE_ACCOUNT_NAME}-secret
  annotations:
    kubernetes.io/service-account.name: $SERVICE_ACCOUNT_NAME
type: kubernetes.io/service-account-token
"@

        $secretResult = $secretYaml | kubectl apply -f - 2>&1

        if ($LASTEXITCODE -eq 0) {
            Write-Host "Secret created successfully" -ForegroundColor Green
        } else {
            if ($secretResult -like "*already exists*") {
                Write-Host "Secret already exists" -ForegroundColor Yellow
            } else {
                Write-Host "Failed to create Secret. Error: $secretResult" -ForegroundColor Red
            }
        }

        # Get the token and set it as an environment variable
        Write-Host "`nRetrieving and setting the token..."
        $token = kubectl get secret ${SERVICE_ACCOUNT_NAME}-secret -o jsonpath='{$.data.token}' | ForEach-Object { 
            [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($_)) 
        }

        if ($token) {
            azd env set TOKEN $token
            if ($LASTEXITCODE -eq 0) {
                Write-Host "Token successfully set as an environment variable" -ForegroundColor Green
            } else {
                Write-Host "Failed to set token as an environment variable" -ForegroundColor Red
            }
        } else {
            Write-Host "Failed to retrieve token from secret" -ForegroundColor Red
        }

    } catch {
        Write-Host "Error in Create-ServiceAccount: $_" -ForegroundColor Red
    }
}

# Main script execution
if ($Help) {
    Show-Help
    exit 0
}

if (-not $AZURE_SUBSCRIPTION_ID) {
    Write-Host "Error: You must provide a AZURE_SUBSCRIPTION_ID"
    Show-Help
    exit 1
}

if (-not $AZURE_RESOURCE_GROUP) {
    Write-Host "Error: You must provide a AZURE_RESOURCE_GROUP"
    Show-Help
    exit 1
}

Set-Login

# Execute Docker Compose commands
Write-Host "`n=================================================================="
Write-Host "Starting Kind Cluster "
Write-Host "=================================================================="

# Check if Docker Compose services are already running
$servicesRunning = docker compose ps --services --filter "status=running" | Out-String

if ($servicesRunning.Trim()) {
    Write-Host "Docker Compose services are already running."
} else {
    Write-Host "Starting Docker Compose services..."
    docker compose up -d --build
}

# Wait for the config file to exist
$configPath = "./cluster/kubeconfig/config"
$maxWaitTime = 300 # Maximum wait time in seconds (5 minutes)
$startTime = Get-Date

Write-Host "`n=================================================================="
Write-Host "Waiting for Cluster to come alive..."
Write-Host "=================================================================="

while (-not (Test-Path $configPath)) {
    if (((Get-Date) - $startTime).TotalSeconds -gt $maxWaitTime) {
        Write-Host "Timeout waiting for cluster. Exiting."
        exit 1
    }
    Start-Sleep -Seconds 5
}

Write-Host "`nCluster is ready. Proceeding with cluster info." 

$KUBECONFIG = $configPath
$clusterInfoOutput = kubectl --kubeconfig=$KUBECONFIG cluster-info 2>&1

if ($LASTEXITCODE -eq 0) {
    Write-Host "Cluster info retrieved successfully:" -ForegroundColor Green

    Register-AksArc
    Create-ServiceAccount
} else {
    Write-Host "Failed to retrieve cluster info. Skipping further operations." -ForegroundColor Red
    Write-Host "Error output: $clusterInfoOutput"
}
