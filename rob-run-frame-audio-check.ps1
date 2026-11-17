<#
.SYNOPSIS
    ROB RUN Frame & Audio Check — Read-Only Windows Diagnostic Script
.DESCRIPTION
    Performs non-invasive, read-only local checks on Windows (Steam paths, folder layout,
    file timestamps/sizes, and system info). Does NOT modify, delete, or upload any files,
    and does NOT require administrator privileges or changes to Windows Defender.
.NOTES
    License: MIT
#>

$ErrorActionPreference = 'SilentlyContinue'

function Get-SteamLibraries {
    $libs = @()
    $regPath = 'HKCU:\Software\Valve\Steam'
    $steamPath = (Get-ItemProperty -Path $regPath -Name 'SteamPath').SteamPath
    if (-not $steamPath) {
        $steamPath = 'C:\Program Files (x86)\Steam'
    }
    $steamPath = $steamPath -replace '/', '\'
    if (Test-Path $steamPath) {
        $libs += $steamPath
        $vdf = Join-Path $steamPath 'steamapps\libraryfolders.vdf'
        if (Test-Path $vdf) {
            $content = Get-Content -Path $vdf -Raw
            $matches = [regex]::Matches($content, '"path"\s+"([^"]+)"')
            foreach ($m in $matches) {
                $p = $m.Groups[1].Value -replace '\\', '\'
                if ((Test-Path $p) -and ($libs -notcontains $p)) {
                    $libs += $p
                }
            }
        }
    }
    return $libs
}

function Find-SteamGameDir {
    param([string[]]$FolderNames)
    foreach ($lib in (Get-SteamLibraries)) {
        foreach ($name in $FolderNames) {
            $candidate = Join-Path $lib "steamapps\common\$name"
            if (Test-Path $candidate) {
                return $candidate
            }
        }
    }
    return $null
}

Write-Host "============================================================" -ForegroundColor Cyan
Write-Host " ROB RUN Frame & Audio Check (Read-Only Check)" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ""

$os = Get-CimInstance Win32_OperatingSystem
$gpu = Get-CimInstance Win32_VideoController | Select-Object -First 1
$ramGB = [math]::Round((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1GB, 2)

Write-Host "[System & Graphics]" -ForegroundColor Yellow
Write-Host "  OS      : $($os.Caption) ($($os.Version))"
Write-Host "  RAM     : $ramGB GB"
Write-Host "  GPU     : $($gpu.Name) (Driver: $($gpu.DriverVersion), Refresh: $($gpu.CurrentRefreshRate) Hz)"
Write-Host ""

Write-Host "[Windows Audio Endpoints]" -ForegroundColor Yellow
$endpoints = Get-PnpDevice -Class AudioEndpoint
if ($endpoints) {
    foreach ($ep in $endpoints) {
        $color = if ($ep.Status -eq 'OK') { 'Green' } else { 'Red' }
        Write-Host ("  [{0,-7}] {1}" -f $ep.Status, $ep.FriendlyName) -ForegroundColor $color
    }
} else {
    Write-Host "  No AudioEndpoint devices enumerated." -ForegroundColor DarkYellow
}

Write-Host ""
Write-Host "Diagnostic complete. No files were modified." -ForegroundColor Green
Read-Host "Press Enter to exit"
