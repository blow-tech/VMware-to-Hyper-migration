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
$ErrorActionPreference = 'Stop'
$connection = $null
$cred = Get-Credential -Message "vCenter read-only service account"

if (-not (Test-Path $OutputPath)) {
    New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null
}

$timestamp = (Get-Date -Format 'yyyyMMdd-HHmmss') + '-' + [guid]::NewGuid().ToString('N')

try {
    $connection = Connect-VIServer -Server $vCenterServer -Credential $cred -NotDefault -ErrorAction Stop

    Write-Host "Connected to $vCenterServer. Gathering VM inventory..." -ForegroundColor Cyan

    $vmReport = Get-VM -Server $connection -ErrorAction Stop | Select-Object `
        Name,
        PowerState,
        @{N = 'NumCpu'; E = { $_.NumCpu } },
        @{N = 'MemoryGB'; E = { [math]::Round($_.MemoryGB, 1) } },
        @{N = 'ProvisionedGB'; E = { [math]::Round($_.ProvisionedSpaceGB, 1) } },
        @{N = 'UsedGB'; E = { [math]::Round($_.UsedSpaceGB, 1) } },
        @{N = 'Cluster'; E = { (Get-Cluster -VM $_ -Server $connection -ErrorAction Stop).Name } },
        @{N = 'ESXiHost'; E = { $_.VMHost.Name } },
        @{N = 'GuestOS'; E = { $_.Guest.OSFullName } },
        @{N = 'IPAddress'; E = { ($_.Guest.IPAddress -join ';') } },
        @{N = 'Folder'; E = { $_.Folder.Name } },
        @{N = 'MigrationWave'; E = { '' } },
        @{N = 'Notes'; E = { '' } }

    $csvPath = Join-Path $OutputPath "vm-inventory-$timestamp.csv"
    $vmReport | Export-Csv -LiteralPath $csvPath -NoTypeInformation -NoClobber -ErrorAction Stop
    Write-Host "VM inventory CSV: $csvPath" -ForegroundColor Green

    Write-Host "Gathering cluster/host capacity..." -ForegroundColor Cyan
    $clusterReport = @(foreach ($cluster in @(Get-Cluster -Server $connection -ErrorAction Stop)) {
        $hosts = @(Get-VMHost -Location $cluster -Server $connection -ErrorAction Stop)
        [pscustomobject]@{
            Name = $cluster.Name
            NumHosts = $hosts.Count
            TotalCpuGhz = [math]::Round((($hosts | Measure-Object CpuTotalMhz -Sum).Sum / 1000),1)
            TotalMemoryGB = [math]::Round(($hosts | Measure-Object MemoryTotalGB -Sum).Sum,1)
            HAEnabled = $cluster.HAEnabled
            DrsEnabled = $cluster.DrsEnabled
        }
    })

    $clusterCsvPath = Join-Path $OutputPath "cluster-capacity-$timestamp.csv"
    $clusterReport | Export-Csv -LiteralPath $clusterCsvPath -NoTypeInformation -NoClobber -ErrorAction Stop
    Write-Host "Cluster capacity CSV: $clusterCsvPath" -ForegroundColor Green

    # Selected planning fields only; not a full-fidelity vSphere export.
    $jsonPath = Join-Path $OutputPath "vm-inventory-$timestamp.json"
    ConvertTo-Json -InputObject @($vmReport) -Depth 5 | Out-File -FilePath $jsonPath -Encoding utf8
    Write-Host "VM inventory JSON: $jsonPath" -ForegroundColor Green

    [IO.File]::WriteAllText((Join-Path $OutputPath "complete-$timestamp.txt"),'All selected collectors and report writes completed.')
    Write-Host "`nDiscovered $($vmReport.Count) VMs across $($clusterReport.Count) cluster(s)." -ForegroundColor Yellow
    Write-Host "Reminder: this captures config/capacity only, not IOPS history." -ForegroundColor Yellow
}
finally {
    if ($null -ne $connection) {
        Disconnect-VIServer -Server $connection -Confirm:$false -ErrorAction Stop
    }
}
