# Pre-Cutover Checklist

Run this per migration wave, before any VM in that wave moves. This is
deliberately short — it's a gate, not a project plan. Anything that fails
here blocks the wave, not just that one VM.

## Network / firewall

- [ ] VLAN mapping confirmed for every VM in this wave
      (`templates/vlan-portgroup-mapping.csv`)
- [ ] Physical switchports feeding new hosts are trunked for the required
      VLANs — confirmed by network team, not assumed
- [ ] Firewall rules updated for new host/VM IPs if they change subnets
      — don't assume IP addresses carry over 1:1 unless explicitly
      designed that way
- [ ] Cluster east-west traffic ports open between Hyper-V hosts:
      - Live Migration: TCP 6600 (default, verify if changed)
      - Cluster heartbeat/CSV: relies on cluster network roles, confirm
        `Get-ClusterNetwork` shows correct role assignment
      - SMB (if using SMB Direct/RDMA for Live Migration or S2D): TCP 445
- [ ] Management network reachable from admin workstations/jump hosts
      before the VM needs day-2 management

## Storage

- [ ] Target datastore/CSV/volume has capacity headroom for this wave
      (not just total cluster capacity — actual free space on the target
      volume)
- [ ] FC zoning or S2D volume confirmed present and visible
      (`Get-Disk`, `Get-ClusterSharedVolume`) before migration starts,
      not discovered as a blocker mid-wave

## Backup

- [ ] Backup validation (`docs/backup-validation.md`) passed for this
      platform before the first wave — doesn't need to repeat per wave,
      but confirm the backup job scope includes the new wave's VMs after
      they land

## Licensing / activation

- [ ] Windows guest OS activation model checked — KMS host re-pointing
      needed if the new platform's KMS/AVMA setup differs from VMware
      side (`slmgr /dlv` to check current activation status pre-move,
      confirm post-move)
- [ ] Any BYOL application licensing tied to hardware IDs/MAC addresses
      checked — some licensing (not just Windows) keys off hardware
      fingerprints that change when the VM moves platforms. Check with
      the app vendor for anything license-sensitive before the wave, not
      after it's down

## Application

- [ ] App owner has confirmed RTO/RPO tolerance for this wave's downtime
      window
- [ ] Dependency chain confirmed — this wave includes every VM this
      app needs (DB, auth, dependent services) or has confirmed
      connectivity to VMs migrating in a later wave

## Rollback readiness

- [ ] Source VM powered off, not deleted, until post-migration validation
      passes
- [ ] Rollback owner and decision deadline agreed before the window opens
      — "how long do we try before we roll back" decided in advance, not
      mid-incident
