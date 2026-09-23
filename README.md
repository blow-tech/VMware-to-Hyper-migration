# VMware → Hyper-V / Azure Stack HCI Migration Toolkit

Discovery, network, and storage planning templates for a VMware →
Hyper-V / Azure Stack HCI migration project. Contains **no real
infrastructure data** — every credential/hostname/WWPN is a placeholder
you fill in locally, and those files are gitignored so they never get
committed.

## Project structure

```
├── playbooks/discover-vmware-inventory.yml   # Phase 1: Ansible VM/cluster discovery
├── scripts/Export-VMwareInventory.ps1        # Phase 1: PowerCLI equivalent
├── scripts/Export-FC-HBA-Info.ps1            # Phase 2: existing ESXi FC HBA reference export
├── docs/network-vlan-mapping.md              # Phase 2: VMware portgroup -> Hyper-V SET switch mapping
├── docs/storage-migration.md                 # Phase 2: FC SAN zoning vs vSAN vs Storage Spaces Direct
├── templates/vlan-portgroup-mapping.csv       # fill in during network design
├── templates/fc-zoning-worksheet.csv          # fill in if continuing FC SAN
└── templates/storage-spaces-direct-sizing.csv # fill in if moving to S2D
```

All discovery tooling is **read-only** against vCenter: no VM creation, no
config changes. Reports write to `./reports/` (gitignored).

Read `docs/storage-migration.md` first if you're not sure whether your
source environment is vSAN, FC SAN, or NFS — that decision changes
whether the existing SAN is reusable at all.

## What this does NOT do
- No IOPS/performance history — pull that separately from vCenter
  performance charts or vROps before sizing Azure Stack HCI storage
- No application dependency mapping — that's a manual/discovery-tool step
  (or add one later, e.g. via a network flow tool)
- No VLAN/portgroup mapping — build that spreadsheet by hand against the
  cluster report this produces

## Prerequisites

**Ansible path:**
```bash
ansible-galaxy collection install -r requirements.yml
pip install --user pyvmomi requests
```

**PowerCLI path:**
```powershell
Install-Module VMware.PowerCLI -Scope CurrentUser
Set-PowerCLIConfiguration -InvalidCertificateAction Ignore -Confirm:$false  # only if using self-signed certs
```

Use a **read-only vCenter service account**, not a personal admin login.

## Setup (Ansible)

```bash
cp inventory/hosts.yml.example inventory/hosts.yml
cp group_vars/all.yml.example group_vars/all.yml
# edit group_vars/all.yml with your real vcenter_hostname / vcenter_username

# encrypt the vCenter password instead of storing it in plaintext
ansible-vault encrypt_string 'YourPassword' --name 'vault_vcenter_password' >> group_vars/vault.yml

ansible-playbook playbooks/discover-vmware-inventory.yml --ask-vault-pass
```

## Setup (PowerCLI)

```powershell
./scripts/Export-VMwareInventory.ps1 -vCenterServer vcenter.example.local -OutputPath ./reports
# prompts for credentials interactively -- never hardcoded
```

## Output

Both paths write to `./reports/` (gitignored):
- `vm-inventory-<timestamp>.csv` — one row per VM: vCPU, RAM, provisioned
  storage, cluster, host, IP, guest OS, plus empty `migration_wave` /
  `notes` columns to fill in during planning
- `vm-inventory-<timestamp>.json` — full-fidelity dump, source of truth
- `cluster-capacity-<timestamp>.csv` / `.json` — host count, aggregate
  CPU/RAM per cluster, for target sizing math

> Note: the exact field names returned by `community.vmware.vmware_vm_info`
> can shift slightly between collection versions. Run once with `-vvv` (or
> a quick `debug: var=vm_inventory` task) and adjust
> `playbooks/templates/vm_inventory.csv.j2` if a field comes back empty.

## Next steps after running Phase 1 discovery

1. Open the CSV, fill in `migration_wave` per VM based on dependency
   chains (app servers move with their DB in the same wave)
2. Cross-reference `cluster-capacity` output against Azure Stack HCI HCL
   sizing before ordering hardware
3. Pull IOPS baselines from vCenter/vROps separately — this tool doesn't
   capture them
4. Feed the VM list into the AD/DNS/DHCP migration runbook (handled
   separately — DCs are rebuilt fresh, not migrated)

## Phase 2 — Network and storage design

Once discovery is done:

1. **`docs/network-vlan-mapping.md`** — pull existing VMware
   portgroups/VLANs, map each to a target Hyper-V SET switch VLAN,
   get network team sign-off before the first migration wave
2. **`docs/storage-migration.md`** — determine whether source storage is
   vSAN (no reuse possible, VM-level migration only), FC SAN (array is
   often reusable, re-zone to new hosts), or NFS. Then either fill in
   `templates/fc-zoning-worksheet.csv` or
   `templates/storage-spaces-direct-sizing.csv` depending on the target
   decision

## Publishing this to your own GitHub

This repo has been `git init`'d locally with an initial commit. To push it
to your own GitHub:

```bash
git remote add origin git@github.com:<your-org>/vmware-to-hyperv-migration.git
git branch -M main
git push -u origin main
```

(Create the empty repo on GitHub first, without a README/license, so there's
no merge conflict on first push.)
