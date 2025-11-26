# Client Information Report Script

A PowerShell script for retrieving detailed Windows 11 device information from Microsoft Intune, including OS versions, build numbers, KB updates, and hardware details.

## 🎯 Features

- **Multiple Input Methods**: 
  - CSV file with computer names
  - Manual input (single or multiple clients)
  - Azure AD Group members
- **Detailed Build Information**: 
  - OS Version and Feature Update (22H2, 23H2, 24H2, 25H2)
  - Exact Build Release Date
  - KB Article Number
  - Update Type (Patch Tuesday, Preview, OOB, etc.)
- **Hardware Information**: Serial number, manufacturer, model
- **Last Check-in Time**: Shows when devices last synced with Intune
- **CSV Export**: Automatic export with timestamp
- **Comprehensive Build Database**: Includes Windows 11 builds from 2022-2025

## 📋 Prerequisites

- **PowerShell 7.0+** recommended
- **Microsoft Graph PowerShell SDK**:
  ```powershell
  Install-Module Microsoft.Graph -Scope CurrentUser
  ```
- **Required Permissions**:
  - `DeviceManagementConfiguration.Read.All`
  - `DeviceManagementManagedDevices.Read.All`

## 🚀 Usage

### 1. Run the Script

```powershell
.\OSVersionReport.ps1
```

### 2. Choose Input Method

When prompted, select one of three options:

**Option 1: CSV File**
- Place computer names in `Clients.csv` (see example below)
- Script automatically reads the file

**Option 2: Manual Input**
- Enter computer names when prompted
- Single: `PC-001`
- Multiple: `PC-001, PC-002, PC-003`

**Option 3: Azure AD Group**
- Enter the group name or Object ID
- Script retrieves all devices in the group

### 3. View Results

- Console output shows progress for each device
- Final report displays in table format
- CSV export saved with timestamp: `ClientReport_YYYYMMDD_HHMMSS.csv`

## 📁 File Structure

```
Reports/
├── OSVersionReport.ps1          # Main script
├── windows11_builds_full.csv    # Build database (DO NOT MODIFY)
├── Clients.csv                  # Input file for Option 1
└── ClientReport_*.csv           # Generated reports
```

## 📝 Input File Format

Create `Clients.csv` with the following format:

```csv
ComputerName
PC-001
PC-002
LAPTOP-003
DESKTOP-004
```

## 📊 Output Columns

| Column | Description |
|--------|-------------|
| ComputerName | Device name from Intune |
| SerialNumber | Hardware serial number |
| LastCheckIn | Last Intune sync date/time |
| OSVersion | Full OS version (e.g., 10.0.26100.7171) |
| FeatureUpdateVersion | Windows 11 version (22H2, 23H2, 24H2, 25H2) |
| BuildReleaseDate | Official Microsoft release date |
| KBNumber | KB article number (e.g., KB5068861) |
| UpdateType | Type of update (Patch Tuesday, Preview, OOB, etc.) |
| LastPatchInstalled | Last sync date (proxy for patch installation) |
| OperatingSystem | OS name |
| Model | Device model |
| Manufacturer | Device manufacturer |

## 🔧 Configuration

### Modify CSV Path (Option 1)
Edit line in script if using custom path:
```powershell
$csvPath = ".\Clients.csv"  # Change path here
```

### Update Build Database
The `windows11_builds_full.csv` contains all Windows 11 builds from 2022-2025. To add new builds:

```csv
Version;Build;Release-Datum;KB;Hinweis
24H2;26100.7500;2025-12-10;KB5070000;December Update
```

**Format**: Semicolon-delimited
- **Version**: 22H2, 23H2, 24H2, 25H2
- **Build**: Full build number (e.g., 26100.7500)
- **Release-Datum**: Date in YYYY-MM-DD format
- **KB**: KB article number or "—" for releases
- **Hinweis**: Update type description

## 🐛 Troubleshooting

### "Build not in database"
- Check console output for missing build number
- Add missing build to `windows11_builds_full.csv`
- Restart PowerShell session to reload database

### Authentication Issues
```powershell
# Disconnect and reconnect
Disconnect-MgGraph
Connect-MgGraph -Scopes "DeviceManagementConfiguration.Read.All","DeviceManagementManagedDevices.Read.All"
```

### Group Not Found (Option 3)
- Verify group name spelling
- Try using the Object ID instead
- Ensure you have permissions to read the group

### No Devices Found
- Check device names match Intune exactly
- Verify devices are enrolled in Intune
- Ensure devices are not retired/deleted

## 📚 Examples

### Example 1: Quick Check for Single Device
```powershell
.\OSVersionReport.ps1
# Choose Option 2: Manual Input
# Enter: PC-001
```

### Example 2: Bulk Report from CSV
```powershell
.\OSVersionReport.ps1
# Choose Option 1: CSV File
# Ensure Clients.csv is populated
```

### Example 3: Department Devices
```powershell
.\OSVersionReport.ps1
# Choose Option 3: Azure AD Group
# Enter: IT-Department-Devices
```

## 📅 Build Database Coverage

- **Windows 11 22H2**: 78 builds (Sep 2022 - Oct 2025)
- **Windows 11 23H2**: 60 builds (Oct 2023 - Nov 2025)
- **Windows 11 24H2**: 26 builds (Oct 2024 - Nov 2025)
- **Windows 11 25H2**: 4 builds (Jun 2025 - Nov 2025)

Total: **168 builds** covering all major and preview updates

## 🔐 Security Notes

- Script requires read-only permissions
- No data is modified in Intune
- Exports contain sensitive information (serial numbers, device names)
- Store reports securely and follow your organization's data handling policies

## 📄 License

This script is provided as-is for internal use. Modify as needed for your environment.

## 🤝 Contributing

To add missing builds or improvements:
1. Test changes thoroughly
2. Update build database with official Microsoft sources
3. Document changes in this README

## 📞 Support

For issues with:
- **Script functionality**: Check troubleshooting section above
- **Missing builds**: Verify against [Microsoft Update History](https://support.microsoft.com/en-us/topic/windows-11-update-history)
- **Graph API**: See [Microsoft Graph Documentation](https://learn.microsoft.com/en-us/graph/)

---

**Last Updated**: November 2025  
**Version**: 1.0  
**Compatibility**: Windows 11 (22H2, 23H2, 24H2, 25H2)
