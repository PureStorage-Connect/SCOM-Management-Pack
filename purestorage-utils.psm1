<#
.SYNOPSIS
  Helper functions to facilitate managing purestorage management pack overrides
.DESCRIPTION
  Helper functions to facilitate managing purestorage management pack overrides
  Version:        1.0
  Author:         Hesham Anan, Mike Nelson @ Pure Storage
<#
.DISCLAIMER
You running this code means you will not blame the author(s) if this breaks your stuff. This script/function is provided AS IS without warranty of any kind. Author(s) disclaim all implied warranties including, without limitation, any implied warranties of merchantability or of fitness for a particular purpose. The entire risk arising out of the use or performance of the sample scripts and documentation remains with you. In no event shall author(s) be held liable for any damages whatsoever arising out of the use of or inability to use the script or documentation.
#>
function CreateManagementPack {
    param (
        $Name
    )
    $ManagementPackID = $Name
    $MG = Get-SCOMManagementGroup
    $MPStore = New-Object Microsoft.EnterpriseManagement.Configuration.IO.ManagementPackFileStore
    $MP = New-Object Microsoft.EnterpriseManagement.Configuration.ManagementPack($ManagementPackID, $Name, (New-Object Version(1, 0, 0)), $MPStore)
    $MG.ImportManagementPack($MP)
    $MP = $MG.GetManagementPacks($ManagementPackID)[0]
    $MP.DisplayName = $Name
    $MP.Description = "Auto Generated Management Pack $Name"
    $MP.AcceptChanges()
}

function SaveChanges {
    param (
        $OverridesManagementPack
    )
    try {
        $OverridesManagementPack.Verify()
        $OverridesManagementPack.AcceptChanges()
    }
    catch {
        Write-Error $_
        $OverridesManagementPack.RejectChanges()
    }
}

function Get-SourceModule {

    param (
        $OverridableParameters,
        $ParamName
    )
    $arrModules = New-Object System.Collections.ArrayList
    Foreach ($module in $OverridableParameters.keys) {
        foreach ($parameter in $OverridableParameters.$module) {
            if ($parameter.name -ieq $ParamName) {
                $objParameter = New-Object psobject
                Add-Member -InputObject $objParameter -MemberType NoteProperty -Name Module -Value  $module.name
                Add-Member -InputObject $objParameter -MemberType NoteProperty -Name Parameter -Value  $parameter.name
                [System.Void]$arrModules.Add($objParameter)
            }
        }
    }

    If ($arrModules.Count -eq 1) {
        return $arrModules[0].Module
    }
    else {
        return $null
    }
}

function Set-RulesLogToArrayOverrides {
    param (
        $ManagementPack,
        $OverridesManagementPack
    )
    $rules = $ManagementPack | Get-SCOMRule
    for ($i = 0; $i -le $rules.Length - 1; $i++)  {
        $rule = $rules[$i]
        $objParameters = $rule.GetOverrideableParametersByModule()
        $module = Get-SourceModule -OverridableParameters $objParameters -ParamName "LogToArray"
        if ($null -ne $module) {
            Write-Host "$Action logging for rule $( $rule.Name )"
            $target = Get-SCOMClass -Id $rule.Target.Id
            $OverrideID = "LogToArrayOverride." + $rule.name
            $override = New-Object Microsoft.EnterpriseManagement.Configuration.ManagementPackRuleConfigurationOverride($OverridesManagementPack, $OverrideID)
            $override.Rule = $rule
            $Override.Parameter = 'LogToArray'
            $override.Value = $LogToArray
            $override.Context = $Target
            $override.DisplayName = $OverrideID
            $override.Enforced = $true
            $override.Module = $module
            SaveChanges -OverridesManagementPack $OverridesManagementPack
        }
    }
}

function Set-MonitorsLogToArrayOverrides {
    param (
        $ManagementPack,
        $OverridesManagementPack
    )
    $monitors = $ManagementPack | Get-SCOMMonitor | Where { $_.xmltag -eq "UnitMonitor" }
    $monitors | ForEach-Object {
        $monitor = $_
        $target = Get-SCOMClass -Id $monitor.Target.Id
        Write-Host "$Action logging for monitor $( $monitor.Name ) ... "
        $OverrideID = "LogToArrayOverride" + $monitor.name
        $Override = New-Object Microsoft.EnterpriseManagement.Configuration.ManagementPackMonitorConfigurationOverride($OverridesManagementPack, $OverrideID)
        $Override.Monitor = $monitor
        $Override.Parameter = "LogToArray"
        $Override.Value = $LogToArray
        $Override.Context = $target
        $Override.DisplayName = "Override LogToArray"
        $override.Enforced = $true
        SaveChanges -OverridesManagementPack $OverridesManagementPack
    }
}

function Set-DiscoveriesLogToArrayOverrides {
    param (
        $ManagementPack,
        $OverridesManagementPack
    )
    $discoveries = $ManagementPack | Get-SCOMDiscovery
    for ($i = 0; $i -le $discoveries.Length - 1; $i++) {
        $discovery = $discoveries[$i]
        $objParameters = $discovery.GetOverrideableParametersByModule()
        $module = Get-SourceModule -OverridableParameters $objParameters -ParamName "LogToArray"
        if ($null -ne $module) {
            Write-Host "$Action logging for discovery $( $discovery.Name )"
            $target = Get-SCOMClass -Id $discovery.Target.Id
            $OverrideID = "LogToArrayOverride" + $discovery.name
            $Override = New-Object Microsoft.EnterpriseManagement.Configuration.ManagementPackDiscoveryConfigurationOverride($OverridesManagementPack, $OverrideID)
            $Override.Discovery = $discovery
            $Override.Parameter = "LogToArray"
            $Override.Value = $LogToArray
            $Override.Context = $target
            $Override.DisplayName = "Override LogToArray"
            $override.Enforced = $true
            $override.Module = $module
            SaveChanges -OverridesManagementPack $OverridesManagementPack
        }
    }
}

