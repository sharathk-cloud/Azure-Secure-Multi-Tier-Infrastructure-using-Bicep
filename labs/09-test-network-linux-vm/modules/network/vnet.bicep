@description('Virtual network name')
param name string

@description('Deployment location, e.g. centralus')
param location string

@description('Address prefixes for the VNet')
param addressPrefixes array

@description('Subnets to create')
param subnets array

@description('Network Security group ID')
param nsgId string

@description('Dedicated NSG ID for AzureBastionSubnet')
param bastionNsgId string = ''

resource vnet 'Microsoft.Network/virtualNetworks@2025-05-01' = {
  name: name
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: addressPrefixes
    }
    subnets: [
  for s in subnets: {
    name: s.name
    properties: {
      addressPrefix: s.prefix
      networkSecurityGroup: {
        id: s.name == 'AzureBastionSubnet' ? bastionNsgId : nsgId
      }
    }
  }
]

  }
}

output subnetIds array = [ 
  for s in subnets:{
    name: s.name
    id:resourceId('Microsoft.Network/virtualNetworks/subnets', name, s.name)
  }
]
