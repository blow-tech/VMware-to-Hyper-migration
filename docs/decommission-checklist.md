# VMware Decommission Checklist

Only start this once every VM has been stable on the new platform for a
minimum soak period (recommend 2-4 weeks) and all items below are true.
This is a one-way door for most of these steps — go slow.

## Gate — confirm before starting decommission

- [ ] Every VM from the discovery inventory accounted for: migrated,
      confirmed retired, or explicitly out of scope (documented why)
- [ ] Minimum soak period completed with no rollback triggered
- [ ] Backup validation on new platform has real production restore
      points now, not just the test-VM validation from Phase 3
- [ ] Application owners have signed off — not just infra team confidence

## Step 1 — Source VMs (reversible, do first)

- [ ] Power off source VMs (already done per-wave, confirm none missed)
- [ ] Remove source VMs from any monitoring/alerting — stop noise before
      deleting them
- [ ] **Wait** — don't delete yet. Keep powered-off VMs as a rollback
      option through the full soak period

## Step 2 — Storage (semi-reversible)

- [ ] FC SAN path: unmask/remove LUN access from old ESXi hosts only
      after confirming no source VM has been needed
- [ ] vSAN path: no reuse regardless, but don't destroy the vSAN
      datastore until source VMs are confirmed deletable
- [ ] Delete source VM disk files only after the soak period and explicit
      go-ahead — this step is not reversible

## Step 3 — vCenter / ESXi infrastructure

- [ ] Remove ESXi hosts from vCenter inventory
- [ ] Decommission vCenter Server Appliance (last, once nothing else
      depends on it for reporting/history you still need)
- [ ] Export final vCenter events/tasks history if compliance requires
      an audit trail before shutdown

## Step 4 — Licensing / contracts

- [ ] VMware licensing/support contracts — confirm renewal dates and
      cancel or right-size before auto-renewal, this is often the actual
      deadline driving the whole project timeline
- [ ] Any third-party tools licensed per-VMware-host (backup agents,
      monitoring) — reconcile license counts down

## Step 5 — Physical hardware (if retiring, not repurposing)

- [ ] Secure data wipe on decommissioned host local storage per your
      data handling policy
- [ ] FC HBA/cabling removed or repurposed, fabric zoning for old hosts
      cleaned up on the SAN switches (stale zones are a common audit
      finding later)
- [ ] Asset tracking/CMDB updated to reflect retired hardware

## Step 6 — Documentation

- [ ] Update network diagrams to remove decommissioned VMware
      infrastructure
- [ ] Archive this repo's filled-in templates (VLAN mapping, storage
      worksheets, wave tracker) somewhere permanent — they're your record
      of what actually happened, not just what was planned
- [ ] Close out the project with a short retro: what wave took longer
      than expected, what the mapping template missed, feed it back into
      this repo for the next migration
