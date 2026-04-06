param location string
param vnet object
param storageAccountName string
param nsg object

module devnet 'modules/network/vnet.bicep' = { 
   name: 'prod-network'
   params: { 
    name:vnet.name
    location: location
    addressPrefixes:vnet.addressPrefixes
    subnets:vnet.subnets
   }  
}

module storage 'modules/storage/storageAccount.bicep' = { 
    name: 'stprodcusinfra01'
    params: { 
      name:storageAccountName
      location: location
    }
}


module sharednsg 'modules/security/nsg.bicep' = { 
   name: 'nsg-prod-cus-shared-01'
   params: { 
      location:location
      name:nsg.name
      rules:nsg.rules
   }
}
