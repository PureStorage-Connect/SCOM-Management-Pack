# Pure Storage FlashArray Management Pack for Microsoft System Center Operations Manager Version 2.0.116.0 Release Notes

Get the latest information about this release online at: https://support.purestorage.com/Solutions/Microsoft_Platform_Guide/System_Center_Suite/Management_Pack

## RELEASE COMPATIBILITY
This release is compatible with FlashArrays with Purity Operating Environment **5.3.0** and above.

This release requires Microsoft System Center Operations Manager **2016**, **2019**, or **2022**

Upgrading to this release of the Pure Storage FlashArray Management Pack is supported from versions 1.2.9, 1.2.12, and 1.2.20.

## What is New for 2.0.116.0

- Support FlashArray C and Cloud Block Store arrays
- Support Arrays with Direct Flash Shelves (DFS)

## Known Issues

The v2.0.116.0 release will install in a greenfield deployment or perform an upgrade if the v1.x version of the Pure Storage SCOM Management Pack is installed.
Upgrade from v2.0.19.0 using the upgrade wizard is unsupported and will fail. A workaround for an existing v2.0.19.0 deployment, is to manually import the management pack. The management pack can be extracted from the MSI or downloaded directly (PureStorageFlashArray.mpb) from this release.
For more details on importing a management pack, see: https://learn.microsoft.com/en-us/system-center/scom/manage-mp-import-remove-delete?view=sc-om-2022

# Manual Import Summary

In the Operations console, select Administration.
- Right-click Management Packs, and select Import Management Packs.
- The 'Import Management Packs' wizard opens. Select Add, and then select Add from disk.
- The 'Select Management Packs to import' dialog appears. If necessary, change to the directory that holds the PureStorageFlashArray.mpb management pack file and select Open.
- On the Select Management Packs page, the management packs that you selected for import are listed. A green check mark indicates that the management pack can be imported. Select Import.
- Select Close.
  
Follow Pure's Management Pack Guide on configuring an override management pack and adding FlashArrays to Operations Manager: https://github.com/PureStorage-Connect/SCOM-Management-Pack/blob/main/SCOMManagementPack-Guide.pdf (edited)

## What is New for 2.0.19.0
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
