# Backup Validation — Prove Restores Work Before Anything Cuts Over

A backup job that completes successfully on the new platform is not the
same thing as a backup that can restore. This phase exists to catch that
gap before it matters, not after.

## Why the Veeam architecture changes

VMware backup integration (CBT via vSphere API, proxy VMs with hot-add or
NBD transport) does not carry over to Hyper-V. Hyper-V backup uses the
**Hyper-V VSS writer** and Veeam's **On-Host** or **Off-Host proxy**
roles instead — different transport, different proxy placement, and a
different failure mode if misconfigured.

## Step 1 — Confirm version compatibility

```powershell
# Check installed Veeam version
Get-VBRServerSession | Select-Object Version

# Cross-reference against target requirements:
#   Hyper-V Server 2022         -> Veeam B&R v11a minimum, v12 recommended
#   Azure Stack HCI (22H2/23H2) -> Veeam B&R v12.1 minimum
```
If you're below the minimum, the Veeam upgrade is its own change-managed
project — surface this to the project timeline now, not during cutover
week.

## Step 2 — Add Hyper-V hosts/cluster to Veeam

```powershell
# Add the Hyper-V cluster as a managed server in Veeam
Add-VBRHvCluster -Name "HyperV-Cluster01" -Credentials (Get-VBRCredentials -Name "svc-veeam")
```
Confirm the proxy role (On-Host is simplest for a first pass — Off-Host
adds a dedicated proxy VM/host to offload transport, worth it at higher
VM density but not required to start).

## Step 3 — Run a real backup job on a throwaway VM

Don't validate against a VM anyone cares about. Migrate or build a
disposable test VM first, then:

```powershell
# Example: kick a backup job manually and wait for completion
Start-VBRJob -Job (Get-VBRJob -Name "HyperV-Test-Backup")
```

## Step 4 — Restore it. Actually restore it.

This is the step teams skip because the job showed green. Green backup
job status only proves the job ran — it says nothing about the restore
path.

```powershell
# Full VM restore to an isolated/staging network, not production
Start-VBRRestoreVM -Backup (Get-VBRBackup -Name "HyperV-Test-Backup") `
    -VMName "restore-test-01" -Server "HyperV-Host01" -Path "C:\RestoreStaging"
```
Boot it. Confirm the guest OS comes up cleanly and the data is intact.
Only then is backup validated for this platform.

## Checklist — gate before any production VM migrates

- [ ] Veeam version confirmed compatible with target platform
- [ ] Hyper-V cluster/hosts added and credentialed in Veeam
- [ ] Backup job completes successfully against a test VM
- [ ] **Full VM restore performed and guest boots successfully**
- [ ] File-level restore tested (spot-check, not just full-VM)
- [ ] Backup job schedule/retention matches or exceeds current VMware
      policy — don't silently regress RPO during the migration
- [ ] Backup storage/repository capacity sized for the new environment's
      total VM footprint, not just the pilot wave

## What "done" looks like

You should be able to point to a restored, booted VM on the new platform
and say "this came from a backup taken on this platform" — not "the job
said success." That's the bar before Phase 4 (pilot wave) starts moving
anything with real data on it.
