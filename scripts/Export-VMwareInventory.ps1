<#
.SYNOPSIS
    Phase 1 discovery: read-only VMware inventory export for migration
    planning (VMware -> Hyper-V / Azure Stack HCI).

.DESCRIPTION
    Connects to vCenter with PowerCLI, pulls VM/cluster/host config data,
    and writes CSV + JSON reports. Read-only: makes no changes in vCenter.

.NOTES
    Requires: VMware.PowerCLI module (Install-Module VMware.PowerCLI -Scope CurrentUser)
    Use a read-only service account, not a personal admin login.
    Does NOT capture IOPS/performance history -- pull that separately from
    vCenter performance charts or vROps before sizing storage.

.EXAMPLE
    ./Export-VMwareInventory.ps1 -vCenterServer vcenter.example.local -OutputPath ./reports
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$vCenterServer,

    [Parameter(Mandatory = $false)]
    [string]$OutputPath = "./reports"
)

# Prompt for credentials interactively -- never hardcode them in the script
$cred = Get-Credential -Message "vCenter read-only service account"

if (-not (Test-Path $OutputPath)) {
    New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null
}

$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"

try {
    Connect-VIServer -Server $vCenterServer -Credential $cred -ErrorAction Stop | Out-Null

    Write-Host "Connected to $vCenterServer. Gathering VM inventory..." -ForegroundColor Cyan

    $vmReport = Get-VM | Select-Object `
        Name,
        PowerState,
        @{N = 'NumCpu'; E = { $_.NumCpu } },
        @{N = 'MemoryGB'; E = { [math]::Round($_.MemoryGB, 1) } },
        @{N = 'ProvisionedGB'; E = { [math]::Round($_.ProvisionedSpaceGB, 1) } },
        @{N = 'UsedGB'; E = { [math]::Round($_.UsedSpaceGB, 1) } },
        @{N = 'Cluster'; E = { (Get-Cluster -VM $_).Name } },
        @{N = 'ESXiHost'; E = { $_.VMHost.Name } },
        @{N = 'GuestOS'; E = { $_.Guest.OSFullName } },
        @{N = 'IPAddress'; E = { ($_.Guest.IPAddress -join ';') } },
        @{N = 'Folder'; E = { $_.Folder.Name } },
        @{N = 'MigrationWave'; E = { '' } },
        @{N = 'Notes'; E = { '' } }

    $csvPath = Join-Path $OutputPath "vm-inventory-$timestamp.csv"
    $vmReport | Export-Csv -Path $csvPath -NoTypeInformation
    Write-Host "VM inventory CSV: $csvPath" -ForegroundColor Green

    Write-Host "Gathering cluster/host capacity..." -ForegroundColor Cyan
    $clusterReport = Get-Cluster | Select-Object `
        Name,
        @{N = 'NumHosts'; E = { ($_ | Get-VMHost).Count } },
        @{N = 'TotalCpuGhz'; E = { [math]::Round((($_ | Get-VMHost | Measure-Object -Property CpuTotalMhz -Sum).Sum) / 1000, 1) } },
        @{N = 'TotalMemoryGB'; E = { [math]::Round((($_ | Get-VMHost | Measure-Object -Property MemoryTotalGB -Sum).Sum), 1) } },
        HAEnabled,
        DrsEnabled

    $clusterCsvPath = Join-Path $OutputPath "cluster-capacity-$timestamp.csv"
    $clusterReport | Export-Csv -Path $clusterCsvPath -NoTypeInformation
    Write-Host "Cluster capacity CSV: $clusterCsvPath" -ForegroundColor Green

    # Full-fidelity JSON dump as source of truth, same as the Ansible version
    $jsonPath = Join-Path $OutputPath "vm-inventory-$timestamp.json"
    $vmReport | ConvertTo-Json -Depth 5 | Out-File -FilePath $jsonPath -Encoding utf8
    Write-Host "VM inventory JSON: $jsonPath" -ForegroundColor Green

    Write-Host "`nDiscovered $($vmReport.Count) VMs across $($clusterReport.Count) cluster(s)." -ForegroundColor Yellow
    Write-Host "Reminder: this captures config/capacity only, not IOPS history." -ForegroundColor Yellow
}
finally {
    if ($global:DefaultVIServer) {
        Disconnect-VIServer -Server $vCenterServer -Confirm:$false
    }
}