$INITIAL_DISCOVERY_SCRIPT_REGEX = '(?s)<ScriptName>PureStorage\.FlashArray\.PureArray\.Discovery\.ps1</ScriptName>.*<ScriptBody>(?<script>.*)</ScriptBody>'
function New-TemporaryDirectory {
    $parent = [System.IO.Path]::GetTempPath()
    [string]$name = [System.Guid]::NewGuid()
    $path = (Join-Path $parent $name)
    New-Item -ItemType Directory -Path  $path
}

function Get-InitialDiscoveryScript {
    param (
        $content
    )

    $match = $content | Select-String $INITIAL_DISCOVERY_SCRIPT_REGEX
    if ($match) {
        $script = $match.Matches[0].Value
        return $script
    }
}


function Update-RuleParam {
    param(
        $RuleName,
        $ParamName,
        $ParamValue,
        $OverridesManagementPack
    )

    Write-Host "Updating $RuleName : Overriding $ParamName to $ParamValue"
    $rule = Get-SCOMRule -Name $RuleName
    if (!$rule) {
        Write-Error "Could not find rule : $RuleName"
    }
    $objParameters = $rule.GetOverrideableParametersByModule()
    $module = Get-SourceModule -OverridableParameters $objParameters -ParamName $ParamName
    if (!$module) {
        Write-Error "Could not find module that includes parameter : $ParamName"
        return
    }
    $target = Get-SCOMClass -Id $rule.Target.Id
    $OverrideID = $ParamName + "Override." + $rule.name
    $override = New-Object Microsoft.EnterpriseManagement.Configuration.ManagementPackRuleConfigurationOverride($OverridesManagementPack, $OverrideID)
    $override.Rule = $rule
    $Override.Parameter = $ParamName
    $override.Value = $ParamValue
    $override.Context = $target
    $override.DisplayName = $OverrideID
    $override.Enforced = $true
    $override.Module = $module
    SaveChanges -OverridesManagementPack $OverridesManagementPack
}

function Update-DiscoveryParam {
    param(
        $DiscoveryName,
        $ParamName,
        $ParamValue,
        $OverridesManagementPack
    )

    Write-Host "Updating $DiscoveryName : Overriding $ParamName to $ParamValue"
    $discovery = Get-SCOMDiscovery -Name $DiscoveryName
    if (!$discovery) {
        Write-Error "Could not find discovery : $DiscoveryName"
    }
    $objParameters = $discovery.GetOverrideableParametersByModule()
    $module = Get-SourceModule -OverridableParameters $objParameters -ParamName $ParamName
    if (!$module) {
        Write-Error "Could not find module that includes parameter : $ParamName"
        return
    }
    $target = Get-SCOMClass -Id $discovery.Target.Id
    $OverrideID = $ParamName + "Override." + $discovery.name
    $override = New-Object Microsoft.EnterpriseManagement.Configuration.ManagementPackDiscoveryConfigurationOverride($OverridesManagementPack, $OverrideID)
    $override.Discovery = $discovery
    $Override.Parameter = $ParamName
    $override.Value = $ParamValue
    $override.Context = $target
    $override.DisplayName = $OverrideID
    $override.Enforced = $true
    $override.Module = $module
    SaveChanges -OverridesManagementPack $OverridesManagementPack
}

function Update-MonitorParam {
    param(
        $MonitorName,
        $ParamName,
        $ParamValue,
        $OverridesManagementPack
    )

    Write-Host "Updating $MonitorName : Overriding $ParamName to $ParamValue"
    $monitor = Get-SCOMMonitor -Name $MonitorName
    if (!$monitor) {
        Write-Error "Could not find discovery : $MonitorName"
    }
    $target = Get-SCOMClass -Id $monitor.Target.Id
    $OverrideID = $ParamName + "Override." + $monitor.name
    $override = New-Object Microsoft.EnterpriseManagement.Configuration.ManagementPackMonitorConfigurationOverride($OverridesManagementPack, $OverrideID)
    $override.Monitor = $monitor
    $Override.Parameter = $ParamName
    $override.Value = $ParamValue
    $override.Context = $target
    $override.DisplayName = $OverrideID
    $override.Enforced = $true
    SaveChanges -OverridesManagementPack $OverridesManagementPack
}

function Get-Json {
    param (
        $Path
    )
    $json = Get-Content $path | ConvertFrom-Json
    # Convert to hashtable
    $result = @{
    }
    $json.psobject.properties | ForEach-Object {
        $result[$_.Name] = $_.Value
    }
    return $result
}

# helper to turn PSCustomObject into a list of key/value pairs
function Get-ObjectMembers {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $True, ValueFromPipeline = $True)]
        [PSCustomObject]$obj
    )
    $obj | Get-Member -MemberType NoteProperty | ForEach-Object {
        $key = $_.Name
        [PSCustomObject]@{
            Key = $key; Value = $obj."$key"
        }
    }
}
function Write-ProgressHelper {
    param(
        [int]$StepNumber,
        [string]$Message
    )
    Write-Progress -Activity 'Modifing the Pure Storage SCOM Management Pack' -Status $Message -PercentComplete (($StepNumber / $steps) * 100)
}

function End {
    param (
        $ScriptLog
    )
    if ($ScriptLog) {
        Stop-Transcript
    }
}

<#
.SYNOPSIS
  Enable/Disable logging to array for Systems Center Operations Manager and Pure Storage FlashArray SCOM Management Pack.
.DESCRIPTION
  This script will programatically set the LogToArray parameter in all rules, discoveries, & monitors in the Pure Storage SCOM Management Pack for FlashArray to either true or false. Disabling this logging will reduce the amount of log entries generated on the array by the MP.
