// =============================================================
// Lab 11 — NAT Gateway
// Fixes the outbound connectivity loss introduced in Lab 08
// when VMs were placed behind the Standard Internal LB.
// New resources: pip-nat-prod-cus-01, ng-prod-cus-01
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

// NAT Gateway Public IP — name follows existing convention
// pip-bas-prod-cus-01 (Bastion) → pip-nat-prod-cus-01 (NAT GW)
var natPipName = 'pip-nat-prod-cus-01'

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

// ── NAT Gateway (new in Lab 11) ───────────────────────────────

// Step 1: Dedicated Public IP for NAT Gateway
// Must be Standard SKU + Static — same as Bastion PIP
// but a SEPARATE resource. Never share PIPs between resources.
module pipNat 'modules/network/publicIp.bicep' = {
  name: 'pip-nat-prod'
  params: {
    name: natPipName
    location: location
    sku: 'Standard'
    allocation: 'Static'
  }
}

// Step 2: NAT Gateway — must deploy before the VNet
// so its ID can be passed to the App subnet association
module natGw 'modules/network/natGateway.bicep' = {
  name: 'nat-gateway-prod'
  params: {
    location: location
    environmentName: 'prod'
    publicIpId: pipNat.outputs.PublicIPid
  }
  dependsOn: [
    pipNat
  ]
}

// ── Networking ───────────────────────────────────────────────

// Step 3: VNet — now receives natGatewayId
// The updated vnet.bicep applies this to the App subnet only
module devnet 'modules/network/vnet.bicep' = {
  name: 'prod-network'
  params: {
    name: vnet.name
    location: location
    addressPrefixes: vnet.addressPrefixes
    subnets: vnet.subnets
    nsgId: sharednsg.outputs.nsgId
    bastionNsgId: bastionNsgModule.outputs.nsgId
    natGatewayId: natGw.outputs.natGatewayId  // Lab 11 addition
  }
  dependsOn: [
    natGw  // NAT Gateway must exist before subnet references its ID
  ]
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
    // natGatewayId not passed — staging VNet does not need NAT GW
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

// ── Outputs ──────────────────────────────────────────────────

output natGatewayName string = natGw.outputs.natGatewayName
output natPipName      string = natPipName
