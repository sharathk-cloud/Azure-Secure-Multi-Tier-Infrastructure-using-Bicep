// =============================================================
// Module  : natGateway.bicep
// Lab     : 11 - NAT Gateway
// Purpose : Restores outbound internet connectivity for VMs
//           sitting behind the Standard Internal Load Balancer.
//           Standard SKU ILB sets disableOutboundSnat: true by
//           default, cutting all outbound SNAT. NAT Gateway
//           provides a dedicated, scalable outbound path.
// =============================================================

@description('Azure region')
param location string

@description('Environment prefix used for naming, e.g. prod')
param environmentName string

@description('Resource ID of the dedicated Public IP for NAT Gateway')
param publicIpId string

@description('Tags to apply to this resource')
param tags object = {}

resource natGateway 'Microsoft.Network/natGateways@2025-05-01' = {
  name: 'ng-${environmentName}-cus-01'
  location: location
  tags: tags
  sku: {
    name: 'Standard'
  }
  properties: {
    idleTimeoutInMinutes: 10
    publicIpAddresses: [
      {
        id: publicIpId
      }
    ]
  }
}

output natGatewayId   string = natGateway.id
output natGatewayName string = natGateway.name
