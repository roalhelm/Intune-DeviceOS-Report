# Intune Device OS Report - Action Recommendations

## Overview

This document explains the various action recommendations in the `RecommendedAction` column of the Device OS Report and describes which actions are recommended based on status combinations.

---

## Report Columns

### Status Columns

| Column | Description |
|--------|-------------|
| **IntuneStatus** | Management status in Microsoft Intune (Active, Retired, Wiped, etc.) |
| **EntraIDStatus** | Device status in Microsoft Entra ID (Enabled, Disabled, No Entra ID Link, etc.) |
| **DaysSinceLastCheckIn** | Number of days since the device last checked in to Intune |

---

## Action Recommendations (RecommendedAction)

### Active Devices

#### **Keep Active**
- **Meaning:** Device is active and should continue to be managed
- **Conditions:**
  - IntuneStatus: `Active`
  - EntraIDStatus: `Enabled`
  - Last check-in: < 30 days
- **Action:** No action required

---

### Monitoring Required

#### **Watch (>30 days inactive)**
- **Meaning:** Device has been inactive for over 30 days
- **Conditions:**
  - Last check-in: 30-60 days
- **Action:** Monitor device, contact user if necessary

#### **Monitor (>60 days inactive)**
- **Meaning:** Device has been inactive for over 60 days
- **Conditions:**
  - Last check-in: 60-90 days
- **Action:** Monitor closely, consider deactivation

#### **Consider Disabling (>90 days inactive)**
- **Meaning:** Device has not been active for over 90 days
- **Conditions:**
  - IntuneStatus: `Active`
  - EntraIDStatus: `Enabled`
  - Last check-in: > 90 days
- **Action:** Deactivation strongly recommended, clarify with IT/user

---

### Cleanup Required

#### **Disable in Entra ID**
- **Meaning:** Device has already been retired/wiped in Intune, but is still active in Entra ID
- **Conditions:**
  - IntuneStatus: `Retired`, `Wiped`, `Retire Pending`, or `Wipe Pending`
  - EntraIDStatus: `Enabled`
- **Action:** Disable or delete device in Entra ID

#### **Clean up Intune**
- **Meaning:** Device is disabled in Entra ID but still registered in Intune
- **Conditions:**
  - EntraIDStatus: `Disabled`
  - Last check-in: > 90 days
- **Action:** Remove device from Intune (Retire/Delete)

#### **Retire from Intune**
- **Meaning:** Device is disabled in Entra ID but still marked as active in Intune
- **Conditions:**
  - IntuneStatus: `Active`
  - EntraIDStatus: `Disabled`
- **Action:** Perform retire/wipe in Intune

#### **Entra ID Missing - Clean up Intune**
- **Meaning:** The Entra ID device object has been deleted, but device still exists in Intune
- **Conditions:**
  - EntraIDStatus: `Entra ID Object Not Found`
  - AzureAdDeviceId exists, but device no longer exists in Entra ID
- **Action:** Remove device from Intune

---

### Already Inactive

#### **Already Inactive**
- **Meaning:** Device is disabled/retired in both Intune and Entra ID
- **Conditions:**
  - IntuneStatus: `Retired`, `Wiped`, `Retire Pending`, or `Wipe Pending`
  - EntraIDStatus: `Disabled` or `Entra ID Object Not Found`
- **Action:** Optional: Permanently delete from both systems (if retention periods are met)

---

### Special Cases

#### **MDM Only - Review**
- **Meaning:** Device is registered via MDM only, without Entra ID link
- **Conditions:**
  - EntraIDStatus: `No Entra ID Link`
  - No AzureAdDeviceId present
- **Action:** Check if this is intended (e.g., Workplace Join, BYOD devices)

#### **Not in Intune - Review**
- **Meaning:** Device was not found in Intune during the query
- **Conditions:**
  - Device does not exist in Intune
- **Action:** Check if device should be registered or if CSV entry is outdated

#### **Review Required**
- **Meaning:** Unclear status combination, manual review required
- **Conditions:**
  - None of the other rules apply
  - Unusual status combination
- **Action:** Manually review and take appropriate action

---

## Entra ID Status - Meanings

| Status | Meaning |
|--------|---------|
| **Enabled** | Device is enabled in Entra ID |
| **Disabled** | Device is disabled in Entra ID |
| **No Entra ID Link** | Device has no link to Entra ID (e.g., MDM-only, Workplace Join) |
| **Entra ID Object Not Found** | AzureAdDeviceId exists, but device object was deleted from Entra ID |
| **Error** | Error retrieving Entra ID status |
| **Not found** | Device not found in Intune |

---

## Intune Status - Meanings

| Status | Meaning |
|--------|---------|
| **Active** | Device is actively managed |
| **Retire Pending** | Retirement has been initiated |
| **Retired** | Device has been retired |
| **Wipe Pending** | Wipe has been initiated |
| **Wiped** | Device has been wiped |
| **Not found** | Device not found in Intune |

---

## Recommended Workflow

1. **Run report** and open CSV file
2. **Sort/filter by RecommendedAction**
3. **Set priorities:**
   - First: Devices with "Disable in Entra ID", "Retire from Intune", "Clean up Intune"
   - Then: Devices with ">90 days inactive"
   - After: Devices with ">60 days inactive"
4. **Validation:** Clarify with IT team/user before deactivation
5. **Documentation:** Log changes

---

## Recommended Retention Periods

- **Active devices:** Unlimited
- **30-60 days inactive:** Continue monitoring
- **60-90 days inactive:** Preparation for deactivation
- **> 90 days inactive:** Disable/Remove
- **Retired/Wiped:** 30-90 days retention in logs, then delete

---

## Permissions

The script requires the following Microsoft Graph permissions to retrieve data:

- `DeviceManagementConfiguration.Read.All` - Read Intune configuration
- `DeviceManagementManagedDevices.Read.All` - Read Intune devices
- `Device.Read.All` - Read Entra ID device status

---

## Version

This document applies to OSVersionReport.ps1 Version 1.2 (2026-01-13)
