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

resource natGateway 'Microsoft.Network/natGateways@2025-05-01' = {
  name: 'ng-${environmentName}-cus-01'
  location: location

  // Standard is the only supported SKU for NAT Gateway
  sku: {
    name: 'Standard'
  }

  properties: {
    // How long an idle TCP connection keeps a SNAT port reserved.
    // 10 minutes suits most web workloads without wasting ports.
    idleTimeoutInMinutes: 10

    // The dedicated Public IP all outbound traffic will exit through
    publicIpAddresses: [
      {
        id: publicIpId
      }
    ]
  }
}

output natGatewayId   string = natGateway.id
output natGatewayName string = natGateway.name
