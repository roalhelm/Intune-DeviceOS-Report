<#
.SYNOPSIS
    Retrieves detailed Windows 11 device information from Microsoft Intune including OS versions, 
    build numbers, KB updates, and hardware details.
    GitHub Repository: https://github.com/roalhelm/

.DESCRIPTION
    This script provides three methods to query device information from Microsoft Intune:
    1. CSV File - Read computer names from a CSV file
    2. Manual Input - Enter single or multiple computer names directly
    3. Azure AD Group - Retrieve all devices from an Azure AD group
    
    The script queries Microsoft Intune for each device and retrieves:
    - Serial Number
    - Primary User UPN (User Principal Name)
    - Last Check-in Time
    - OS Version and Feature Update Version (22H2, 23H2, 24H2, 25H2)
    - Build Release Date
    - KB Article Number
    - Update Type (Patch Tuesday, Preview Update, OOB, etc.)
    - Hardware Information (Manufacturer, Model)
    - Free Disk Space (in GB)
    
    Results are displayed in the console and automatically exported to a timestamped CSV file.
    The script uses a comprehensive build database (windows11_builds_full.csv) containing 
    168+ Windows 11 builds from 2022-2025.

.PARAMETER None
    This script does not accept parameters. All inputs are provided interactively.

.NOTES
    File Name      : OSVersionReport.ps1
    Author         : Ronny Alhelm
    Version        : 1.1
    Creation Date  : 2025-11-25
    Last Modified  : 2025-12-05
    Requirements   : PowerShell 7.0 or higher (PowerShell 5.1 minimum)
    Dependencies   : Microsoft.Graph PowerShell Module
    Required Files : windows11_builds_full.csv (build database)
                     Clients.csv (optional, for CSV input method)

.CHANGES
    Version 1.1 (2025-12-05):
    - Added Primary User UPN (UserPrincipalName) to report output
    - Added Free Disk Space in GB (FreeDiscSpaceGB) to report output
    - Enhanced device information with storage and user details
    
    Version 1.0 (2025-11-26):
    - Initial release with CSV, Manual, and AAD Group input methods
    - Windows 11 build database with 168+ builds
    - Feature update version detection (22H2, 23H2, 24H2, 25H2)
    - KB article and update type information

.PREREQUISITES
    1. Install Microsoft Graph PowerShell Module:
       Install-Module Microsoft.Graph -Scope CurrentUser
    
    2. Required Microsoft Graph Permissions:
       - DeviceManagementConfiguration.Read.All
       - DeviceManagementManagedDevices.Read.All
    
    3. Ensure windows11_builds_full.csv is in the same directory as the script

.AUTHOR
    Ronny Alhelm with assistance from GitHub Copilot (Claude Sonnet 4.5)

.VERSION
    1.1 - Added Primary User UPN and Free Disk Space fields

.EXAMPLE
    PS C:\> .\OSVersionReport.ps1
    
    Runs the script and prompts for input method selection.
    Choose option 1 to read from Clients.csv, option 2 for manual entry,
    or option 3 to query an Azure AD group.

.EXAMPLE
    Manual Input Example:
    Select input method: 2
    Enter computer names: PC-001, PC-002, LAPTOP-003
    
    The script will query Intune for these three devices and generate a report.

.EXAMPLE
    Azure AD Group Example:
    Select input method: 3
    Enter Azure AD Group Name: Windows 11 Devices
    
    The script will retrieve all devices from the specified group and generate a report.

.OUTPUTS
    CSV File: ClientReport_YYYYMMDD_HHMMSS.csv
    Contains columns: ComputerName, SerialNumber, PrimaryUserUPN, LastCheckIn, 
    OSVersion, FeatureUpdateVersion, BuildReleaseDate, KBNumber, UpdateType, 
    LastPatchInstalled, OperatingSystem, Model, Manufacturer, FreeDiscSpaceGB

.LINK
    GitHub Repository: https://github.com/roalhelm/
    Microsoft Graph PowerShell: https://learn.microsoft.com/en-us/powershell/microsoftgraph/
    Windows 11 Update History: https://support.microsoft.com/en-us/topic/windows-11-update-history

#>

# Connect to Microsoft Graph
Connect-MgGraph

# User Selection: Choose Input Method
Write-Host "`n=== Client Information Report ===" -ForegroundColor Cyan
Write-Host "Select input method:" -ForegroundColor Yellow
Write-Host "1. CSV File"
Write-Host "2. Manual Input (Single or Multiple Clients)"
Write-Host "3. Azure AD Group"
Write-Host ""

$choice = Read-Host "Enter your choice (1-3)"

$clients = @()

