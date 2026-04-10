# Troubleshooting

Real issues encountered during this project and how they were resolved.

---

## 1. Custom Script Extension reports Succeeded but IIS is not installed

**Symptom:** Deployment completes with `ProvisioningState: Succeeded`. VMs are running. Connecting via Bastion shows no IIS page — connection refused on port 80. Checking the VM Extensions blade shows `cse-init` in `Failed` state with a storage error.

**Cause:** The SAS token in `winWebConfig.scriptUri` inside `dev.parameters.json` had expired. The CSE agent on the VM tried to download `setup-iis.ps1` from blob storage but received HTTP 403 Forbidden. ARM considers the extension resource created successfully regardless of whether the script actually ran.

**Resolution:** Regenerate the SAS token in the Azure portal — go to Storage Account → container → `setup-iis.ps1` → Generate SAS. Set an expiry date far enough in the future. Paste the new URL into `parameters/dev.parameters.json` before redeploying.

**Key insight:** ARM deployment success does not guarantee execution success. Always validate the VM extension status separately after deployment.

---

## 2. `AzureBastionSubnet` name validation error

**Symptom:** Deployment fails with a validation error stating the subnet name is not valid for Bastion.

**Cause:** Azure mandates the exact name `AzureBastionSubnet` — this capitalisation, this spelling, no variation. Names like `bastion-subnet` or `BastionSubnet` are rejected without a helpful error message.

**Resolution:** Ensure the subnet name in `parameters/dev.parameters.json` is exactly `AzureBastionSubnet`.

---

## 3. VNet Peering status shows `Initiated` instead of `Connected`

**Symptom:** After deployment, one VNet's peering blade shows `Connected` but the other shows `Initiated`. Cross-VNet traffic does not flow.

**Cause:** VNet peering requires a separate resource for each direction — one from prod to staging and one from staging to prod. If only one direction is created successfully, the peering is one-sided and traffic does not flow in either direction.

**Resolution:** Check the deployment output for errors on the `vnet-peering-prod-staging` module. Both VNets must show `Connected` before any cross-VNet traffic works. Redeploying the module or manually creating the missing direction in the portal resolves it.

---

## 4. Standard ILB breaks outbound internet from VMs

**Symptom:** After deploying the ILB in Lab 08, VMs in the backend pool can no longer reach the internet — Windows Update fails, outbound HTTPS times out.

**Cause:** Standard SKU ILB sets `disableOutboundSnat: true` by default. Unlike Basic SKU, Standard ILB does not provide implicit outbound internet access to backend VMs.

**Resolution:** A NAT Gateway was added in Lab 11. The NAT Gateway is associated with the App subnet, providing a dedicated outbound path that routes around the ILB restriction. This is the recommended production approach.

---

## 5. SQL Server deployment fails with `NameAlreadyExists`

**Symptom:** Deployment fails with: `The name 'sql-prod-cus-01' already exists. Choose a different name.`

**Cause:** Azure SQL Server names are globally unique across all Azure subscriptions worldwide — not just your own. A generic name like `sql-prod-cus-01` is almost certainly already taken by someone else.

**Resolution:** Appended a suffix to make the name unique within the resource group scope. The same constraint applies to Storage Accounts — which is why `stprodcusinfra01` uses a compressed naming style rather than something generic.

---

## 6. Bicep incremental mode leaves orphaned resources after template changes

**Symptom:** A resource was removed from a Bicep module and the template was redeployed. The resource still existed in Azure and continued to affect behaviour.

**Cause:** Bicep uses incremental deployment mode by default. In incremental mode, resources removed from the template are not deleted from Azure — they are simply no longer managed by the deployment. The resource remains in Azure until explicitly deleted.

**Resolution:** Manually delete the orphaned resource using the CLI or portal after removing it from the template. Then redeploy to confirm the desired state.

**Key insight:** Removing a resource from a Bicep template does not delete it from Azure in incremental mode. Always verify the actual Azure state matches the template after removing resources.

---

## 7. `nc` reports SQL port as open even when access is blocked

**Symptom:** Running `nc -zv <sql-fqdn> 1433` from the Linux VM returns "Connected" even after the VNet rule was correctly configured to block the staging subnet.

**Cause:** Azure SQL's public gateway always completes the TCP handshake before evaluating firewall rules. Tools like `nc`, `telnet`, and `curl telnet://` only test the TCP layer — they report success as soon as the handshake completes, which happens before SQL checks whether the source is allowed.

**Resolution:** Test with an actual SQL client that speaks the SQL Server protocol. `sqlcmd` produces a real authentication attempt that hits the firewall check:

```bash
/opt/mssql-tools/bin/sqlcmd -S <sql-fqdn> -U sqladmin -P 'YourPassword' -Q "SELECT 1"
```

A blocked connection returns: `Cannot open server requested by the login. Client with IP address '10.1.x.x' is not allowed to access the server.`

This error message is better validation evidence than a successful `nc` result — it confirms the VNet rule evaluated the source and rejected it.

---

## 8. Resource group not found — deployment never starts

**Symptom:** `New-AzResourceGroupDeployment` fails immediately with `ResourceGroupNotFound`.

**Cause:** `New-AzResourceGroupDeployment` deploys into an existing resource group — it does not create one.

**Resolution:**

```powershell
New-AzResourceGroup -Name rg-infra-prod-cus-01 -Location centralus
```
