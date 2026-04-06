// =============================================================
// Module  : sqlDatabase.bicep
// Lab     : 12 - SQL Database
// Purpose : Deploys Azure SQL Server + Serverless SQL Database
//           completing the three-tier architecture by populating
//           the previously empty Database subnet with a real
//           data tier. Access is restricted to the App subnet
//           only via a VNet rule + the DB NSG.
// Tier    : Serverless — auto-pauses after 60 min of inactivity
//           so the lab incurs near-zero cost when not in use.
// Secrets : Admin password injected from Key Vault at deploy time
// =============================================================

@description('Azure region')
param location string

@description('Environment prefix used for naming, e.g. prod')
param environmentName string

@description('SQL Server administrator login username')
param sqlAdminLogin string

@description('SQL admin password — must come from a Key Vault reference in the parameter file')
@secure()
param sqlAdminPassword string

@description('Name of the production VNet — needed to build the subnet resource ID for the VNet rule')
param vnetName string

@description('Name of the Database subnet — SQL access is restricted to this subnet')
param appSubnetName string

// ── Naming (matches existing convention across all labs) ──────

var sqlServerName   = 'sql-${environmentName}-cus-db-01'
var sqlDatabaseName = 'sqldb-${environmentName}-cus-01'

// ── SQL Server ───────────────────────────────────────────────

resource sqlServer 'Microsoft.Sql/servers@2022-05-01-preview' = {
  name: sqlServerName
  location: location

  properties: {
    administratorLogin: sqlAdminLogin
    administratorLoginPassword: sqlAdminPassword



    // Reject TLS < 1.2 — Azure Security Center flags lower versions
    minimalTlsVersion: '1.2'
  }
}

// ── VNet Rule ─────────────────────────────────────────────────
// Restricts SQL Server access to the Database subnet.
// Requires the Microsoft.Sql service endpoint on that subnet
// (added to vnet.bicep in this lab).

resource vnetRule 'Microsoft.Sql/servers/virtualNetworkRules@2022-05-01-preview' = {
  parent: sqlServer
  name: 'allow-app-subnet-only'
  properties: {
    virtualNetworkSubnetId: resourceId(
      'Microsoft.Network/virtualNetworks/subnets',
      vnetName,
      appSubnetName   
    )
    ignoreMissingVnetServiceEndpoint: false
  }
}

// ── Serverless SQL Database ───────────────────────────────────

resource sqlDatabase 'Microsoft.Sql/servers/databases@2022-05-01-preview' = {
  parent: sqlServer
  name: sqlDatabaseName
  location: location

  // GP_S_Gen5 = General Purpose Serverless Gen5
  sku: {
    name: 'GP_S_Gen5_2'    // Max 2 vCores
    tier: 'GeneralPurpose'
    family: 'Gen5'
    capacity: 2
  }

  properties: {
    // ── Serverless config ──────────────────────────────────
    autoPauseDelay: 60          // Auto-pause after 60 min idle — reduces cost to near zero
    minCapacity: json('0.5')    // Minimum 0.5 vCores when active

    // ── Storage ───────────────────────────────────────────
    maxSizeBytes: 2147483648    // 2 GB — sufficient for a lab database

    // ── Backup ────────────────────────────────────────────
    // LRS = Locally Redundant Storage — cheapest backup tier for lab use
    requestedBackupStorageRedundancy: 'Local'

    zoneRedundant: false        // Single zone — keeps lab cost low

    collation: 'SQL_Latin1_General_CP1_CI_AS'
  }
}

// ── Outputs ──────────────────────────────────────────────────

output sqlServerName   string = sqlServer.name
output sqlServerFqdn   string = sqlServer.properties.fullyQualifiedDomainName
output sqlDatabaseName string = sqlDatabase.name