switch ($choice) {
    "1" {
        # CSV File Input
        $csvPath = ".\Clients.csv"
        
        if (-not (Test-Path $csvPath)) {
            Write-Error "CSV file not found: $csvPath"
            exit
        }
        
        $clients = Import-Csv -Path $csvPath
        Write-Host "Loaded $($clients.Count) clients from CSV" -ForegroundColor Green
    }
    
    "2" {
        # Manual Input
        Write-Host "`nEnter computer names (comma-separated for multiple):" -ForegroundColor Yellow
        $input = Read-Host "Computer Name(s)"
        
        $computerNames = $input -split ',' | ForEach-Object { $_.Trim() }
        
        foreach ($name in $computerNames) {
            if ($name) {
                $clients += [PSCustomObject]@{ ComputerName = $name }
            }
        }
        
        Write-Host "Processing $($clients.Count) client(s)" -ForegroundColor Green
    }
    
    "3" {
        # Azure AD Group Input
        Write-Host "`nEnter Azure AD Group Name or Object ID:" -ForegroundColor Yellow
        $groupInput = Read-Host "Group Name/ID"
        
        try {
            # Try to find group by display name first
            $group = Get-MgGroup -Filter "displayName eq '$groupInput'" -ErrorAction SilentlyContinue
            
            # If not found, try by Object ID
            if (-not $group) {
                $group = Get-MgGroup -GroupId $groupInput -ErrorAction SilentlyContinue
            }
            
            if (-not $group) {
                Write-Error "Group '$groupInput' not found"
                exit
            }
            
            Write-Host "Found group: $($group.DisplayName)" -ForegroundColor Green
            Write-Host "Retrieving group members..." -ForegroundColor Cyan
            
            # Get group members
            $groupMembers = Get-MgGroupMember -GroupId $group.Id -All
            
            foreach ($member in $groupMembers) {
                # Get device details
                $device = Get-MgDevice -DeviceId $member.Id -ErrorAction SilentlyContinue
                
                if ($device -and $device.DisplayName) {
                    $clients += [PSCustomObject]@{ ComputerName = $device.DisplayName }
                }
            }
            
            Write-Host "Found $($clients.Count) devices in group" -ForegroundColor Green
        }
        catch {
            Write-Error "Error retrieving group members: $_"
            exit
        }
    }
    
    default {
        Write-Error "Invalid choice. Please select 1, 2, or 3."
        exit
    }
}

if ($clients.Count -eq 0) {
    Write-Error "No clients to process"
    exit
}

# Load Windows 11 Build Database
$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
if ([string]::IsNullOrEmpty($scriptPath)) {
    $scriptPath = Get-Location
}
$buildDatabasePath = Join-Path $scriptPath "windows11_builds_full.csv"
$buildDatabase = @{}

Write-Host "Script path: $scriptPath" -ForegroundColor Gray
Write-Host "Looking for database at: $buildDatabasePath" -ForegroundColor Gray

if (Test-Path $buildDatabasePath) {
    $buildData = Import-Csv -Path $buildDatabasePath -Delimiter ';'
    Write-Host "CSV Columns: $($buildData[0].PSObject.Properties.Name -join ', ')" -ForegroundColor Cyan
    
    foreach ($build in $buildData) {
        # Trim whitespace from build number
        $buildKey = $build.Build.Trim()
        $buildDatabase[$buildKey] = @{
            ReleaseDate = $build.'Release-Datum'
            KB = $build.KB
            Note = $build.Hinweis
        }
    }
    Write-Host "Loaded $($buildDatabase.Count) builds from database" -ForegroundColor Green
    
    # Show first few builds for debugging
    $firstBuilds = ($buildDatabase.Keys | Select-Object -First 5) -join ', '
    Write-Host "Sample builds in database: $firstBuilds" -ForegroundColor Gray
} else {
    Write-Warning "Build database not found at $buildDatabasePath - Release dates will not be available"
}

# Create array for the report
$report = @()

Write-Host "Starting query for $($clients.Count) clients..." -ForegroundColor Cyan

