# Storage Migration — FC Zoning, vSAN, and Storage Spaces Direct

Storage is the one area where "migrate the config" doesn't apply — none of
these three architectures talk to each other natively. Figure out which
box you're in below, because it changes the whole plan.

## Step 0 — What is your current shared storage, actually?

```powershell
# vSAN check
Get-VsanClusterConfiguration -Cluster <ClusterName>

# FC SAN check (datastores backed by FC LUNs)
Get-Datastore | Where-Object {$_.Type -eq "VMFS"} | Select Name, @{N='LunId';E={($_.ExtensionData.Info.Vmfs.Extent | Select -First 1).DiskName}}

# NFS check
Get-Datastore | Where-Object {$_.Type -eq "NFS"}
```

| Source | What it means for you |
|---|---|
| **VMware vSAN** | Proprietary to VMware — no direct migration path. Data must move VM-by-VM (Azure Migrate / Veeam), the underlying storage layer is simply retired |
| **FC SAN (VMFS on FC LUNs)** | The SAN array itself can usually be **reused** — you re-zone the new Hyper-V hosts' HBAs to the same array and present new LUNs formatted as CSVFS instead of VMFS |
| **NFS** | Reusable similarly to FC — re-point Hyper-V hosts at the NFS export (SMB3 is the Hyper-V-native equivalent if the array supports it) |

## Step 1 — Decide the target: keep FC SAN, or go Storage Spaces Direct (S2D)?

| | Continue with FC SAN | Move to S2D (Azure Stack HCI) |
|---|---|---|
| Hardware | Reuse existing SAN + fabric switches | Requires HCL-certified local NVMe/SSD per host, RDMA-capable NICs |
| Complexity | Familiar if your team already does FC zoning | New skillset (S2D, RDMA/RoCEv2 tuning) |
| Failure domain | SAN is a shared single point unless dual-fabric | Distributed across hosts, no shared array to fail |
| Cost pattern | Sunk cost in existing SAN, licensing is per-host for Hyper-V | Higher per-host hardware cost, no SAN/fabric switch licensing |
| Best fit | You already have FC SAN with capacity/life left | Greenfield or SAN is end-of-life anyway |

If keeping FC SAN with Hyper-V: LUNs get formatted as **CSVFS** (Cluster
Shared Volumes) instead of VMFS — conceptually the same "shared storage
multiple hosts can write to" model VMware users already understand.

## Step 2a — If continuing with FC SAN: zoning worksheet

Copy `templates/fc-zoning-worksheet.csv` and fill in one row per new
Hyper-V host HBA before racking. Standard practice: **single-initiator,
single-target zoning** (one HBA WWPN + one target port WWPN per zone) —
same best practice as your VMware zoning, don't deviate for the migration.

Pull new host WWPNs once HBAs are installed:
```powershell
Get-InitiatorPort | Select NodeAddress, PortAddress
```
Or use the bundled `scripts/Export-FC-HBA-Info.ps1` to export all hosts'
WWPNs straight into the zoning worksheet format.

Checklist before cutover:
- [ ] New host WWPNs registered on the array's host groups/initiator groups
- [ ] Zones created on both fabrics (dual-fabric redundancy, same as source)
- [ ] LUN masking updated to present target LUNs to new hosts
- [ ] MPIO configured on Hyper-V hosts (`Enable-MSDSMAutomaticClaiming`, `Set-MSDSMGlobalDefaultLoadBalancePolicy -Policy RR`)
- [ ] Test LUN visible via `Get-Disk` before formatting as CSVFS

## Step 2b — If moving to S2D: sizing worksheet

Copy `templates/storage-spaces-direct-sizing.csv`, one row per host,
using drive counts/sizes from your hardware quote. Key decisions to
record per cluster:

- **Resiliency**: two-way mirror (2-copy, ~50% usable, less host count needed) vs three-way mirror (3-copy, more resilient, needs 4+ hosts) vs parity (more usable capacity, higher write cost — rarely right for VM workloads)
- **Cache tier**: NVMe for cache + SSD/HDD for capacity, or all-NVMe/all-flash if budget allows
- **Fault domain awareness**: with only 4-6 hosts, you're almost always at the "2-node" or "3-4 node mirror" sizing tier — check current Microsoft S2D/Azure Stack HCI volume-planning guidance for your exact host count before ordering drives, this materially changes usable capacity math

```powershell
# Validate S2D-eligible storage after OS install, before enabling S2D
Test-Cluster -Node Host1,Host2,Host3,Host4 -Include "Storage Spaces Direct","Inventory","Network"
Enable-ClusterStorageSpacesDirect -PoolFriendlyName "S2D-Pool01"
```

## Rollback note

FC SAN path: don't unmask/remove LUN access from the old ESXi hosts until
the migration wave using that storage is fully validated — array-side
masking changes are your fastest rollback lever.

S2D path: there is no shared rollback array — your rollback is the
untouched source VM on VMware plus a validated Veeam restore point.
