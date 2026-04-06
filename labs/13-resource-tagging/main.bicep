// =============================================================
// Lab 13 — Resource Tagging
// Adds consistent tags to every resource in the infrastructure.
// Tags are defined once in dev.parameters.json and flow through
// main.bicep into every module — single source of truth.
//
// No new Azure resources are deployed in this lab.
// The only change is the addition of the tags parameter across
// all modules. This demonstrates that governance concerns
// (tagging, cost allocation) are managed separately from
// infrastructure deployment concerns.
//
// Tags applied to every resource:
//   Environment  = prod
//   Project      = azure-secure-multi-tier-infra
//   Owner        = Sharath Kumar
//   CostCenter   = lab
//   ManagedBy    = Bicep
// =============================================================

param location string
param vnet object
param storageAccountName string
param nsg object
param bastionNsg object
param winWebConfig object
@secure()
param winWebAdminPassword string
param bastion object
param lbName string
param linuxWebConfig object
@secure()
param linuxWebAdminPassword string
param testvnet object
param dbNsg object
param sqlAdminLogin string
@secure()
param sqlAdminPassword string

// Lab 13 — single tags object, defined once in dev.parameters.json
// Passed into every module so every resource gets identical tags.
// To update tags across all resources: change dev.parameters.json only.
@description('Tags applied to all resources in this deployment')
param tags object

// ── Naming variables (unchanged from Lab 12) ─────────────────

var natPipName = 'pip-nat-prod-cus-01'

// ── Security ─────────────────────────────────────────────────

module sharednsg 'modules/security/nsg.bicep' = {
  name: 'nsg-prod-cus-shared-01'
  params: {
    location: location
    name: nsg.name
    rules: nsg.rules
    tags: tags
  }
}

module bastionNsgModule 'modules/security/nsg.bicep' = {
  name: 'nsg-bastion-prod'
  params: {
    location: location
    name: bastionNsg.name
    rules: bastionNsg.rules
    tags: tags
  }
}

module dbNsgModule 'modules/security/nsg.bicep' = {
  name: 'nsg-db-prod-cus-01'
  params: {
    location: location
    name: dbNsg.name
    rules: dbNsg.rules
    tags: tags
  }
}

// ── NAT Gateway ───────────────────────────────────────────────

module pipNat 'modules/network/publicIp.bicep' = {
  name: 'pip-nat-prod'
  params: {
    name: natPipName
    location: location
    sku: 'Standard'
    allocation: 'Static'
    tags: tags
  }
}

module natGw 'modules/network/natGateway.bicep' = {
  name: 'nat-gateway-prod'
  params: {
    location: location
    environmentName: 'prod'
    publicIpId: pipNat.outputs.PublicIPid
    tags: tags
  }
  dependsOn: [pipNat]
}

// ── Networking ───────────────────────────────────────────────

module devnet 'modules/network/vnet.bicep' = {
  name: 'prod-network'
  params: {
    name: vnet.name
    location: location
    addressPrefixes: vnet.addressPrefixes
    subnets: vnet.subnets
    nsgId: sharednsg.outputs.nsgId
    bastionNsgId: bastionNsgModule.outputs.nsgId
    natGatewayId: natGw.outputs.natGatewayId
    dbNsgId: dbNsgModule.outputs.nsgId
    tags: tags
  }
  dependsOn: [natGw]
}

module storage 'modules/storage/storageAccount.bicep' = {
  name: 'stprodcusinfra01'
  params: {
    name: storageAccountName
    location: location
    tags: tags
  }
}

// ── Compute ──────────────────────────────────────────────────

module ilb 'modules/network/internalLB.bicep' = {
  name: 'ilb-prod'
  params: {
    location: location
    lbName: lbName
    subnetId: devnet.outputs.subnetIds[0].id
    tags: tags
  }
}

module winWeb 'modules/compute/windowsVm.bicep' = {
  name: 'win-web-dev'
  params: {
    location: location
    baseName: winWebConfig.baseName
    vmSize: winWebConfig.vmSize
    count: winWebConfig.count
    adminUserName: winWebConfig.adminUserName
    subnetId: devnet.outputs.subnetIds[0].id
    adminPassword: winWebAdminPassword
    scriptUri: winWebConfig.scriptUri
    scriptCommand: 'powershell -ExecutionPolicy Bypass -File .\\setup-iis.ps1'
    lbBackendPoolId: ilb.outputs.backendPoolId
    tags: tags
  }
}

// ── Bastion ──────────────────────────────────────────────────

module basPip 'modules/network/publicIp.bicep' = {
  name: 'pip-bastion-prod'
  params: {
    name: bastion.pipName
    location: location
    sku: 'Standard'
    allocation: 'Static'
    tags: tags
  }
}

module bastionhost 'modules/security/bastion.bicep' = {
  name: 'bastion-prod'
  params: {
    name: bastion.name
    location: location
    subnetId: devnet.outputs.subnetIds[2].id
    publicIPId: basPip.outputs.PublicIPid
    tags: tags
  }
}

// ── Staging VNet + Linux VM ───────────────────────────────────

module testnet './modules/network/vnet.bicep' = {
  name: 'staging-network'
  params: {
    name: testvnet.name
    location: location
    addressPrefixes: testvnet.addressPrefixes
    subnets: testvnet.subnets
    nsgId: sharednsg.outputs.nsgId
    // natGatewayId and dbNsgId not passed — staging VNet does not need them
    tags: tags
  }
}

module linWeb './modules/compute/linuxVm.bicep' = {
  name: 'mod-linux-app-prod'
  params: {
    location: location
    baseName: linuxWebConfig.baseName
    vmSize: linuxWebConfig.vmSize
    subnetId: testnet.outputs.subnetIds[0].id
    count: linuxWebConfig.count
    adminUsername: linuxWebConfig.adminUsername
    adminPassword: linuxWebAdminPassword
    tags: tags
  }
}

// ── VNet Peering ──────────────────────────────────────────────
// Note: VNet peering child resources (virtualNetworkPeerings)
// do not support tags in Azure — omitted intentionally.

module vnetpeering 'modules/network/vnetpeering.bicep' = {
  name: 'vnet-peering-prod-staging'
  params: {
    localVnetName: vnet.name
    remoteVnetName: testvnet.name
    localVnetId: devnet.outputs.vnetId
    remoteVnetId: testnet.outputs.vnetId
  }
}

// ── SQL Database ─────────────────────────────────────────────

module sqlDb 'modules/database/sqlDatabase.bicep' = {
  name: 'sql-database-prod'
  params: {
    location:        location
    environmentName: 'prod'
    sqlAdminLogin:   sqlAdminLogin
    sqlAdminPassword: sqlAdminPassword
    vnetName:        vnet.name
    appSubnetName:   'snet-prod-cus-app-01'
    tags:            tags
  }
  dependsOn: [devnet]
}

// ── Outputs ──────────────────────────────────────────────────

output natGatewayName  string = natGw.outputs.natGatewayName
output sqlServerName   string = sqlDb.outputs.sqlServerName
output sqlServerFqdn   string = sqlDb.outputs.sqlServerFqdn
output sqlDatabaseName string = sqlDb.outputs.sqlDatabaseName
