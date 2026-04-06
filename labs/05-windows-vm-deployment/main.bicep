param location string
param vnet object
param storageAccountName string
param nsg object
param winWebConfig object
@secure()
param winWebAdminPassword string

var nsgAttachments = [
{
      vnetName:vnet.name
      subnetName:vnet.subnets[0].name
      addressPrefix:vnet.subnets[0].prefix
}
{
   
      vnetName:vnet.name
      subnetName:vnet.subnets[1].name
      addressPrefix:vnet.subnets[1].prefix
}
]

module sharednsg 'modules/security/nsg.bicep' = { 
   name: 'nsg-prod-cus-shared-01'
   params: { 
      location:location
      name:nsg.name
      rules:nsg.rules
      attachments:nsgAttachments
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
   }
}