.PARAMETER OverridesManagementPackName
    Required. This is the name of the new management pack override necessary to set the new value.
.PARAMETER LogToArray
    Required. Set to "true" or "false".
.PARAMETER ScriptLog
    If set to $true, this will enable the PowerShell Start-Transcript cmdlet to log all verbose output. The default log location is in the script root.
.INPUTS
  None
.OUTPUTS
  Results can also be viewed in the SCOM audit logs.
.EXAMPLE
  Set-LoggingToArray -OverridesManagementPackName "MyOverride" -LogToArray $true -ScriptLog $true
  #>

function Set-LoggingToArray {
    param(
        [Parameter(Mandatory = $true)]
        [string] $OverridesManagementPackName,
        [Parameter(Mandatory = $true)]
        [bool] $LogToArray,
        [Parameter(Mandatory = $false)]
        [bool] $Scriptlog
    )

    if ($ScriptLog) {
        $logFile = "$PSScriptRoot\LoggingToArray.txt"
        Start-Transcript -Path $logFile -Append
    }

    if ($LogToArray) {
        $Action = "Enabling"
    }
    else {
        $Action = "Disabling"
    }

    Write-Host " "
    Write-host "Beginning processing..."
    Write-Host "Depending on SCOM environment, this may take several minutes to complete."
    Write-Host "Do not close this session until script has finished."
    Write-Host " "
    Start-Sleep 2

    $script:steps = 4 # Number of Write-ProgressHelper commands in this function
    $stepCounter = 0
    $mp = Get-SCOMManagementPack -Name PureStorageFlashArray
    if (!$mp) {
        Write-Error "Failed to find management pack 'PureStorageFlashArray'"
        End -ScriptLog $Scriptlog
        exit
    }

    Write-ProgressHelper -Message 'Creating Management Pack Override' -StepNumber ($stepCounter++)
    $overrides_mp = Get-SCOMManagementPack -Name $OverridesManagementPackName
    if (!$overrides_mp) {
        Write-Host "Creating management pack $OverridesManagementPackName..."
        CreateManagementPack -Name $OverridesManagementPackName
    }
    Write-ProgressHelper -Message 'Processing Rules' -StepNumber ($stepCounter++)
    Set-RulesLogToArrayOverrides -ManagementPack $mp -OverridesManagementPack $overrides_mp

    Write-ProgressHelper -Message 'Processing Discoveries' -StepNumber ($stepCounter++)
    Set-DiscoveriesLogToArrayOverrides -ManagementPack $mp -OverridesManagementPack $overrides_mp

    Write-ProgressHelper -Message 'Processing Monitors' -StepNumber ($stepCounter++)
    Set-MonitorsLogToArrayOverrides -ManagementPack $mp -OverridesManagementPack $overrides_mp
    End -ScriptLog $Scriptlog
}

<#
.SYNOPSIS
  Update discovery workflows stored in overrides management pack
.DESCRIPTION
  This script will update code for initial discovery stored in the overrides management pack
.PARAMETER OverridesManagementPackName
    Required. This is the name of the overrides management pack.
.PARAMETER ScriptLog
    If set to $true, this will enable the PowerShell Start-Transcript cmdlet to log all verbose output. The default log location is in the script root.
 EXAMPLE
  Update-Overrides -OverridesManagementPackName "MyOverride"
  #>
function Update-Overrides {
    param (
    # Overrides management pack name
        [Parameter(Mandatory = $true)]
        [string] $OverridesManagementPackName,
        [Parameter(Mandatory = $false)]
        [bool] $Scriptlog
    )

    if ($ScriptLog) {
        $logFile = "$PSScriptRoot\LoggingToArray.txt"
        Start-Transcript -Path $logFile -Append
    }

    Write-Host " "
    Write-host "Beginning processing..."
    Write-Host "Depending on SCOM environment, this may take several minutes to complete."
    Write-Host "Do not close this session until script has finished."
    Write-Host " "
    Start-Sleep 2

    $script:steps = 3 # Number of Write-ProgressHelper commands in this function
    $stepCounter = 0

    $mp = Get-SCOMManagementPack -Name PureStorageFlashArray
    if (!$mp) {
        Write-Error "Failed to find management pack 'PureStorageFlashArray'"
        End -ScriptLog $Scriptlog
        exit
    }

    $overrides_mp = Get-SCOMManagementPack -DisplayName $OverridesManagementPackName
    if (!$overrides_mp) {
        Write-Error "Failed to find management pack '$OverridesManagementPackName'"
        End -ScriptLog $Scriptlog
        exit
    }

    Write-ProgressHelper -Message 'Inspecting existing management packs' -StepNumber ($stepCounter++)
    $temp_dir = New-TemporaryDirectory
    $overrides_mp | Export-SCManagementPack -Path $temp_dir
    $mp | Export-SCManagementPack -Path $temp_dir

    $mp_xml_path = (Join-Path $temp_dir $mp.Name) + ".xml"
    $mp_xml = Get-Content $mp_xml_path -Raw

    Write-ProgressHelper -Message 'Updating overrides management pack $OverridesManagementPackName' -StepNumber ($stepCounter++)
    $overrides_xml_path = (Join-Path $temp_dir $overrides_mp.Name) + ".xml"
    $overrides_xml = Get-Content $overrides_xml_path -Raw

    $mp_script = Get-InitialDiscoveryScript -content $mp_xml
    $overrides_script = Get-InitialDiscoveryScript -content $overrides_xml

    $overrides_xml = $overrides_xml.Replace($overrides_script, $mp_script)
    # Resolve management pack references
    $overrides_xml = $overrides_xml.Replace("`$Reference/Self`$", "PureStorageFlashArray!")

    Set-Content -Path $overrides_xml_path -Value $overrides_xml

    # Import to SCOM
    Write-Output "Updating management pack $OverridesManagementPackName ..."
    Import-SCOMManagementPack $overrides_xml_path
    Write-Output "Finished updating management pack $OverridesManagementPackName ..."

    Write-ProgressHelper -Message 'Finalizing updates ..' -StepNumber ($stepCounter++)
    # Cleanup
    Remove-Item -Path $temp_dir -Recurse -Force
    End -ScriptLog $Scriptlog
}

