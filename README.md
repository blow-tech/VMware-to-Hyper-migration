# VMware → Hyper-V / Azure Stack HCI Migration — Phase 1 Discovery

Read-only inventory pull from vCenter to seed migration-wave planning for a
VMware → Hyper-V / Azure Stack HCI migration project. Contains **no real
infrastructure data** — every credential/hostname is a placeholder you fill
in locally, and those files are gitignored so they never get committed.

Two equivalent implementations, use whichever fits your team:
- `playbooks/discover-vmware-inventory.yml` — Ansible (community.vmware)
- `scripts/Export-VMwareInventory.ps1` — PowerCLI

Both are **read-only** against vCenter: no VM creation, no config changes.
They only write report files to `./reports/`.

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

## Next steps after running this

1. Open the CSV, fill in `migration_wave` per VM based on dependency
   chains (app servers move with their DB in the same wave)
2. Cross-reference `cluster-capacity` output against Azure Stack HCI HCL
   sizing before ordering hardware
3. Pull IOPS baselines from vCenter/vROps separately — this tool doesn't
   capture them
4. Feed the VM list into the AD/DNS/DHCP migration runbook (handled
   separately — see project notes, DCs are rebuilt fresh, not migrated)

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
