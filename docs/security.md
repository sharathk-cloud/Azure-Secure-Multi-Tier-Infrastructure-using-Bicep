# Security Design

## Principles

1. No VM has a public IP address — Bastion is the only management ingress
2. Secrets never appear in code, parameter files, terminal history, or ARM deployment logs
3. RDP is restricted to the Bastion subnet source only — not open to the internet
4. Each subnet tier has its own dedicated NSG with least-privilege rules
5. Database access is restricted to the App subnet only — not reachable from the internet or staging

---

## Azure Bastion

`bas-prod-cus-01` (Standard SKU) provides browser-based RDP and SSH over HTTPS port 443. Admins authenticate through Entra ID. The VM never receives a connection from the internet — Bastion proxies the session internally and the VM only sees traffic from the Bastion subnet.

**Key configuration:**
- SKU: Standard — required for native client support and tunneling
- `enableTunneling: true` — allows native RDP client alongside browser-based access
- `scaleUnits: 2` — minimum for Standard SKU high availability

---

## Bastion NSG — `nsg-bas-prod-cus-01`

`AzureBastionSubnet` requires a dedicated NSG with exactly these rules. Missing or misconfiguring any of them causes sessions to fail silently.

| Rule | Direction | Protocol | Port | Source | Purpose |
|------|-----------|----------|------|--------|---------|
| `AllowHttpsInBound` | Inbound | TCP | 443 | Internet | Admin browser sessions |
| `AllowGatewayManagerInBound` | Inbound | TCP | 443 | GatewayManager | Azure control plane |
| `AllowLoadBalancerInBound` | Inbound | TCP | 443 | AzureLoadBalancer | Health probes |
| `AllowBastionHostCommunicationInBound` | Inbound | * | 8080, 5701 | VirtualNetwork | Inter-host communication |
| `AllowSshRdpOutBound` | Outbound | TCP | 22, 3389 | * | VM access |
| `AllowAzureCloudOutBound` | Outbound | TCP | 443 | AzureCloud | Platform services |
| `AllowBastionHostCommunicationOutBound` | Outbound | * | 8080, 5701 | VirtualNetwork | Inter-host communication |
| `AllowGetSessionInformationOutBound` | Outbound | TCP | 80 | Internet | Session certificate validation |

---

## Shared App Subnet NSG — `nsg-prod-cus-shared-01`

Applied to `snet-prod-cus-app-01` and `snet-staging-cus-app-01`.

| Rule | Direction | Protocol | Port | Source | Destination | Priority |
|------|-----------|----------|------|--------|-------------|----------|
| `in-allow-rdp-from-bastion-subnet` | Inbound | TCP | 3389 | 10.0.2.0/24 | * | 400 |
| `in-allow-http-from-internet-to-10-0-0-4` | Inbound | TCP | 80 | Internet | 10.0.0.4 | 410 |

The RDP source is the Bastion subnet CIDR (`10.0.2.0/24`), not `*`. No internet IP can reach port 3389 directly.

---

## Database Subnet NSG — `nsg-db-prod-cus-01`

Applied exclusively to `snet-prod-cus-db-01`. Only the App subnet can reach port 1433.

| Rule | Direction | Protocol | Port | Source | Destination | Priority |
|------|-----------|----------|------|--------|-------------|----------|
| `in-allow-sql-from-app-subnet` | Inbound | TCP | 1433 | 10.0.0.0/24 | 10.0.1.0/24 | 100 |
| `in-allow-azure-services` | Inbound | TCP | 1433 | AzureCloud | 10.0.1.0/24 | 200 |
| `in-deny-all-other` | Inbound | * | * | * | * | 4000 |

---

## SQL Server Access Control

Azure SQL access is controlled through two complementary layers:

**Layer 1 — VNet Service Endpoint + VNet Rule**
The App subnet (`snet-prod-cus-app-01`) has a `Microsoft.Sql` service endpoint enabled. The SQL Server has a VNet rule (`allow-app-subnet-only`) that allows connections only from that subnet. Connections from any other subnet — including the staging VNet via peering — are rejected at the SQL gateway level with an explicit error citing the source IP.

**Layer 2 — DB Subnet NSG**
The NSG on `snet-prod-cus-db-01` restricts inbound port 1433 to the App subnet CIDR only. This provides defence-in-depth at the network level independent of the SQL firewall.


**TLS enforcement:**
`minimalTlsVersion: '1.2'` is set on the SQL Server. Azure Security Center flags anything lower as a finding.

---

## Key Vault Password Management

VM and SQL passwords are never stored in parameter files. The ARM deployment engine resolves Key Vault references before the deployment starts:

```json
"winWebAdminPassword": {
  "reference": {
    "keyVault": {
      "id": "/subscriptions/<your-subscription-id>/resourceGroups/rg-infra-prod-cus-01/providers/Microsoft.KeyVault/vaults/kv-prod-cus-01"
    },
    "secretName": "win-app-admin-password"
  }
}
```

The `@secure()` decorator on Bicep parameters ensures the resolved value is never written to ARM deployment history, never visible in `az deployment group show` output, and never logged in Azure Monitor or Activity Log.

**Required permission:** The deploying identity needs `Key Vault Secrets User` RBAC on `kv-prod-cus-01`.

---

## Resource Tagging

All resources are tagged consistently from Lab 13 onwards. Tags are defined once in `dev.parameters.json` and flow through `main.bicep` into every module:

| Tag | Value |
|-----|-------|
| `Environment` | prod |
| `Project` | azure-secure-multi-tier-infra |
| `Owner` | Sharath Kumar |
| `CostCenter` | lab |
| `ManagedBy` | Bicep |

VNet peering child resources (`virtualNetworkPeerings`) do not support tags in Azure and are excluded intentionally.

---

## What This Repository Does Not Contain

- Real subscription IDs — replaced with `<your-subscription-id>`
- Real Key Vault resource paths — replace with your vault name before deploying
- SAS tokens — regenerate before each deployment and paste into `params/dev.parameters.json`
- VM or SQL passwords of any kind
