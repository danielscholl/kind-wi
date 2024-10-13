targetScope = 'resourceGroup'
metadata name = 'kind-WI.'
metadata description = 'This instance deploys a local kind cluster with workload identity enabled.'


@description('Specify the Azure region to place the application definition.')
param location string = resourceGroup().location


@description('Internal Configuration Object')
var configuration = {
  name: 'main'
  displayName: 'Main Resources'
}

@description('Unique ID for the resource group')
var rg_unique_id = '${replace(configuration.name, '-', '')}${uniqueString(resourceGroup().id, configuration.name)}'


//*****************************************************************//
//  Identity Resources                                             //
//*****************************************************************//
module identity 'br/public:avm/res/managed-identity/user-assigned-identity:0.4.0' = {
  name: '${configuration.name}-user-managed-identity'
  params: {
    // Required parameters
    name: rg_unique_id
    location: location
    // Assign Tags
    tags: {
      layer: configuration.displayName
      id: rg_unique_id
    }
  }
}



//*****************************************************************//
//  Vault Resources                                           //
//*****************************************************************//

@description('The list of secrets to persist to the Key Vault')
var vaultSecrets = [ 
  {
    secretName: 'tenant-id'
    secretValue: subscription().tenantId
  }
  {
    secretName: 'subscription-id'
    secretValue: subscription().subscriptionId
  }
]

module keyvault 'br/public:avm/res/key-vault/vault:0.9.0' = {
  name: '${configuration.name}-keyvault'
  params: {
    name: length(rg_unique_id) > 24 ? substring(rg_unique_id, 0, 24) : rg_unique_id
    location: location
    
    // Assign Tags
    tags: {
      layer: configuration.displayName
      id: rg_unique_id
    }

    enablePurgeProtection: false
    publicNetworkAccess: 'Disabled'
    
    // Configure RBAC
    enableRbacAuthorization: true
    roleAssignments: [{
      roleDefinitionIdOrName: 'Key Vault Secrets User'
      principalId: identity.outputs.principalId
      principalType: 'ServicePrincipal'
    }]

    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Allow'
    }

    // Configure Secrets
    secrets: [
      for secret in vaultSecrets: {
        name: secret.secretName
        value: secret.secretValue
      }
    ]
  }
}



//*****************************************************************//
//  Configuration Resources                                        //
//*****************************************************************//

module configurationStore 'br/public:avm/res/app-configuration/configuration-store:0.5.0' = {
  name: '${configuration.name}-appconfig'
  params: {
    // Required parameters
    name: length(rg_unique_id) > 24 ? substring(rg_unique_id, 0, 24) : rg_unique_id    
    location: location

    // Assign Tags
    tags: {
      layer: configuration.displayName
      id: rg_unique_id
    }

    enablePurgeProtection: false
  }
}

output IDENTITY_PRINCIPAL_ID string = identity.outputs.principalId
