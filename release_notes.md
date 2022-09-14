# Pure Storage FlashArray Management Pack for Microsoft System Center Operations Manager Version 2.0.19.0 Release Notes

Get the latest information about this release online at: https://support.purestorage.com/Solutions/Microsoft_Platform_Guide/System_Center_Suite/Management_Pack

## RELEASE COMPATIBILITY
This release is compatible with FlashArrays with Purity Operating Environment **5.3.0** and above.

This release requires Microsoft System Center Operations Manager **2016**, **2019**, or **2022**

Upgrading to this release of the Pure Storage FlashArray Management Pack is supported from versions 1.2.9, 1.2.12, and 1.2.20.

## What is New
-	Supports SCOM Resource Pools on installation
-	Endpoint and Resource Pool editing in the GUI
-	Updated Dashboards with more details and larger alerts section
-	Alert & Monitor enhancements including more description in what has failed
-	Array Space Monitor updates with 2 thresholds that provide Healthy, Warning, & Critical states
-	No need to install on every SCOM server. Installation can be done in any SCOM server except for the gateway server (installer will detect and deny installation on that server)
-	Alerts default thresholds updated so the alerting isn’t so noisy
-	ActiveCluster POD and mediator monitoring

## INSTALLATION AND UNINSTALLATION
-   To install the Management Pack, extract and run **SCOMManagementPackInstaller.msi**, and follow the instructions. If this is a new installation close the installer. If this is an upgrade, run the Flash Array Management Tool by checking the box in the installer before closing. If the box is closed, the Flash Array Management tool can be found in the Start Menu, or by navigating to it directly at "C:\Program Files\Pure Storage\Flash Array Management Tool\MpMigrationTool.exe".

-   The purpose of the Flash Array Management Tool, is to migrate Flash Array endpoints, and their corresponding Override Management Packs to the 2.0 schema, preserving override settings and history. First connect to a Management Group, then select Upgrade Management Pack and follow the instructions.

-   The software can be uninstalled from **Programs and Features** of the Control Panel.

## PERFORMANCE TESTING
No performance testing was done for this release.

## END USER LICENSE AGREEMENT
Please review the **EndUserLicenseAgreement.pdf** or **EUA.rtf** file

## OPEN SOURCE LICENSES
Please review **licenses.txt**
