@description('Azure region')
param location string

@description('Load balancer name')
param lbName string

@description('Subnet ID for the private frontend')
param subnetId string

@description('Frontend name')
param feName string = 'fe-ilb-01'

@description('Backend pool name')
param beName string = 'be-ilb-01'

@description('HTTP probe path')
param probePath string = '/'

@description('Probe name')
param probeName string = 'hp-http-80'

@description('LB rule name')
param ruleName string = 'lbr-http-80'

resource lb 'Microsoft.Network/loadBalancers@2025-05-01' = {
name: lbName
  location: location
  sku: { name: 'Standard' }
  properties: { 
    frontendIPConfigurations: [
      {
        name: feName
        properties: {
          subnet: { id: subnetId }
          privateIPAllocationMethod: 'Dynamic' 
        }
      }
    ]

    backendAddressPools: [
      {
        name: beName
      }
    ]

    probes: [
      {
        name: probeName
        properties: {
          protocol: 'Http'
          port: 80
          requestPath: probePath
          intervalInSeconds: 5
          numberOfProbes: 2
        }
      }
    ]

    loadBalancingRules: [
      {
        name: ruleName
        properties: {
          protocol: 'Tcp'
          frontendIPConfiguration: {
            id: resourceId('Microsoft.Network/loadBalancers/frontendIPConfigurations', lbName, feName)
          }
          backendAddressPool: {
            id: resourceId('Microsoft.Network/loadBalancers/backendAddressPools', lbName, beName)
          }
          probe: {
            id: resourceId('Microsoft.Network/loadBalancers/probes', lbName, probeName)
          }
          frontendPort: 80
          backendPort: 80
          idleTimeoutInMinutes: 4
          enableTcpReset: true
          loadDistribution: 'Default'
          disableOutboundSnat: true
        }
      }
    ]

  }

}

output backendPoolId string = resourceId('Microsoft.Network/loadBalancers/backendAddressPools', lbName, beName)
