#requires -Version 5.1
[CmdletBinding()]
param(
    [ValidateSet('ThreeNet','Local')][string]$Mode='ThreeNet',
    [string]$ServerId,
    [ValidateSet('ipv4','ipv6','both')][string]$Family='both',
    [string]$WorkerUrl='https://cf-server-monitor.checkzhh.workers.dev',
    [string]$Target,
    [ValidateSet('TCP','ICMP','UDP')][string]$Protocol='TCP',
    [ValidateRange(1,65535)][int]$Port=80,
    [string]$OutputDirectory,
    [switch]$Publish,
    [switch]$Plan
)
$ErrorActionPreference='Stop'
# Canonical implementation is hosted by the monitor Worker. Pin its reviewed bytes.
$expected='7619ebb43e974b5746c0adadda4cfa0882120c0b5ee058e944d6184dd5f231e9'
$file=Join-Path $env:TEMP ('cf-route-core-'+[guid]::NewGuid().ToString('N')+'.ps1')
try {
    Invoke-WebRequest -UseBasicParsing -Uri 'https://cf-server-monitor.checkzhh.workers.dev/files/cf-route-out.ps1?v=7619ebb43e97' -OutFile $file
    if((Get-FileHash -LiteralPath $file -Algorithm SHA256).Hash.ToLowerInvariant() -ne $expected) { throw 'Script checksum mismatch. Download the current GitHub entry again; do not bypass verification.' }
    & $file @PSBoundParameters
} finally {
    Remove-Item -LiteralPath $file -Force -ErrorAction SilentlyContinue
}
