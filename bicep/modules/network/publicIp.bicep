@description('Public IP name')
param name string

param location string

@description('SKU: Standard required for Bastion and NAT Gateway')
param sku string = 'Standard'

param allocation string = 'Static'

@description('Tags to apply to this resource')
param tags object = {}

resource pip 'Microsoft.Network/publicIPAddresses@2025-05-01' = {
  name: name
  location: location
  tags: tags
  sku: { name: sku }
  properties: { publicIPAllocationMethod: allocation }
}

output PublicIPid string = pip.id
