# Script remediation — 8 November 2026

Both PowerCLI exporters now retain the exact connection object, use -NotDefault and pass -Server to collectors. Finally disconnects only that owned connection, including failed-connect handling. HBA WWNs are padded to 16 hex digits. Cluster host capacity collects each cluster's hosts once, and unique run filenames prevent same-second collisions. Complete marker is written only after all VMware planning exports succeed; files without the marker are incomplete evidence, not final inventory. JSON is selected planning fields, not a full-fidelity vSphere backup.

Ansible discovery defaults TLS validation on and freezes one timestamp for all outputs. Existing example now validates certificates. PowerCLI uses existing certificate policy; trusted certificates are an operator prerequisite. No session/credential policy is changed. PowerCLI/Ansible schemas are not identical and must be mapped explicitly.

Validation: mocked CI only, no live vCenter. Required lab: supported PowerCLI/vCenter versions, multiple concurrent sessions, empty/standalone hosts, WWPN mapping, partial-export failure and restore/recovery planning. No migration performed. Performance benefit expected from one host collection per cluster, not measured.

Local validation: YAML parsing; VMware PowerCLI connection-scope/failure/WWPN/JSON fixtures passed in PowerShell 7.4.13 for the migration repository. Windows versions and Ansible contracts are checked by the PR CI; infrastructure integration remains unverified.
