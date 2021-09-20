# Pure Storage FlashArray Management Pack for Microsoft System Center Operations Manager

## Version 1.2.12.0 Release Notes

Fixes:
* Fixed an issue where duplicate alerts might be added to SCOM.

Get the latest information about this release online at: https://support.purestorage.com/Solutions/Microsoft_Platform_Guide/System_Center_Suite/Management_Pack

## RELEASE COMPATIBILITY

This release is compatible with FlashArrays with Purity Operating Environment **4.7.0** and above.
This release requires Microsoft System Center Operations Manager **2012R2**, **2016**, or **2019**.
This release has not been tested in an Azure Stack environment.

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

Please review the **EndUserLicenseAgreement.pdf** file

## OPEN SOURCE LICENSES

Please review **licenses.txt**
