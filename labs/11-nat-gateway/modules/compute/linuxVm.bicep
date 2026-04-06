@description('Region')
param location string

@description('Base name without the numeric suffix, e.g. vm-test-cus-web')
param baseName string

@description('VM size, e.g. Standard_D2s_v3')
param vmSize string

@description('Target subnet resource ID')
param subnetId string

@description('How many VMs to create')
param count int = 1

@description('Admin username')
param adminUsername string = 'linuxadmin'

@secure()
@description('Admin password (use a Key Vault parameter reference)')
param adminPassword string


var indexes  = [for i in range(1, count): i]
var vmNames  = [for i in indexes: '${baseName}-${i}']
var nicNames = [for n in vmNames: replace(n, 'vm-', 'nic-')]

resource nics 'Microsoft.Network/networkInterfaces@2025-05-01' = [for (n, i) in nicNames: {
  name: n
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig-01'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: { id: subnetId }
         
        }
      }
    ]
  }
}]
resource vms 'Microsoft.Compute/virtualMachines@2025-04-01' = [for (vmName,i) in vmNames: {
  name: vmName
  location: location
  properties: {
    hardwareProfile: { vmSize: vmSize }
    storageProfile: {
      imageReference: {
        publisher: 'Canonical'
        offer: 'ubuntu-24_04-lts'
        sku: 'server'
        version: 'latest'
      }
      osDisk: {
        createOption: 'FromImage'
        managedDisk: { storageAccountType: 'Premium_LRS' }
      }
    }
    osProfile: {
      computerName: vmName
      adminUsername: adminUsername
      adminPassword: adminPassword
      linuxConfiguration: {
                disablePasswordAuthentication: false
      }
    }
    networkProfile: {
      networkInterfaces: [
        { id: nics[i].id }
      ]
    }
  }
}]

