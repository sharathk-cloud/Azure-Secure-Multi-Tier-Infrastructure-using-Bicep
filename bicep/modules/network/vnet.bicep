@description('Virtual network name')
param name string

@description('Deployment location, e.g. centralus')
param location string

@description('Address prefixes for the VNet')
param addressPrefixes array

@description('Subnets to create')
param subnets array

@description('Shared NSG ID — applied to App subnet')
param nsgId string

@description('Dedicated NSG ID for AzureBastionSubnet')
param bastionNsgId string = ''

@description('NAT Gateway resource ID — applied to App subnet only. Leave empty to skip.')
param natGatewayId string = ''

@description('NSG ID for the Database subnet. Leave empty to use shared NSG.')
param dbNsgId string = ''

@description('Tags to apply to this resource')
param tags object = {}

resource vnet 'Microsoft.Network/virtualNetworks@2025-05-01' = {
  name: name
  location: location
  tags: tags
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
            id: s.name == 'AzureBastionSubnet'
              ? bastionNsgId
              : (contains(toLower(s.name), '-db-') && dbNsgId != '')
                  ? dbNsgId
                  : nsgId
          }

       
          natGateway: (natGatewayId != '' && !contains(toLower(s.name), 'bastion') && !contains(toLower(s.name), '-db-'))
            ? { id: natGatewayId }
            : null

      
          serviceEndpoints: s.name == 'snet-prod-cus-app-01'
            ? [{ service: 'Microsoft.Sql' }] : []
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
