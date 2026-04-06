// =============================================================
// Lab 12 — SQL Database + DB Subnet NSG
// Completes the three-tier architecture:
//   Tier 1 → App subnet  (Windows VMs + ILB)
//   Tier 2 → DB subnet   (SQL Server + NSG restricting to App only)
//   Tier 3 → Bastion     (secure admin access)
// New resources: nsg-db-prod-cus-01, sql-prod-cus-01, sqldb-prod-cus-01
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

// Lab 12 new parameters
param dbNsg object                   // NSG rules for DB subnet
param sqlAdminLogin string           // SQL admin username (plain text)
@secure()
param sqlAdminPassword string        // SQL admin password (from Key Vault)

// Naming variables
var natPipName  = 'pip-nat-prod-cus-01'
var dbSubnetName = 'snet-prod-cus-db-01'

// ── Security ─────────────────────────────────────────────────

module sharednsg 'modules/security/nsg.bicep' = {
  name: 'nsg-prod-cus-shared-01'
  params: {
    location: location
    name: nsg.name
    rules: nsg.rules
  }
}

module bastionNsgModule 'modules/security/nsg.bicep' = {
  name: 'nsg-bastion-prod'
  params: {
    location: location
    name: bastionNsg.name
    rules: bastionNsg.rules
  }
}

// Lab 12 — DB subnet NSG
// Reuses the same generic nsg.bicep module — DB-specific rules
// are passed from dev.parameters.json exactly like the existing NSGs.
// Rules: allow App subnet → port 1433, deny everything else.
module dbNsgModule 'modules/security/nsg.bicep' = {
  name: 'nsg-db-prod-cus-01'
  params: {
    location: location
    name: dbNsg.name
    rules: dbNsg.rules
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
  }
}

module natGw 'modules/network/natGateway.bicep' = {
  name: 'nat-gateway-prod'
  params: {
    location: location
    environmentName: 'prod'
    publicIpId: pipNat.outputs.PublicIPid
  }
  dependsOn: [pipNat]
}

// ── Networking ───────────────────────────────────────────────

// Lab 12 — vnet.bicep now adds Microsoft.Sql service endpoint
// to the DB subnet so the SQL VNet rule can be enforced.
// The DB NSG ID is passed as nsgId for the DB subnet via the
// existing nsgId param — the shared NSG covers App + Bastion,
// and the DB NSG is handled by overriding at the subnet level.
//
// NOTE: The existing vnet.bicep applies nsgId to all non-Bastion
// subnets. To apply the DB NSG to only the DB subnet we pass
// dbNsgModule.outputs.nsgId as a separate param and use the
// existing conditional pattern in vnet.bicep (extended below).
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
    dbNsgId: dbNsgModule.outputs.nsgId           // Lab 12 addition
  }
  dependsOn: [natGw]
}

module storage 'modules/storage/storageAccount.bicep' = {
  name: 'stprodcusinfra01'
  params: {
    name: storageAccountName
    location: location
  }
}

// ── Compute ──────────────────────────────────────────────────

module ilb 'modules/network/internalLB.bicep' = {
  name: 'ilb-prod'
  params: {
    location: location
    lbName: lbName
    subnetId: devnet.outputs.subnetIds[0].id
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
  }
}

module bastionhost 'modules/security/bastion.bicep' = {
  name: 'bastion-prod'
  params: {
    name: bastion.name
    location: location
    subnetId: devnet.outputs.subnetIds[2].id
    publicIPId: basPip.outputs.PublicIPid
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
  }
}

// ── VNet Peering ─────────────────────────────────────────────

module vnetpeering 'modules/network/vnetpeering.bicep' = {
  name: 'vnet-peering-prod-staging'
  params: {
    localVnetName: vnet.name
    remoteVnetName: testvnet.name
    localVnetId: devnet.outputs.vnetId
    remoteVnetId: testnet.outputs.vnetId
  }
}

// Lab 12 — SQL Database
// Deployed after devnet so the DB subnet service endpoint exists
// before the VNet rule tries to reference it.
module sqlDb 'modules/database/sqlDatabase.bicep' = {
  name: 'sql-database-prod'
  params: {
    location        : location
    environmentName : 'prod'
    sqlAdminLogin   : sqlAdminLogin
    sqlAdminPassword: sqlAdminPassword
    vnetName        : vnet.name
    appSubnetName   : 'snet-prod-cus-app-01'  
  }
  dependsOn: [devnet]
}

// ── Outputs ──────────────────────────────────────────────────

output natGatewayName  string = natGw.outputs.natGatewayName
output sqlServerName   string = sqlDb.outputs.sqlServerName
output sqlServerFqdn   string = sqlDb.outputs.sqlServerFqdn
output sqlDatabaseName string = sqlDb.outputs.sqlDatabaseName