# Retrieve information for each client in the CSV
foreach ($client in $clients) {
    $clientName = $client.ComputerName  # Adjust the column name according to your CSV
    
    Write-Host "Processing: $clientName" -ForegroundColor Yellow
    
    try {
        # Search for client in Intune
        $device = Get-MgDeviceManagementManagedDevice -Filter "deviceName eq '$clientName'"
        
        if ($device) {
            # Extract information
            
            # Derive Feature Update Version and Build Release Date from OS Version
            $featureUpdate = "Unknown"
            $buildReleaseDate = "Unknown"
            if ($device.OSVersion) {
                # Convert from Intune format (10.0.26100.7171) to Build format (26100.7171)
                if ($device.OSVersion -match '10\.0\.(\d+)\.(\d+)') {
                    $osBuild = $matches[1]
                    $osRevision = $matches[2]
                } else {
                    # Fallback to split method
                    $parts = $device.OSVersion.Split('.')
                    if ($parts.Count -ge 4) {
                        $osBuild = $parts[2]
                        $osRevision = $parts[3]
                    } else {
                        $osBuild = $parts[0]
                        $osRevision = if ($parts.Count -gt 1) { $parts[1] } else { "0" }
                    }
                }
                
                # Feature Update Version
                switch ($osBuild) {
                    "22000" { $featureUpdate = "21H2" }
                    "22621" { $featureUpdate = "22H2" }
                    "22631" { $featureUpdate = "23H2" }
                    "26100" { $featureUpdate = "24H2" }
                    "26200" { $featureUpdate = "25H2" }
                    "19041" { $featureUpdate = "2004" }
                    "19042" { $featureUpdate = "20H2" }
                    "19043" { $featureUpdate = "21H1" }
                    "19044" { $featureUpdate = "21H2" }
                    "19045" { $featureUpdate = "22H2" }
                    default { $featureUpdate = "Build $osBuild" }
                }
                
                # Look up Build Release Date from database
                $fullBuild = "$osBuild.$osRevision"
                $kbNumber = "Unknown"
                $updateType = "Unknown"
                
                Write-Host "  Searching for build: '$fullBuild' in database..." -ForegroundColor Gray
                
                # Trim whitespace for lookup
                $lookupKey = $fullBuild.Trim()
                
                if ($buildDatabase.ContainsKey($lookupKey)) {
                    $buildReleaseDate = $buildDatabase[$lookupKey].ReleaseDate
                    $kbNumber = $buildDatabase[$lookupKey].KB
                    $updateType = $buildDatabase[$lookupKey].Note
                    Write-Host "  ✓ Found build $lookupKey in database" -ForegroundColor Green
                } else {
                    $buildReleaseDate = "Build not in database"
                    Write-Host "  ! Build '$lookupKey' not found in database (DB has $($buildDatabase.Count) entries)" -ForegroundColor Yellow
                    
                    # Show similar builds for debugging
                    $similarBuilds = $buildDatabase.Keys | Where-Object { $_ -like "$osBuild.*" } | Select-Object -First 3
                    if ($similarBuilds) {
                        Write-Host "  Similar builds found: $($similarBuilds -join ', ')" -ForegroundColor Gray
                    }
                }
            }
            
            # Calculate free disk space in GB
            $freeSpaceGB = "Unknown"
            if ($device.FreeStorageSpaceInBytes) {
                $freeSpaceGB = [math]::Round($device.FreeStorageSpaceInBytes / 1GB, 2)
            }
            
            # Get Primary User UPN
            $primaryUserUPN = "Unknown"
            if ($device.UserPrincipalName) {
                $primaryUserUPN = $device.UserPrincipalName
            }
            
            $deviceInfo = [PSCustomObject]@{
                ComputerName           = $device.DeviceName
                SerialNumber           = $device.SerialNumber
                PrimaryUserUPN         = $primaryUserUPN
                LastCheckIn            = $device.LastSyncDateTime
                OSVersion              = $device.OSVersion
                FeatureUpdateVersion   = $featureUpdate
                BuildReleaseDate       = $buildReleaseDate
                KBNumber               = $kbNumber
                UpdateType             = $updateType
                LastPatchInstalled     = $device.LastSyncDateTime
                OperatingSystem        = $device.OperatingSystem
                Model                  = $device.Model
                Manufacturer           = $device.Manufacturer
                FreeDiscSpaceGB        = $freeSpaceGB
            }
            
            $report += $deviceInfo
            
            Write-Host "  ✓ Successfully retrieved" -ForegroundColor Green
        }
        else {
            Write-Warning "  ✗ Client '$clientName' not found in Intune"
            
            # Include clients not found in the report
            $deviceInfo = [PSCustomObject]@{
                ComputerName           = $clientName
                SerialNumber           = "Not found"
                PrimaryUserUPN         = "Not found"
                LastCheckIn            = $null
                OSVersion              = "Not found"
                FeatureUpdateVersion   = "Not found"
                BuildReleaseDate       = "Not found"
                KBNumber               = "Not found"
                UpdateType             = "Not found"
                LastPatchInstalled     = $null
                OperatingSystem        = "Not found"
                Model                  = "Not found"
                Manufacturer           = "Not found"
                FreeDiscSpaceGB        = "Not found"
            }
            
            $report += $deviceInfo
        }
    }
    catch {
        Write-Error "  ✗ Error for '$clientName': $_"
    }
}

# Display report
Write-Host "`n=== REPORT ===" -ForegroundColor Cyan
$report | Format-Table -AutoSize

# Export report as CSV
$outputPath = ".\ClientReport_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv"
$report | Export-Csv -Path $outputPath -NoTypeInformation -Encoding UTF8

Write-Host "`nReport saved to: $outputPath" -ForegroundColor Green

# Disconnect
Disconnect-MgGraph