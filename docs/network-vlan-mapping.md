# Network Migration — VLAN / Portgroup Mapping

The single most common post-migration incident is a VM landing on the new
platform with no network connectivity because the target VLAN wasn't wired
up to match the source portgroup. This mapping must be built and reviewed
**before** the first VM moves, not discovered during cutover.

## 1. Pull the current VMware side

**PowerCLI:**
```powershell
Get-VirtualPortGroup | Select-Object `
    Name,
    VLanId,
    @{N='VSwitch';E={$_.VirtualSwitchName}},
    @{N='VMHost';E={$_.VMHost.Name}} |
    Export-Csv ./reports/vmware-portgroups.csv -NoTypeInformation

# Distributed switches, if in use
Get-VDPortgroup | Select-Object Name, VlanConfiguration |
    Export-Csv ./reports/vmware-dvportgroups.csv -NoTypeInformation
```

**Or from ESXi CLI (per host, if not using vCenter):**
```bash
esxcli network vswitch standard portgroup list
esxcli network vswitch standard portgroup get -p <portgroup-name>
```

## 2. Fill in the mapping template

Copy `templates/vlan-portgroup-mapping.csv`, one row per VMware
portgroup, and fill in the target Hyper-V side as you design the new
switch layout.

Key concept translation:

| VMware | Hyper-V / Azure Stack HCI equivalent |
|---|---|
| Standard vSwitch | Virtual Switch (per host) |
| Distributed vSwitch (VDS) | **SET (Switch Embedded Teaming)** switch — the closest equivalent, gives you the same host-independent, teamed-NIC behavior |
| Portgroup + VLAN ID | VM network adapter's `-VlanId` on the SET switch |
| NIC teaming policy (route based on IP hash / physical NIC load) | SET load-balancing algorithm (`Dynamic` or `HyperVPort`) |

## 3. Build the target SET switch (example)

```powershell
New-VMSwitch -Name "SET-Switch01" -NetAdapterName "NIC1","NIC2" `
    -EnableEmbeddedTeaming $true -AllowManagementOS $true

# Per-VM VLAN tagging, matching the mapping CSV
Set-VMNetworkAdapterVlan -VMName "AppServer01" -Access -VlanId 110
```

## 4. Validate before cutover

For every VM in a migration wave, confirm the target VLAN ID in the
mapping CSV matches an actual routed/trunked VLAN on the physical switch
ports feeding the new Hyper-V hosts — get network team sign-off on the
switchport trunk config before the wave, not after a VM can't reach its
gateway.

```powershell
# Quick connectivity smoke test post-migration
Test-NetConnection -ComputerName <gateway-ip> -Port 0 -InformationLevel Detailed
```

## Rollback note

Keep the source VM's VMware portgroup untouched and the VM powered off
(not deleted) until the migrated VM has passed connectivity validation.
That's your rollback path if the VLAN mapping was wrong.
