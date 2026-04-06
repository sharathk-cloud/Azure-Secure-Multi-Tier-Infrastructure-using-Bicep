@description('Local VNet name (in this RG/subscription)')
param localVnetName string

param localVnetId string

@description('Remote VNet name (in this RG/subscription)')
param remoteVnetName string

param remoteVnetId string

resource localToRemote 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2025-05-01' = { 
  name:'${localVnetName}/peer-${localVnetName}-to-${remoteVnetName}'
  properties: { 
    remoteVirtualNetwork: { id:remoteVnetId}
    allowVirtualNetworkAccess: true
    allowForwardedTraffic: false
    allowGatewayTransit: false
    useRemoteGateways: false
  }
 }

 resource remoteToLocal 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2025-05-01' = { 
  name:'${remoteVnetName}/peer-${remoteVnetName}-to-${localVnetName}'
  properties: { 
    remoteVirtualNetwork: { id:localVnetId}
    allowVirtualNetworkAccess: true
    allowForwardedTraffic: false
    allowGatewayTransit: false
    useRemoteGateways: false
  }
 }
