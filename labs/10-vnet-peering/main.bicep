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

module devnet 'modules/network/vnet.bicep' = {
  name: 'prod-network'
  params: {
    name: vnet.name
    location: location
    addressPrefixes: vnet.addressPrefixes
    subnets: vnet.subnets
    nsgId: sharednsg.outputs.nsgId
    bastionNsgId: bastionNsgModule.outputs.nsgId
  }
}

module storage 'modules/storage/storageAccount.bicep' = { 
    name: 'stprodcusinfra01'
    params: { 
      name:storageAccountName
      location: location
    }
}
module winWeb 'modules/compute/windowsVm.bicep'= { 
   name:'win-web-dev'
   params: { 
      location:location
      baseName:winWebConfig.baseName
      vmSize:winWebConfig.vmSize
      count:winWebConfig.count
      adminUserName:winWebConfig.adminUserName
      subnetId: devnet.outputs.subnetIds[0].id
      adminPassword:winWebAdminPassword 
      scriptUri:winWebConfig.scriptUri
      scriptCommand: 'powershell -ExecutionPolicy Bypass -File .\\setup-iis.ps1'
      lbBackendPoolId:ilb.outputs.backendPoolId
   }

}

module ilb 'modules/network/internalLB.bicep' = { 
   name: 'ilb-prod'
   params: { 
      location:location
      lbName:lbName
      subnetId:devnet.outputs.subnetIds[0].id
   }
}

module basPip 'modules/network/publicIp.bicep' =  { 
   name: 'pip-bastion-prod'
   params: { 
      name:bastion.pipName
      location:location
      sku:'Standard'
      allocation:'Static'
   }
}

module bastionhost 'modules/security/bastion.bicep'= { 
   name: 'bastion-prod'
   params:{ 
      name:bastion.name
      location:location
      subnetId:devnet.outputs.subnetIds[2].id
      publicIPId:basPip.outputs.PublicIPid
   }
}

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

module vnetpeering 'modules/network/vnetpeering.bicep'= { 
   name: 'vnet-peering-prod-staging'
   params:{ 
      localVnetName:vnet.name
      remoteVnetName:testvnet.name
      localVnetId:devnet.outputs.vnetId
      remoteVnetId:testnet.outputs.vnetId
   }
}
