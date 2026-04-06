@description('Storage account name (3-24 lowercase letters and numbers)')
param name string

@description('Deployment location, e.g. centralus')
param location string

@description('Tags to apply to this resource')
param tags object = {}

resource sa 'Microsoft.Storage/storageAccounts@2025-06-01' = {
  name: name
  location: location
  tags: tags
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
}
