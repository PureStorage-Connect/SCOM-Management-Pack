# Pure Storage FlashArray Management Pack for Microsoft System Center Operations Manager

## Version 1.2.9.0 Release Notes

Get the latest information about this release online at: https://support.purestorage.com/Solutions/Microsoft_Platform_Guide/System_Center_Suite/Management_Pack

## RELEASE COMPATIBILITY

This release is compatible with FlashArrays with Purity Operating Environment **4.7.0** and above.
This release requires Microsoft System Center Operations Manager **2012R2**, **2016**, or **2019**.
This release has not been tested in an Azure Stack environment.

## NEW FEATURES

- Added a configuration parameter to disable logging to the array. This would enable reducing the amount of log entries related to the Management Pack operations that are reported to the Flash Array.
- A Utility PowerShell module is added to package and released as Open Source in this Github Repository (https://github.com/PureStorage-OpenConnect/FlashArray-SCOM-Scripts), This scripts provides tools to:
    - Allow bulk overrides of SCOM overridable configuration parameters.
    - Allow for the bulk changing of thresholds in Rules, Monitors, and Discoveries.

## FIXES

- Fixed issue with SDK request timings for slow queries and responses. (PurePowerShellSDK v1.17.16.0)
- Fixed resource leak problems that were triggered by running some rules, monitors and/or discovery tasks.
- Corrected the Pure Storage SCOM support link visible in the alerts.
- Corrected measurement unit issues in Bandwidth,IOPS monitor and rule.
- Updated the default threshold value of the Bandwidth and IOPS monitors.
- Fixed some incorrect alert messages.
- Added alert messages for the Alert Rule Monitor and the Port Health Monitor.
- Fixed issue with Discovery regex pattern that would not allow more than one array to be added to the MP (from v1.2.5.0)

## KNOWN ISSUES

- Due to a current FlashArray limitation, File Services virtual interfaces (filevif) are either not discovered or are shown as disconnected or down. This is expected to be resolved in a upcoming release.

- The management pack currently does not work with SCOM Resource Pools or targeting individual member servers in a Management Group. This will be addressed in a future revision.

- This version has not been tested in Azure Stack environments.

- This version will report a DirectFlash Shelf (DFS) controller as unhealthy and may show it in a Critical state. This will be resolved in the next release.

## INSTALLATION AND UNINSTALLATION

- To install the Management Pack, extract and run **SCOMManagementPackInstaller.msi**, and follow the instructions.
- The software can be uninstalled from **Programs and Features** of the Control Panel.

## PERFORMANCE TESTING

No performance testing was done for this release.

## END USER LICENSE AGREEMENT

Please review the **EndUserLicenseAgreement.pdf** or **EUA.rtf** file

## OPEN SOURCE LICENSES

Please review **licenses.txt**
