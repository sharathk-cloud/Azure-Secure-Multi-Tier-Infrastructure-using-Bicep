# Architecture

## Overview

This project deploys a production-style Azure network environment across two Virtual Networks connected by bidirectional VNet Peering. The production VNet hosts three tiers — application, database, and management — each with its own subnet and dedicated NSG. All VM access goes through Azure Bastion. Outbound internet traffic from the App subnet routes through a NAT Gateway. The database tier runs Azure SQL Serverless, restricted to the App subnet via a VNet rule. All resources are tagged consistently for cost tracking.

---

## Network Topology

| VNet | CIDR | Purpose |
|------|------|---------|
| `vnet-prod-cus-01` | 10.0.0.0/16 | Production workloads |
| `vnet-staging-cus-01` | 10.1.0.0/16 | Staging and validation |

### Subnets — Production VNet

| Subnet | CIDR | Contents | NSG |
|--------|------|----------|-----|
| `snet-prod-cus-app-01` | 10.0.0.0/24 | Windows VMs, ILB, NAT Gateway | `nsg-prod-cus-shared-01` |
| `snet-prod-cus-db-01` | 10.0.1.0/24 | Database tier | `nsg-db-prod-cus-01` |
| `AzureBastionSubnet` | 10.0.2.0/24 | Azure Bastion | `nsg-bas-prod-cus-01` |

### Subnets — Staging VNet

| Subnet | CIDR | Contents | NSG |
|--------|------|----------|-----|
| `snet-staging-cus-app-01` | 10.1.0.0/24 | Linux VM | `nsg-prod-cus-shared-01` |

---

## Module Dependency Chain

ARM resolves most dependencies automatically from Bicep output references. `dependsOn` is added explicitly where a resource needs to exist before another references its ID at the subnet level.

```
Wave 1 (parallel):  sharednsg  bastionNsgModule  dbNsgModule  storage  pipNat  basPip
Wave 2:             natGw (waits: pipNat)
Wave 3 (parallel):  devnet  (waits: sharednsg + bastionNsgModule + dbNsgModule + natGw)
                    testnet (waits: sharednsg)
Wave 4 (parallel):  ilb     (waits: devnet)
                    bastionhost (waits: devnet + basPip)
                    linWeb  (waits: testnet)
Wave 5:             winWeb  (waits: devnet + ilb)
Wave 6:             sqlDb   (waits: devnet)
Wave 7:             vnetpeering (waits: devnet + testnet)
```

---

## Prerequisites Checklist

Before running `New-AzResourceGroupDeployment`, the following must exist:

- [ ] Resource group `rg-infra-prod-cus-01` in Central US
- [ ] Key Vault `kv-prod-cus-01` in the same resource group
- [ ] Secret `win-app-admin-password` in the Key Vault
- [ ] Secret `linux-app-admin-password` in the Key Vault
- [ ] Secret `sql-admin-password` in the Key Vault *(Labs 12–13 only)*
- [ ] Deploying identity has `Key Vault Secrets User` RBAC role on the vault
- [ ] Storage account `stprodcusinfra01` with `setup-iis.ps1` in a `scripts` container
- [ ] Check the SAS Token `se=` expiry date in `params/dev.parameters.json` before deploying 
- [ ] Subscription ID placeholder replaced with your real subscription ID

---

## Design Decisions

**Why does each subnet have its own NSG instead of one shared NSG?**
Early labs used a single shared NSG across all subnets, which worked for basic isolation. When the SQL database tier was added, it became clear that one NSG couldn't cleanly express different rules for different tiers without becoming messy. Having a separate NSG per subnet (`nsg-prod-cus-shared-01` for the App tier, `nsg-db-prod-cus-01` for the DB tier, `nsg-bas-prod-cus-01` for Bastion) keeps each NSG focused on one job and makes the intent obvious when reading the rules.

**Why is the NSG attachment inline inside `vnet.bicep` rather than a separate resource?**
The original approach patched subnets with NSG associations after the VNet was created, using a separate resource in `nsg.bicep`. This caused `AnotherOperationInProgress` errors because two ARM operations were trying to modify the same subnet at the same time. Passing the NSG ID directly into `vnet.bicep` as a parameter and applying it during subnet creation eliminates this race condition entirely and removes the need for explicit `dependsOn`.

**Why NAT Gateway instead of an outbound rule on the ILB?**
Standard SKU ILB disables outbound SNAT by default. The outbound rule approach works but allocates a fixed number of SNAT ports per VM, which becomes a problem under load. NAT Gateway scales automatically, is the recommended approach for any new design involving a Standard ILB, and is what production teams use. The cost difference for a lab environment is minimal.

**Why VNet Peering instead of a single large VNet for prod and staging?**
Separate VNets give each environment an independent failure boundary. If the staging VNet has a misconfiguration that causes a network outage, it stays contained. Peering provides the cross-VNet connectivity needed for validation scenarios (testing from the Linux VM) while keeping the environments logically separated.

**Why service endpoint over Private Endpoint for SQL access control?**
Private Endpoints give SQL Server a real private IP inside the VNet and are the correct choice for production. For this lab, service endpoints were used because they achieve the same subnet-level access restriction without the additional cost of a Private Endpoint (~$7/month) or the DNS complexity of a Private DNS Zone. The VNet rule and DB subnet NSG together provide strong isolation. The code comments explicitly note that Private Endpoint would replace this in a production design.
