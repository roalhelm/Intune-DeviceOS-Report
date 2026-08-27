<#
.SYNOPSIS
    Updates windows11_builds_full.csv with the latest Windows 11 build entries.

.DESCRIPTION
    Reads official Microsoft Windows 11 update history pages for supported versions,
    extracts KB/build/date entries, merges them into the local build database, and
    writes the updated CSV file.

    Features:
    - Supports WhatIf mode (dry run)
    - Creates a timestamped backup before writing
    - Avoids duplicate rows (key: Version + Build)

.PARAMETER CsvPath
    Path to windows11_builds_full.csv. Defaults to the file next to this script.

.PARAMETER NoBackup
    Skip creating a backup file before writing changes.

.EXAMPLE
    .\Update-Windows11Builds.ps1 -WhatIf

    Shows what would be updated without modifying the CSV.

.EXAMPLE
    .\Update-Windows11Builds.ps1

    Updates the CSV file in place and creates a backup.
#>

[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter()]
    [string]$CsvPath = (Join-Path $PSScriptRoot 'windows11_builds_full.csv'),

    [Parameter()]
    [switch]$NoBackup
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ($PSVersionTable.PSVersion.Major -lt 7) {
    Write-Warning "This updater runs best on PowerShell 7+. Current version: $($PSVersionTable.PSVersion)"
}

if (-not (Test-Path -Path $CsvPath)) {
    throw "CSV file not found: $CsvPath"
}

$versionSources = @(
    @{ Version = '22H2'; Url = 'https://support.microsoft.com/en-US/servicing/os/windows-11/2022/09/windows-11-version-22h2-update-history'; BuildPrefix = '22621.' }
    @{ Version = '23H2'; Url = 'https://support.microsoft.com/en-US/servicing/os/windows-11/2023/09/windows-11-version-23h2-update-history'; BuildPrefix = '22631.' }
    @{ Version = '24H2'; Url = 'https://support.microsoft.com/en-US/servicing/os/windows-11/2024/09/windows-11-version-24h2-update-history'; BuildPrefix = '26100.' }
    @{ Version = '25H2'; Url = 'https://support.microsoft.com/en-US/servicing/os/windows-11/2025/07/windows-11-version-25h2-update-history'; BuildPrefix = '26200.' }
    @{ Version = '26H1'; Url = 'https://support.microsoft.com/en-US/servicing/os/windows-11/2026/02/windows-11-version-26h1-update-history'; BuildPrefix = '28000.' }
)

function Get-UpdateHint {
    param(
        [Parameter(Mandatory = $true)]
        [datetime]$Date,

        [Parameter(Mandatory = $true)]
        [string]$SourceText
    )

    $monthName = [System.Globalization.CultureInfo]::InvariantCulture.DateTimeFormat.GetMonthName($Date.Month)
    $year = $Date.Year

    if ($SourceText -match '(?i)out-of-band|\bOOB\b') {
        return "$monthName $year OOB Update"
    }
    if ($SourceText -match '(?i)preview') {
        return "$monthName $year Preview"
    }
    if ($SourceText -match '(?i)hotpatch') {
        return "$monthName $year Hotpatch"
    }

    return "$monthName $year Update"
}

function ConvertTo-BuildParts {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Build
    )

    $parts = $Build -split '\.'
    $major = 0
    $minor = 0

    if ($parts.Count -ge 1) {
        [void][int]::TryParse($parts[0], [ref]$major)
    }
    if ($parts.Count -ge 2) {
        [void][int]::TryParse($parts[1], [ref]$minor)
    }

    return @{ Major = $major; Minor = $minor }
}

function Get-UpdatesFromSource {
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Source
    )

    Write-Host "Reading $($Source.Version) from $($Source.Url)" -ForegroundColor Cyan
    $response = Invoke-WebRequest -Uri $Source.Url
    $content = $response.Content

    $pattern = '(?<date>[A-Za-z]+\s+\d{1,2},\s+\d{4})\s*—\s*(?<kb>KB\d+)\s*\(OS Build(?:s)?\s+(?<builds>[0-9\.\s,and]+)\)\s*(?<suffix>[^<\r\n]*)'
    $matches = [regex]::Matches($content, $pattern, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)

    $results = @()
    foreach ($match in $matches) {
        $dateText = $match.Groups['date'].Value.Trim()
        $kb = $match.Groups['kb'].Value.Trim()
        $buildListRaw = $match.Groups['builds'].Value
        $suffix = $match.Groups['suffix'].Value.Trim()

        $date = [datetime]::ParseExact(
            $dateText,
            'MMMM d, yyyy',
            [System.Globalization.CultureInfo]::InvariantCulture
        )

        $buildCandidates = @($buildListRaw -split '(?i)\sand\s|,') |
            ForEach-Object { $_.Trim() } |
            Where-Object { $_ -match '^\d+\.\d+$' }

        $build = $buildCandidates | Where-Object { $_ -like "$($Source.BuildPrefix)*" } | Select-Object -First 1
        if (-not $build) {
            continue
        }

        $sourceText = "$dateText - $kb - $suffix"
        $hint = Get-UpdateHint -Date $date -SourceText $sourceText

        $results += [PSCustomObject]@{
            Version = $Source.Version
            Build = $build
            'Release-Datum' = $date.ToString('yyyy-MM-dd')
            KB = $kb
            Hinweis = $hint
        }
    }

    # Remove duplicates from the source page itself.
    return $results |
        Sort-Object Version, Build, 'Release-Datum' -Descending |
        Group-Object Version, Build |
        ForEach-Object { $_.Group[0] }
}

