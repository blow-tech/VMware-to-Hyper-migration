> **Pending safety remediation:** read [REMEDIATION-2026-11.md](REMEDIATION-2026-11.md) before using deployment or collection examples. No production validation is implied.

# VMware → Hyper-V / Azure Stack HCI Migration Toolkit

A practical, field-tested structure for migrating a mid-size VMware
environment to Hyper-V or Azure Stack HCI — discovery, network and
storage design, backup validation, wave tracking, and decommission,
each with real templates and read-only automation, not just prose.

Built around a **4-6 host, 20-30 VM** environment (including Active
Directory domain controllers), but the methodology scales either
direction.

**Start here → [`docs/00-migration-overview.md`](docs/00-migration-overview.md)**
— the phase-by-phase guide that ties every doc and template below
together, including a diagram of how the phases gate each other.

## Why this exists

Most migration guidance is either a vendor whitepaper (sells you their
platform) or a checklist with no artifacts (tells you *what* to check,
not how to produce or track the evidence). This repo tries to close that
gap: every phase produces something concrete — a filled CSV, a passed
checklist, a proven restore — that the next phase depends on.

## Contains no real infrastructure data

Every credential, hostname, VLAN ID, and WWPN in this repo is a
placeholder. Real values go in files that are gitignored
(`group_vars/all.yml`, `inventory/hosts.yml`, `reports/*`, filled-in
templates if you choose to keep them local) — copy the `.example` files
and never commit the real ones.

## Repo structure

```
├── docs/
│   ├── 00-migration-overview.md      # START HERE — phase index + methodology
│   ├── network-vlan-mapping.md       # VMware portgroup -> Hyper-V SET switch
│   ├── storage-migration.md          # vSAN vs FC SAN vs Storage Spaces Direct
│   ├── backup-validation.md          # Veeam proxy redesign, prove restores work
│   ├── pre-cutover-checklist.md      # per-wave gate: network/storage/licensing/rollback
│   └── decommission-checklist.md     # retiring the old VMware environment
├── playbooks/
│   └── discover-vmware-inventory.yml # Ansible: read-only VM/cluster discovery
├── scripts/
│   ├── Export-VMwareInventory.ps1    # PowerCLI equivalent of the above
│   └── Export-FC-HBA-Info.ps1        # existing ESXi FC HBA reference export
├── templates/
│   ├── vlan-portgroup-mapping.csv
│   ├── fc-zoning-worksheet.csv
│   ├── storage-spaces-direct-sizing.csv
│   └── migration-wave-tracker.csv    # ties VM + network + storage + gate status per wave
├── inventory/hosts.yml.example
├── group_vars/all.yml.example
└── requirements.yml                  # Ansible collections
```

## Quick start

1. Read [`docs/00-migration-overview.md`](docs/00-migration-overview.md) for the full phase map
2. Run Phase 1 discovery (Ansible or PowerCLI — pick one, both produce
   the same reports) — see **Discovery** below
3. Work through Phase 2 network and storage design docs, filling in the
   templates as you go
4. Use `templates/migration-wave-tracker.csv` to plan and track waves,
   gated by `docs/pre-cutover-checklist.md` per wave
5. Validate backups (`docs/backup-validation.md`) before the first VM
   with real data moves
6. When fully migrated and soaked, work through
   `docs/decommission-checklist.md`

AD/DNS/DHCP cutover is intentionally a separate project/repo — see the
note in the overview doc for why.

## Discovery — read-only, both paths equivalent

**Ansible:**
```bash
ansible-galaxy collection install -r requirements.yml
pip install --user pyvmomi requests

cp inventory/hosts.yml.example inventory/hosts.yml
cp group_vars/all.yml.example group_vars/all.yml   # fill in real vcenter_hostname / username
ansible-vault encrypt_string 'YourPassword' --name 'vault_vcenter_password' >> group_vars/vault.yml

ansible-playbook playbooks/discover-vmware-inventory.yml --ask-vault-pass
```

**PowerCLI:**
```powershell
Install-Module VMware.PowerCLI -Scope CurrentUser
./scripts/Export-VMwareInventory.ps1 -vCenterServer vcenter.example.local -OutputPath ./reports
```

Both write to `./reports/` (gitignored): a full-fidelity JSON dump plus a
wave-planning-friendly CSV (VM specs, cluster, host, IP, empty
`migration_wave`/`notes` columns) and a cluster capacity report for
target sizing.

Use a **read-only vCenter service account**, not a personal admin login.

> Field names returned by `community.vmware.vmware_vm_info` can shift
> slightly between collection versions — if a CSV column comes back
> empty, check with `-vvv` and adjust `playbooks/templates/vm_inventory.csv.j2`.

## What this toolkit deliberately does not cover

- **IOPS/performance history** — pull from vCenter performance charts or
  vROps separately before sizing Azure Stack HCI storage
- **Application dependency mapping** — use a network flow tool or manual
  interviews; feed the result into the wave tracker's `dependency_group` column
- **AD/DNS/DHCP cutover runbook** — separate repo by design; DCs are
  rebuilt fresh on the target platform, never P2V'd

## Contributing / adapting this for your own migration

This is meant to be forked and adapted, not used verbatim. The
`.example` files and empty-header CSV templates are the actual interface
— copy them, fill them with your environment's real data, and keep the
real files out of version control (or push to a **private** repo if your
org wants the filled-in artifacts tracked).

If you find a gap running this against a real migration, the
[`docs/decommission-checklist.md`](docs/decommission-checklist.md) retro
step exists specifically to feed lessons back into a repo like this one
for the next migration.

## License

MIT — see [`LICENSE`](LICENSE). Use it, fork it, adapt it.
