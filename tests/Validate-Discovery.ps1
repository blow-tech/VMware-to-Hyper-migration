$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
function Assert($ok,$msg){if(-not $ok){throw $msg}}
Get-ChildItem (Join-Path $root scripts) -Filter *.ps1 | ForEach-Object {
 $e=$null;$t=$null;$null=[Management.Automation.Language.Parser]::ParseFile($_.FullName,[ref]$t,[ref]$e)
 Assert (-not $e.Count) ($e | Out-String)
}
$global:FixtureConnection=[pscustomobject]@{Name='mock-vcenter';Token='owned'}
$global:FixtureDisconnects=0;$global:FixtureFailConnect=$false
function Get-Credential { [pscredential]::new('fixture',(ConvertTo-SecureString 'FixtureOnly!' -AsPlainText -Force)) }
function Connect-VIServer {param($Server,$Credential,[switch]$NotDefault) Assert $NotDefault 'Connection must not become default';if($global:FixtureFailConnect){throw 'Denied fixture'};$global:FixtureConnection}
function Disconnect-VIServer {param($Server,$Confirm) Assert ($Server.Token -eq 'owned') 'Disconnect only owned connection';$global:FixtureDisconnects++}
function Check-Scope($Server){Assert ($Server.Token -eq 'owned') 'Every query must use owned connection'}
function Get-VM {param($Server) Check-Scope $Server;[pscustomobject]@{Name='fixture';NumCpu=2;MemoryGB=4;ProvisionedSpaceGB=20;UsedSpaceGB=10;VMHost=@{Name='esx'};Guest=@{OSFullName='fixture';IPAddress=@('192.0.2.1')};Folder=@{Name='fixture'};PowerState='PoweredOff'}}
function Get-Cluster {param($Server,$VM) Check-Scope $Server;[pscustomobject]@{Name='fixture-cluster';HAEnabled=$true;DrsEnabled=$false}}
function Get-VMHost {param($Server,$Location) Check-Scope $Server;[pscustomobject]@{Name='fixture-host';CpuTotalMhz=4000;MemoryTotalGB=8}}
function Get-VMHostHba {param($Server,$VMHost,$Type) Check-Scope $Server;[pscustomobject]@{Device='vmhba0';NodeWorldWideName=[uint64]1;PortWorldWideName=[uint64]2;Status='online'}}
$temp=Join-Path ([IO.Path]::GetTempPath()) ('vmware-fixture-'+[guid]::NewGuid().ToString('N'))
$null=New-Item -ItemType Directory $temp
try {
 & (Join-Path $root scripts/Export-VMwareInventory.ps1) -vCenterServer fixture -OutputPath $temp
 Assert (@(Get-ChildItem $temp -Filter complete-*.txt).Count -eq 1) 'Successful complete marker expected'
 $json=Get-Content (Get-ChildItem $temp -Filter vm-inventory-*.json).FullName -Raw
 Assert ($json.Trim().StartsWith('[')) 'One VM must remain a JSON array'
 & (Join-Path $root scripts/Export-FC-HBA-Info.ps1) -vCenterServer fixture -OutputPath $temp
 $row=Import-Csv (Get-ChildItem $temp -Filter esxi-*.csv).FullName
 Assert ($row.PortWWN -eq '0000000000000002') 'WWPN must retain leading zeros'
 Assert ($global:FixtureDisconnects -eq 2) 'Each successful connection cleaned once'
 $global:FixtureFailConnect=$true
 $failed=$false;try {& (Join-Path $root scripts/Export-VMwareInventory.ps1) -vCenterServer fixture -OutputPath $temp}catch{$failed=$true}
 Assert ($failed -and $global:FixtureDisconnects -eq 2) 'Failed connect must not disconnect another session'
 Write-Output 'PASS parser, connection scope, failed-connect cleanup, JSON array and WWPN fixtures.'
} finally {Remove-Item -LiteralPath $temp -Recurse -Force}
