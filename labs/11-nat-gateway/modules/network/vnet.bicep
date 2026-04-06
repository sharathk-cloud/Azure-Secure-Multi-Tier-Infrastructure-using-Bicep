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

// Lab 11 addition — NAT Gateway ID
// When provided, the App subnet is associated with the NAT Gateway
// so VMs behind the Standard ILB can reach the internet again.
// Defaults to empty so earlier labs that call this module still work.
@description('NAT Gateway resource ID — applied to App subnet only. Leave empty to skip.')
param natGatewayId string = ''

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
          // Associate the NAT Gateway only on the App subnet.
          // AzureBastionSubnet and DB subnet must NOT have NAT Gateway.
          // The ternary returns null when not applicable — Bicep omits
          // null properties from the ARM payload automatically.
          natGateway: (natGatewayId != '' && !contains(toLower(s.name), 'bastion') && !contains(toLower(s.name), '-db-'))
            ? { id: natGatewayId }
            : null
        }
      }
    ]
  }
}

output subnetIds array = [
  for s in subnets: {
    name: s.name
    id: resourceId('Microsoft.Network/virtualNetworks/subnets', name, s.name)
  }
]

output vnetId string = vnet.id