$existing = Import-Csv -Path $CsvPath -Delimiter ';'
$merged = @{}

foreach ($row in $existing) {
    $key = "{0}|{1}" -f $row.Version.Trim(), $row.Build.Trim()
    $merged[$key] = [PSCustomObject]@{
        Version = $row.Version.Trim()
        Build = $row.Build.Trim()
        'Release-Datum' = $row.'Release-Datum'.Trim()
        KB = $row.KB.Trim()
        Hinweis = $row.Hinweis.Trim()
    }
}

$discovered = @()
foreach ($source in $versionSources) {
    $discovered += Get-UpdatesFromSource -Source $source
}

$added = 0
$updated = 0
foreach ($row in $discovered) {
    $key = "{0}|{1}" -f $row.Version, $row.Build
    if (-not $merged.ContainsKey($key)) {
        $merged[$key] = $row
        $added++
        continue
    }

    $current = $merged[$key]
    $wasChanged = $false

    # Keep existing values by default; only fill obvious gaps.
    if ([string]::IsNullOrWhiteSpace($current.'Release-Datum') -and -not [string]::IsNullOrWhiteSpace($row.'Release-Datum')) {
        $current.'Release-Datum' = $row.'Release-Datum'
        $wasChanged = $true
    }

    if (
        ([string]::IsNullOrWhiteSpace($current.KB) -or $current.KB -eq '—' -or $current.KB -eq 'Unknown') -and
        -not [string]::IsNullOrWhiteSpace($row.KB)
    ) {
        $current.KB = $row.KB
        $wasChanged = $true
    }

    if (
        ([string]::IsNullOrWhiteSpace($current.Hinweis) -or $current.Hinweis -eq 'Unknown') -and
        -not [string]::IsNullOrWhiteSpace($row.Hinweis)
    ) {
        $current.Hinweis = $row.Hinweis
        $wasChanged = $true
    }

    if ($wasChanged) {
        $merged[$key] = $current
        $updated++
    }
}

$versionOrder = @{
    '21H2' = 1
    '22H2' = 2
    '23H2' = 3
    '24H2' = 4
    '25H2' = 5
    '26H1' = 6
}

$sorted = $merged.Values |
    Sort-Object `
        @{ Expression = { if ($versionOrder.ContainsKey($_.Version)) { $versionOrder[$_.Version] } else { 999 } } },
        @{ Expression = { ([datetime]::ParseExact($_.'Release-Datum', 'yyyy-MM-dd', [System.Globalization.CultureInfo]::InvariantCulture)) } },
        @{ Expression = {
            $bp = ConvertTo-BuildParts -Build $_.Build
            $bp.Major
        } },
        @{ Expression = {
            $bp = ConvertTo-BuildParts -Build $_.Build
            $bp.Minor
        } }

$totalBefore = $existing.Count
$totalAfter = $sorted.Count

Write-Host "Existing entries: $totalBefore" -ForegroundColor Gray
Write-Host "Discovered entries: $($discovered.Count)" -ForegroundColor Gray
Write-Host "Added: $added, Updated: $updated" -ForegroundColor Green
Write-Host "Total after merge: $totalAfter" -ForegroundColor Green

if ($added -eq 0 -and $updated -eq 0) {
    Write-Host "No changes required." -ForegroundColor Yellow
    return
}

if ($PSCmdlet.ShouldProcess($CsvPath, 'Update Windows 11 build database CSV')) {
    if (-not $NoBackup) {
        $backupPath = "{0}.{1}.bak" -f $CsvPath, (Get-Date -Format 'yyyyMMdd_HHmmss')
        Copy-Item -Path $CsvPath -Destination $backupPath -Force
        Write-Host "Backup created: $backupPath" -ForegroundColor DarkGray
    }

    $sorted | Export-Csv -Path $CsvPath -Delimiter ';' -NoTypeInformation -Encoding UTF8
    Write-Host "Updated: $CsvPath" -ForegroundColor Green
}