<#
.SYNOPSIS
  Creates overrides for overridable configuration parameters
.DESCRIPTION
  This script will create overrides for overridable configuration parameters
.PARAMETER OverridesConfigPath
    Required. Path to JSON file that includes overrides information in the following format:.
    {
    "monitor":  {
        "<monitor name>>":  {
            "<param name>>":  <param value>>,
            ...
        }
        ,
        ....
    },
    "rule":  {
        "<rule name>":  {
            "<param name>>":  <param value>>,
            ...
        },
        .....
    },
    "discovery":  {
        "<discovery name>":  {
            "<param name>>":  <param value>>,
            ...
            }
        },
        ......
    }

    The following is a sample OveridesCOnfig JSON file
    {
    "monitor":  {
        "PureStorageFlashArray.ArrayOPSMonitor.Powershell":  {
            "LogToArray":  false,
            "Threshold":  200
        }
    },
    "rule":  {
        "PureStorage.FlashArray.PureHost.PowerShell.Script.Perf.WriteBandwidth.Rule":  {
            "LogToArray":  true
        }
    },
    "discovery":  {
        "PureStorage.FlashArray.PureArray.Discovery":  {
            "LogToArray":  true
            }
        }
    }

.PARAMETER OverridesManagementPackName
    Required. This is the name of the overrides management pack.
.PARAMETER ScriptLog
    If set to $true, this will enable the PowerShell Start-Transcript cmdlet to log all verbose output. The default log location is in the script root.
.EXAMPLE
  Set-OverridableConfig -OverridesConfigPath "MyConfigOverrides.json"  -OverridesManagementPackName "MyOverridesMP"
 #>

function Set-OverridableConfig {
    param (
        [Parameter(Mandatory = $true)]
        [string] $OverridesConfigPath,
        [Parameter(Mandatory = $true)]
        [string] $OverridesManagementPackName,
        [Parameter(Mandatory = $false)]
        [bool] $Scriptlog
    )

    if ($ScriptLog) {
        $logFile = "$PSScriptRoot\LoggingToArray.txt"
        Start-Transcript -Path $logFile -Append
    }

    Write-Host " "
    Write-host "Beginning processing..."
    Write-Host "Depending on SCOM environment, this may take several minutes to complete."
    Write-Host "Do not close this session until script has finished."
    Write-Host " "
    Start-Sleep 2

    $script:steps = 3 # Number of Write-ProgressHelper commands in this function
    $stepCounter = 0

    $mp = Get-SCOMManagementPack -Name PureStorageFlashArray
    if (!$mp) {
        Write-Error "Failed to find management pack 'PureStorageFlashArray'"
        End -ScriptLog $Scriptlog
        exit
    }
    $overrides_mp = Get-SCOMManagementPack -Name $OverridesManagementPackName
    if (!$overrides_mp) {
        Write-Host "Creating management pack $OverridesManagementPackName..."
        CreateManagementPack -Name $OverridesManagementPackName
        $overrides_mp = Get-SCOMManagementPack -Name $OverridesManagementPackName
    }
    $config = Get-Json -path $OverridesConfigPath
    foreach ($item in $config) {
        foreach ($entityKey in $item.Keys) {
            $entity = $item[$entityKey] | Get-ObjectMembers
            foreach ($scom_entity in $entity) {
                $name = $scom_entity.Key
                $params = $scom_entity.Value | Get-ObjectMembers
                foreach ($param in $params) {
                    $paramName = $param.Key
                    $paramValue = $param.Value
                    # Create overrides
                    switch ($entityKey) {
                        "rule" {
                            Write-ProgressHelper -Message 'Processing Rules' -StepNumber ($stepCounter++)
                            Update-RuleParam -RuleName $name -ParamName $paramName -ParamValue $paramValue -OverridesManagementPack $overrides_mp
                        }
                        "discovery" {
                            Write-ProgressHelper -Message 'Processing Discoveries' -StepNumber ($stepCounter++)
                            Update-DiscoveryParam -DiscoveryName $name -ParamName $paramName -ParamValue $paramValue -OverridesManagementPack $overrides_mp
                        }
                        "monitor" {
                            Write-ProgressHelper -Message 'Processing Monitors' -StepNumber ($stepCounter++)
                            Update-MonitorParam -MonitorName $name -ParamName $paramName -ParamValue $paramValue -OverridesManagementPack $overrides_mp
                        }
                    }
                }
            }
        }
    }
    End -ScriptLog $Scriptlog
}

