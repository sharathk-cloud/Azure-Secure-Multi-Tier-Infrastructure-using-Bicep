param name string
param location string

@description('Array of security rules, each like the ARM schema')
param rules array

@description('Tags to apply to this resource')
param tags object = {}

resource nsg 'Microsoft.Network/networkSecurityGroups@2025-05-01' = {
  name: name
  location: location
  tags: tags
  properties: {
    securityRules: [
      for r in rules: r
    ]
  }
}

output nsgId string = nsg.id
