@description('Public IP name')
param name string

param location string

@description('SKU: Standard required for Bastion')
param sku string = 'Standard'

param allocation string = 'Static'

resource pip 'Microsoft.Network/publicIPAddresses@2025-05-01'={
  name:name
  location: location
  sku:{name:sku}
  properties:{publicIPAllocationMethod:allocation}
}

output PublicIPid string =pip.id