Export-ModuleMember -Function Set-LoggingToArray
Export-ModuleMember -Function Update-Overrides
Export-ModuleMember -Function Set-OverridableConfig
# SIG # Begin signature block
# MIIcFQYJKoZIhvcNAQcCoIIcBjCCHAICAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCBjcLcH6gA6epuj
# Nau0wmzvn8o7iOdqcOtc+0v8ISRKSKCCCm8wggUwMIIEGKADAgECAhAECRgbX9W7
# ZnVTQ7VvlVAIMA0GCSqGSIb3DQEBCwUAMGUxCzAJBgNVBAYTAlVTMRUwEwYDVQQK
# EwxEaWdpQ2VydCBJbmMxGTAXBgNVBAsTEHd3dy5kaWdpY2VydC5jb20xJDAiBgNV
# BAMTG0RpZ2lDZXJ0IEFzc3VyZWQgSUQgUm9vdCBDQTAeFw0xMzEwMjIxMjAwMDBa
# Fw0yODEwMjIxMjAwMDBaMHIxCzAJBgNVBAYTAlVTMRUwEwYDVQQKEwxEaWdpQ2Vy
# dCBJbmMxGTAXBgNVBAsTEHd3dy5kaWdpY2VydC5jb20xMTAvBgNVBAMTKERpZ2lD
# ZXJ0IFNIQTIgQXNzdXJlZCBJRCBDb2RlIFNpZ25pbmcgQ0EwggEiMA0GCSqGSIb3
# DQEBAQUAA4IBDwAwggEKAoIBAQD407Mcfw4Rr2d3B9MLMUkZz9D7RZmxOttE9X/l
# qJ3bMtdx6nadBS63j/qSQ8Cl+YnUNxnXtqrwnIal2CWsDnkoOn7p0WfTxvspJ8fT
# eyOU5JEjlpB3gvmhhCNmElQzUHSxKCa7JGnCwlLyFGeKiUXULaGj6YgsIJWuHEqH
# CN8M9eJNYBi+qsSyrnAxZjNxPqxwoqvOf+l8y5Kh5TsxHM/q8grkV7tKtel05iv+
# bMt+dDk2DZDv5LVOpKnqagqrhPOsZ061xPeM0SAlI+sIZD5SlsHyDxL0xY4PwaLo
# LFH3c7y9hbFig3NBggfkOItqcyDQD2RzPJ6fpjOp/RnfJZPRAgMBAAGjggHNMIIB
# yTASBgNVHRMBAf8ECDAGAQH/AgEAMA4GA1UdDwEB/wQEAwIBhjATBgNVHSUEDDAK
# BggrBgEFBQcDAzB5BggrBgEFBQcBAQRtMGswJAYIKwYBBQUHMAGGGGh0dHA6Ly9v
# Y3NwLmRpZ2ljZXJ0LmNvbTBDBggrBgEFBQcwAoY3aHR0cDovL2NhY2VydHMuZGln
# aWNlcnQuY29tL0RpZ2lDZXJ0QXNzdXJlZElEUm9vdENBLmNydDCBgQYDVR0fBHow
# eDA6oDigNoY0aHR0cDovL2NybDQuZGlnaWNlcnQuY29tL0RpZ2lDZXJ0QXNzdXJl
# ZElEUm9vdENBLmNybDA6oDigNoY0aHR0cDovL2NybDMuZGlnaWNlcnQuY29tL0Rp
# Z2lDZXJ0QXNzdXJlZElEUm9vdENBLmNybDBPBgNVHSAESDBGMDgGCmCGSAGG/WwA
# AgQwKjAoBggrBgEFBQcCARYcaHR0cHM6Ly93d3cuZGlnaWNlcnQuY29tL0NQUzAK
# BghghkgBhv1sAzAdBgNVHQ4EFgQUWsS5eyoKo6XqcQPAYPkt9mV1DlgwHwYDVR0j
# BBgwFoAUReuir/SSy4IxLVGLp6chnfNtyA8wDQYJKoZIhvcNAQELBQADggEBAD7s
# DVoks/Mi0RXILHwlKXaoHV0cLToaxO8wYdd+C2D9wz0PxK+L/e8q3yBVN7Dh9tGS
# dQ9RtG6ljlriXiSBThCk7j9xjmMOE0ut119EefM2FAaK95xGTlz/kLEbBw6RFfu6
# r7VRwo0kriTGxycqoSkoGjpxKAI8LpGjwCUR4pwUR6F6aGivm6dcIFzZcbEMj7uo
# +MUSaJ/PQMtARKUT8OZkDCUIQjKyNookAv4vcn4c10lFluhZHen6dGRrsutmQ9qz
# sIzV6Q3d9gEgzpkxYz0IGhizgZtPxpMQBvwHgfqL2vmCSfdibqFT+hKUGIUukpHq
# aGxEMrJmoecYpJpkUe8wggU3MIIEH6ADAgECAhALiNk6K2THnuSy4yCxZdfSMA0G
# CSqGSIb3DQEBCwUAMHIxCzAJBgNVBAYTAlVTMRUwEwYDVQQKEwxEaWdpQ2VydCBJ
# bmMxGTAXBgNVBAsTEHd3dy5kaWdpY2VydC5jb20xMTAvBgNVBAMTKERpZ2lDZXJ0
# IFNIQTIgQXNzdXJlZCBJRCBDb2RlIFNpZ25pbmcgQ0EwHhcNMjAwNzMwMDAwMDAw
# WhcNMjMxMDA0MTIwMDAwWjB0MQswCQYDVQQGEwJVUzETMBEGA1UECBMKQ2FsaWZv
# cm5pYTEWMBQGA1UEBxMNTW91bnRhaW4gVmlldzEbMBkGA1UEChMSUHVyZSBTdG9y
# YWdlLCBJbmMuMRswGQYDVQQDExJQdXJlIFN0b3JhZ2UsIEluYy4wggEiMA0GCSqG
# SIb3DQEBAQUAA4IBDwAwggEKAoIBAQDqd58Tr4DSc0xjzbG2RBv5qTAjSjEuoRtF
# jrlsTit74JVBXbE/z3/sUgBeiiqPE06+u1aJxZMY5mMF0AURdcBQTK70KRYU5cYt
# Xf9CRwR9jd7dnePKlrqHUTOdISnfBJAQhVuKCLqNHazs0OcOhIMAqfNwZxJnw3Pt
# qRcWs3w8CaDeDLxr+vCbYqjsKVFlQePUL84w9dSqI3RDgXICxp4Wa+DY9fa3DGjX
# 3ZZF02ujV2Qo1+YO/KbayzoxdyqAUSMFxm0cO/d7+LQGNPbgmbULbshVhnNV/bx2
# qZV8+juXxssQexUqCtF/RXNLbAhHTyBeIyuiF/22/cBu+0+TtlprAgMBAAGjggHF
# MIIBwTAfBgNVHSMEGDAWgBRaxLl7KgqjpepxA8Bg+S32ZXUOWDAdBgNVHQ4EFgQU
# k7AWftLguPpB02cfq2mbcUwVYkgwDgYDVR0PAQH/BAQDAgeAMBMGA1UdJQQMMAoG
# CCsGAQUFBwMDMHcGA1UdHwRwMG4wNaAzoDGGL2h0dHA6Ly9jcmwzLmRpZ2ljZXJ0
# LmNvbS9zaGEyLWFzc3VyZWQtY3MtZzEuY3JsMDWgM6Axhi9odHRwOi8vY3JsNC5k
# aWdpY2VydC5jb20vc2hhMi1hc3N1cmVkLWNzLWcxLmNybDBMBgNVHSAERTBDMDcG
# CWCGSAGG/WwDATAqMCgGCCsGAQUFBwIBFhxodHRwczovL3d3dy5kaWdpY2VydC5j
# b20vQ1BTMAgGBmeBDAEEATCBhAYIKwYBBQUHAQEEeDB2MCQGCCsGAQUFBzABhhho
# dHRwOi8vb2NzcC5kaWdpY2VydC5jb20wTgYIKwYBBQUHMAKGQmh0dHA6Ly9jYWNl
# cnRzLmRpZ2ljZXJ0LmNvbS9EaWdpQ2VydFNIQTJBc3N1cmVkSURDb2RlU2lnbmlu
# Z0NBLmNydDAMBgNVHRMBAf8EAjAAMA0GCSqGSIb3DQEBCwUAA4IBAQAxUBruZfGE
# Ed/R1PN/osoOdw3wqfMHn0oG93Qq9dlzoWgscaLZaDpcFI/72Z0Mwxg6SiGqy1KT
# tEP6t5PzGKm2siRIxxVxOiDVnd4mNhMrwHtCxKm67aWjRFYDmt2+own6VXNtuO15
# Or66Jw/hP8QPC/ar6I8CCldAPzKvTzgTENYm0x+G/LRzGHnnnHHzyu8VY6EmddiI
# W2No712nt/ZOdlEnjiuYH3yNz0QFH/wYs6L8GHI+KJTicG/wkgdU/UTnMi3z/0+F
# +l6eaJYFu64/RgufOupGGzC0lqqMmKtg0tiiOYg2tu91ykQoYrUCK2ye46MVp0sj
# ttzr3pjfmVQBMYIQ/DCCEPgCAQEwgYYwcjELMAkGA1UEBhMCVVMxFTATBgNVBAoT
# DERpZ2lDZXJ0IEluYzEZMBcGA1UECxMQd3d3LmRpZ2ljZXJ0LmNvbTExMC8GA1UE
# AxMoRGlnaUNlcnQgU0hBMiBBc3N1cmVkIElEIENvZGUgU2lnbmluZyBDQQIQC4jZ
# Oitkx57ksuMgsWXX0jANBglghkgBZQMEAgEFAKB8MBAGCisGAQQBgjcCAQwxAjAA
# MBkGCSqGSIb3DQEJAzEMBgorBgEEAYI3AgEEMBwGCisGAQQBgjcCAQsxDjAMBgor
# BgEEAYI3AgEVMC8GCSqGSIb3DQEJBDEiBCBrUNq8w2uZxtcuRTWuIi28VIENkEH/
# k1tmLQJsominuTANBgkqhkiG9w0BAQEFAASCAQC7lOzlzJwSmdMcj/vpEuJSvIoo
# 7bcZgoSBpsCop5/a6JCq1nvmEmbckI7QSwxM/eiem7Ow56HAD2AFsFyO+r4Hpvnf
# l+2Fb7MH3cX4hLhpjvXrCAyZjyoxiXJzwDzSCVSXe1xT/wFThtHBpDAy4iVkl+2x
# 7G9YOI2IkXlhFcKWmIR2S5vPk0EbpjzGKe9Y50fuCKqrCmx7N/UP338/3rDrhbOk
# urL6Icxw+NkpFqHm08V6DTWUxRRnfkIaGh5Gv4tX8pcLrSngIC4s9wBaKtlPImin
# v4AS+b+A+XJhLJdducwXiZFkBOfMG+qSbmuEPWv5SV1rBnGOJMvV7kBUTzp3oYIO
# yDCCDsQGCisGAQQBgjcDAwExgg60MIIOsAYJKoZIhvcNAQcCoIIOoTCCDp0CAQMx
# DzANBglghkgBZQMEAgEFADB3BgsqhkiG9w0BCRABBKBoBGYwZAIBAQYJYIZIAYb9
# bAcBMDEwDQYJYIZIAWUDBAIBBQAEIK4pWmTERNdmdQRpfDpAZ58ua5ps+/qtiHD6
# Bi3zTvjkAhAbyejNm216VlpfZtV6HDhsGA8yMDIwMTAyMjAwNDgyOVqgggu7MIIG
# gjCCBWqgAwIBAgIQBM0/hWiudsYbsP5xYMynbTANBgkqhkiG9w0BAQsFADByMQsw
# CQYDVQQGEwJVUzEVMBMGA1UEChMMRGlnaUNlcnQgSW5jMRkwFwYDVQQLExB3d3cu
# ZGlnaWNlcnQuY29tMTEwLwYDVQQDEyhEaWdpQ2VydCBTSEEyIEFzc3VyZWQgSUQg
# VGltZXN0YW1waW5nIENBMB4XDTE5MTAwMTAwMDAwMFoXDTMwMTAxNzAwMDAwMFow
# TDELMAkGA1UEBhMCVVMxFzAVBgNVBAoTDkRpZ2lDZXJ0LCBJbmMuMSQwIgYDVQQD
# ExtUSU1FU1RBTVAtU0hBMjU2LTIwMTktMTAtMTUwggEiMA0GCSqGSIb3DQEBAQUA
# A4IBDwAwggEKAoIBAQDpZDWc+qmYZWQb5BfcuCk2zGcJWIVNMODJ/+U7PBEoUK8H
# MeJdCRjC9omMaQgEI+B3LZ0V5bjooWqO/9Su0noW7/hBtR05dcHPL6esRX6UbawD
# AZk8Yj5+ev1FlzG0+rfZQj6nVZvfWk9YAqgyaSITvouCLcaYq2ubtMnyZREMdA2y
# 8AiWdMToskiioRSl+PrhiXBEO43v+6T0w7m9FCzrDCgnJYCrEEsWEmALaSKMTs3G
# 1bJlWSHgfCwSjXAOj4rK4NPXszl3UNBCLC56zpxnejh3VED/T5UEINTryM6HFAj+
# HYDd0OcreOq/H3DG7kIWUzZFm1MZSWKdegKblRSjAgMBAAGjggM4MIIDNDAOBgNV
# HQ8BAf8EBAMCB4AwDAYDVR0TAQH/BAIwADAWBgNVHSUBAf8EDDAKBggrBgEFBQcD
# CDCCAb8GA1UdIASCAbYwggGyMIIBoQYJYIZIAYb9bAcBMIIBkjAoBggrBgEFBQcC
# ARYcaHR0cHM6Ly93d3cuZGlnaWNlcnQuY29tL0NQUzCCAWQGCCsGAQUFBwICMIIB
# Vh6CAVIAQQBuAHkAIAB1AHMAZQAgAG8AZgAgAHQAaABpAHMAIABDAGUAcgB0AGkA
# ZgBpAGMAYQB0AGUAIABjAG8AbgBzAHQAaQB0AHUAdABlAHMAIABhAGMAYwBlAHAA
# dABhAG4AYwBlACAAbwBmACAAdABoAGUAIABEAGkAZwBpAEMAZQByAHQAIABDAFAA
# LwBDAFAAUwAgAGEAbgBkACAAdABoAGUAIABSAGUAbAB5AGkAbgBnACAAUABhAHIA
# dAB5ACAAQQBnAHIAZQBlAG0AZQBuAHQAIAB3AGgAaQBjAGgAIABsAGkAbQBpAHQA
# IABsAGkAYQBiAGkAbABpAHQAeQAgAGEAbgBkACAAYQByAGUAIABpAG4AYwBvAHIA
# cABvAHIAYQB0AGUAZAAgAGgAZQByAGUAaQBuACAAYgB5ACAAcgBlAGYAZQByAGUA
# bgBjAGUALjALBglghkgBhv1sAxUwHwYDVR0jBBgwFoAU9LbhIB3+Ka7S5GGlsqIl
# ssgXNW4wHQYDVR0OBBYEFFZTD8HGB6dN19huV3KAUEzk7J7BMHEGA1UdHwRqMGgw
# MqAwoC6GLGh0dHA6Ly9jcmwzLmRpZ2ljZXJ0LmNvbS9zaGEyLWFzc3VyZWQtdHMu
# Y3JsMDKgMKAuhixodHRwOi8vY3JsNC5kaWdpY2VydC5jb20vc2hhMi1hc3N1cmVk
# LXRzLmNybDCBhQYIKwYBBQUHAQEEeTB3MCQGCCsGAQUFBzABhhhodHRwOi8vb2Nz
# cC5kaWdpY2VydC5jb20wTwYIKwYBBQUHMAKGQ2h0dHA6Ly9jYWNlcnRzLmRpZ2lj
# ZXJ0LmNvbS9EaWdpQ2VydFNIQTJBc3N1cmVkSURUaW1lc3RhbXBpbmdDQS5jcnQw
# DQYJKoZIhvcNAQELBQADggEBAC6DoUQFSgTjuTJS+tmB8Bq7+AmNI7k92JKh5kYc
# Si9uejxjbjcXoxq/WCOyQ5yUg045CbAs6Mfh4szty3lrzt4jAUftlVSB4IB7ErGv
# AoapOnNq/vifwY3RIYzkKYLDigtgAAKdH0fEn7QKaFN/WhCm+CLm+FOSMV/YgoMt
# bRNCroPBEE6kJPRHnN4PInJ3XH9P6TmYK1eSRNfvbpPZQ8cEM2NRN1aeRwQRw6NY
# VCHY4o5W10k/V/wKnyNee/SUjd2dGrvfeiqm0kWmVQyP9kyK8pbPiUbcMbKRkKNf
# MzBgVfX8azCsoe3kR04znmdqKLVNwu1bl4L4y6kIbFMJtPcwggUxMIIEGaADAgEC
# AhAKoSXW1jIbfkHkBdo2l8IVMA0GCSqGSIb3DQEBCwUAMGUxCzAJBgNVBAYTAlVT
# MRUwEwYDVQQKEwxEaWdpQ2VydCBJbmMxGTAXBgNVBAsTEHd3dy5kaWdpY2VydC5j
# b20xJDAiBgNVBAMTG0RpZ2lDZXJ0IEFzc3VyZWQgSUQgUm9vdCBDQTAeFw0xNjAx
# MDcxMjAwMDBaFw0zMTAxMDcxMjAwMDBaMHIxCzAJBgNVBAYTAlVTMRUwEwYDVQQK
# EwxEaWdpQ2VydCBJbmMxGTAXBgNVBAsTEHd3dy5kaWdpY2VydC5jb20xMTAvBgNV
# BAMTKERpZ2lDZXJ0IFNIQTIgQXNzdXJlZCBJRCBUaW1lc3RhbXBpbmcgQ0EwggEi
# MA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQC90DLuS82Pf92puoKZxTlUKFe2
# I0rEDgdFM1EQfdD5fU1ofue2oPSNs4jkl79jIZCYvxO8V9PD4X4I1moUADj3Lh47
# 7sym9jJZ/l9lP+Cb6+NGRwYaVX4LJ37AovWg4N4iPw7/fpX786O6Ij4YrBHk8JkD
# bTuFfAnT7l3ImgtU46gJcWvgzyIQD3XPcXJOCq3fQDpct1HhoXkUxk0kIzBdvOw8
# YGqsLwfM/fDqR9mIUF79Zm5WYScpiYRR5oLnRlD9lCosp+R1PrqYD4R/nzEU1q3V
# 8mTLex4F0IQZchfxFwbvPc3WTe8GQv2iUypPhR3EHTyvz9qsEPXdrKzpVv+TAgMB
# AAGjggHOMIIByjAdBgNVHQ4EFgQU9LbhIB3+Ka7S5GGlsqIlssgXNW4wHwYDVR0j
# BBgwFoAUReuir/SSy4IxLVGLp6chnfNtyA8wEgYDVR0TAQH/BAgwBgEB/wIBADAO
# BgNVHQ8BAf8EBAMCAYYwEwYDVR0lBAwwCgYIKwYBBQUHAwgweQYIKwYBBQUHAQEE
# bTBrMCQGCCsGAQUFBzABhhhodHRwOi8vb2NzcC5kaWdpY2VydC5jb20wQwYIKwYB
# BQUHMAKGN2h0dHA6Ly9jYWNlcnRzLmRpZ2ljZXJ0LmNvbS9EaWdpQ2VydEFzc3Vy
# ZWRJRFJvb3RDQS5jcnQwgYEGA1UdHwR6MHgwOqA4oDaGNGh0dHA6Ly9jcmw0LmRp
# Z2ljZXJ0LmNvbS9EaWdpQ2VydEFzc3VyZWRJRFJvb3RDQS5jcmwwOqA4oDaGNGh0
# dHA6Ly9jcmwzLmRpZ2ljZXJ0LmNvbS9EaWdpQ2VydEFzc3VyZWRJRFJvb3RDQS5j
# cmwwUAYDVR0gBEkwRzA4BgpghkgBhv1sAAIEMCowKAYIKwYBBQUHAgEWHGh0dHBz
# Oi8vd3d3LmRpZ2ljZXJ0LmNvbS9DUFMwCwYJYIZIAYb9bAcBMA0GCSqGSIb3DQEB
# CwUAA4IBAQBxlRLpUYdWac3v3dp8qmN6s3jPBjdAhO9LhL/KzwMC/cWnww4gQiyv
# d/MrHwwhWiq3BTQdaq6Z+CeiZr8JqmDfdqQ6kw/4stHYfBli6F6CJR7Euhx7LCHi
# 1lssFDVDBGiy23UC4HLHmNY8ZOUfSBAYX4k4YU1iRiSHY4yRUiyvKYnleB/WCxSl
# gNcSR3CzddWThZN+tpJn+1Nhiaj1a5bA9FhpDXzIAbG5KHW3mWOFIoxhynmUfln8
# jA/jb7UBJrZspe6HUSHkWGCbugwtK22ixH67xCUrRwIIfEmuE7bhfEJCKMYYVs9B
# NLZmXbZ0e/VWMyIvIjayS6JKldj1po5SMYICTTCCAkkCAQEwgYYwcjELMAkGA1UE
# BhMCVVMxFTATBgNVBAoTDERpZ2lDZXJ0IEluYzEZMBcGA1UECxMQd3d3LmRpZ2lj
# ZXJ0LmNvbTExMC8GA1UEAxMoRGlnaUNlcnQgU0hBMiBBc3N1cmVkIElEIFRpbWVz
# dGFtcGluZyBDQQIQBM0/hWiudsYbsP5xYMynbTANBglghkgBZQMEAgEFAKCBmDAa
# BgkqhkiG9w0BCQMxDQYLKoZIhvcNAQkQAQQwHAYJKoZIhvcNAQkFMQ8XDTIwMTAy
# MjAwNDgyOVowKwYLKoZIhvcNAQkQAgwxHDAaMBgwFgQUAyW9UF7aljAtwi9PoB5M
# KL4oNMUwLwYJKoZIhvcNAQkEMSIEICS1S0fa9V3xNv9Bogo3J1TsZU4IEzE1zDvN
# 9mVUMa1VMA0GCSqGSIb3DQEBAQUABIIBAGS4CTYUeKUS84JQ7PTzTgfoJsjgWXvr
# 3egsDiw+q5iYi7eElad9takx0zF0pEsj1PFyhWMhBPw552SCFBJFUh8Gp1FdJVse
# Z4g+pM8YtzNILWydH/0RUFnImS+Ty6jtCjttxNu+plsb+5y+ii7rD1x8I8ICNwdK
# GB0S8IXHYqqo0InZTAMpZk+hTKAQ/VXlFKTOPJ8N1/MUGtc24jgqWhWMdMTjj1M8
# p4PCDx28QbZRr1U7O58b/tQBFmfR2uzNTuZNNcciC2Z3ea0jgJZJ3UKsQsDppCHH
# RTZld+8kb/FZUwXGClwPF47y3yYwSiSGaLxYb9ZP3ju6EEVdbbr+7dM=
# SIG # End signature block
