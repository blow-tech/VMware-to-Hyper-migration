<#
.SYNOPSIS
    Exports FC HBA WWPNs from current ESXi hosts, as reference for zoning
    the new Hyper-V hosts consistently with existing naming/patterns.

.DESCRIPTION
    Read-only. Does not touch SAN zoning or LUN masking. Existing ESXi WWPNs
    are reference data only -- the new Hyper-V hosts have their own HBAs and
    WWPNs, which must be pulled separately once hardware is racked
    (Get-InitiatorPort on Windows, or your HBA vendor's tool).

.EXAMPLE
    ./Export-FC-HBA-Info.ps1 -vCenterServer vcenter.example.local
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$vCenterServer,

    [Parameter(Mandatory = $false)]
    [string]$OutputPath = "./reports"
)

$ErrorActionPreference = 'Stop'
$connection = $null
$cred = Get-Credential -Message "vCenter read-only service account"

if (-not (Test-Path $OutputPath)) {
    New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null
}

$timestamp = (Get-Date -Format 'yyyyMMdd-HHmmss') + '-' + [guid]::NewGuid().ToString('N')

try {
    $connection = Connect-VIServer -Server $vCenterServer -Credential $cred -NotDefault -ErrorAction Stop

    $hbaReport = Get-VMHost -Server $connection -ErrorAction Stop | ForEach-Object {
        $vmhost = $_
        Get-VMHostHba -VMHost $vmhost -Server $connection -Type FibreChannel -ErrorAction Stop | Select-Object `
            @{N = 'ESXiHost'; E = { $vmhost.Name } },
            Device,
            @{N = 'NodeWWN'; E = { "{0:X16}" -f $_.NodeWorldWideName } },
            @{N = 'PortWWN'; E = { "{0:X16}" -f $_.PortWorldWideName } },
            Status
    }

    $csvPath = Join-Path $OutputPath "esxi-fc-hba-reference-$timestamp.csv"
    $hbaReport | Export-Csv -LiteralPath $csvPath -NoTypeInformation -NoClobber -ErrorAction Stop
    Write-Host "ESXi FC HBA reference export: $csvPath" -ForegroundColor Green
    Write-Host "Reminder: this is the OLD environment's WWPNs, for naming/pattern reference only." -ForegroundColor Yellow
    Write-Host "New Hyper-V host WWPNs must be pulled separately once HBAs are racked." -ForegroundColor Yellow
}
finally {
    if ($null -ne $connection) {
        Disconnect-VIServer -Server $connection -Confirm:$false -ErrorAction Stop
    }
}
