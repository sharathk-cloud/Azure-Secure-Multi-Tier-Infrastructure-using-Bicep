@description('URI to the script file (e.g., SAS URL from Storage or a raw GitHub URL)')
param scriptUri string

@secure()
@description('Command to execute on the VM after the file is downloaded')
param scriptCommand string = 'powershell -ExecutionPolicy Bypass -File .\\setup-iis.ps1'


@description('Azure region')
param location string

@description('VM size, e.g. Standard_D2s_v3')
param vmSize string

@description('Admin username')
param adminUserName string = 'azureadmin'

@secure()
@description('Admin password (or use Key Vault reference in the parameter file)')
param adminPassword string

param baseName string

@description('Target subnet resource ID')
param subnetId string

@description('How many VMs to create')
param count int

var indexes = [for i in range(1,count):i]
var vmNames = [for i in indexes: 'vm-${baseName}-${i}']
var nicNames=[for i in indexes: 'nic-${baseName}-${i}']

resource nics 'Microsoft.Network/networkInterfaces@2025-05-01' = [for (nicName,i) in nicNames:{ 
  name:nicName
  location:location
  properties: { 
    ipConfigurations: [ {
      name: 'ipconfig-01'
      properties: { 
        privateIPAllocationMethod:'Dynamic'
        subnet: {id:subnetId }
      }
    }]
  }
}]

resource vms 'Microsoft.Compute/virtualMachines@2025-04-01' = [for (vmName,i) in vmNames:{ 
   name:vmName
   location:location
   properties: { 
    hardwareProfile: {
      vmSize: vmSize
    }
    osProfile: {
      computerName: vmName
      adminUsername: adminUserName
      adminPassword: adminPassword
      
    }

     storageProfile: {
      imageReference: {
        publisher: 'MicrosoftWindowsServer'
        offer:     'WindowsServer'
        sku:       '2025-datacenter'
        version:   'latest'
      }
      osDisk: {
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: 'Premium_LRS'
        }
      }
    }

    networkProfile: {
      networkInterfaces:[ {
        id:nics[i].id
        properties: { primary: true }
      }]
    }
   }
}]

resource vmCse 'Microsoft.Compute/virtualMachines/extensions@2025-04-01' = [
  for i in range(0, length(vmNames)): {
    name: 'cse-init'                      
    location: location
    parent: vms[i]                        
    properties: {
      publisher: 'Microsoft.Compute'
      type: 'CustomScriptExtension'
      typeHandlerVersion: '1.10'
      autoUpgradeMinorVersion: true
      settings: {
        fileUris: [
          scriptUri                       
        ]
      }
      protectedSettings: {
        commandToExecute: scriptCommand   
      }
    }
  }
]

