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

$INITIAL_DISCOVERY_SCRIPT_REGEX = '(?s)<ScriptName>PureStorage\.FlashArray\.PureArray\.Discovery\.ps1</ScriptName>.*?<ScriptBody>(?<script>.*?)</ScriptBody>'
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
# MIIfAAYJKoZIhvcNAQcCoIIe8TCCHu0CAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCB/Z8e/904C4VNb
# uLnnlcudBTWTbyxwdiMMPJnjbOWJOaCCCm8wggUwMIIEGKADAgECAhAECRgbX9W7
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
# ttzr3pjfmVQBMYIT5zCCE+MCAQEwgYYwcjELMAkGA1UEBhMCVVMxFTATBgNVBAoT
# DERpZ2lDZXJ0IEluYzEZMBcGA1UECxMQd3d3LmRpZ2ljZXJ0LmNvbTExMC8GA1UE
# AxMoRGlnaUNlcnQgU0hBMiBBc3N1cmVkIElEIENvZGUgU2lnbmluZyBDQQIQC4jZ
# Oitkx57ksuMgsWXX0jANBglghkgBZQMEAgEFAKB8MBAGCisGAQQBgjcCAQwxAjAA
# MBkGCSqGSIb3DQEJAzEMBgorBgEEAYI3AgEEMBwGCisGAQQBgjcCAQsxDjAMBgor
# BgEEAYI3AgEVMC8GCSqGSIb3DQEJBDEiBCD3RkI8mc0GdJSmG3EIaOv3PB2GX4/Z
# qMkXoO5w26UuVjANBgkqhkiG9w0BAQEFAASCAQBn8ATSSAclWeiGyaNTUv8cVzjT
# +WS/pjh4IEkIr4xPcJ2wWIjAeHaH04TXEMG4g1vphv6v9HBMAylAxEXmoUgAUXdu
# L/wNSRmfAOH+CoUhSmL6sz8VZ2tlEQ3cIukBIILDgSMHbYdWaYKItO8g2oCVt2dP
# WIdIbj+lWOcrhSlq4c1qSIED/H7bw86FLpV4pBn9Q0A7OpKuNcWNzQvxTjTYRAlk
# 7kLsQQiHrSBJdkNGWT+QOzsA/e0xUiOHx2uX7jrSx7OjVVbfF0AB2AmM+qkF6dx9
# e6zjpwPIkvGpWIYmk26MCk+6U3KvNlvNXLuqcomvJxYD8Q4uP4wkKoM5JjbUoYIR
# szCCEa8GCisGAQQBgjcDAwExghGfMIIRmwYJKoZIhvcNAQcCoIIRjDCCEYgCAQMx
# DzANBglghkgBZQMEAgEFADB4BgsqhkiG9w0BCRABBKBpBGcwZQIBAQYJYIZIAYb9
# bAcBMDEwDQYJYIZIAWUDBAIBBQAEIH82oUvZvIRQ75ZhEZtixApnrLHqDRti0gvD
# JEHheBRyAhEA75C73lBzOqLE7ag6wfgo6RgPMjAyMjA1MTIyMTI5NDJaoIINfDCC
# BsYwggSuoAMCAQICEAp6SoieyZlCkAZjOE2Gl50wDQYJKoZIhvcNAQELBQAwYzEL
# MAkGA1UEBhMCVVMxFzAVBgNVBAoTDkRpZ2lDZXJ0LCBJbmMuMTswOQYDVQQDEzJE
# aWdpQ2VydCBUcnVzdGVkIEc0IFJTQTQwOTYgU0hBMjU2IFRpbWVTdGFtcGluZyBD
# QTAeFw0yMjAzMjkwMDAwMDBaFw0zMzAzMTQyMzU5NTlaMEwxCzAJBgNVBAYTAlVT
# MRcwFQYDVQQKEw5EaWdpQ2VydCwgSW5jLjEkMCIGA1UEAxMbRGlnaUNlcnQgVGlt
# ZXN0YW1wIDIwMjIgLSAyMIICIjANBgkqhkiG9w0BAQEFAAOCAg8AMIICCgKCAgEA
# uSqWI6ZcvF/WSfAVghj0M+7MXGzj4CUu0jHkPECu+6vE43hdflw26vUljUOjges4
# Y/k8iGnePNIwUQ0xB7pGbumjS0joiUF/DbLW+YTxmD4LvwqEEnFsoWImAdPOw2z9
# rDt+3Cocqb0wxhbY2rzrsvGD0Z/NCcW5QWpFQiNBWvhg02UsPn5evZan8Pyx9PQo
# z0J5HzvHkwdoaOVENFJfD1De1FksRHTAMkcZW+KYLo/Qyj//xmfPPJOVToTpdhiY
# mREUxSsMoDPbTSSF6IKU4S8D7n+FAsmG4dUYFLcERfPgOL2ivXpxmOwV5/0u7NKb
# AIqsHY07gGj+0FmYJs7g7a5/KC7CnuALS8gI0TK7g/ojPNn/0oy790Mj3+fDWgVi
# fnAs5SuyPWPqyK6BIGtDich+X7Aa3Rm9n3RBCq+5jgnTdKEvsFR2wZBPlOyGYf/b
# ES+SAzDOMLeLD11Es0MdI1DNkdcvnfv8zbHBp8QOxO9APhk6AtQxqWmgSfl14Zvo
# aORqDI/r5LEhe4ZnWH5/H+gr5BSyFtaBocraMJBr7m91wLA2JrIIO/+9vn9sExjf
# xm2keUmti39hhwVo99Rw40KV6J67m0uy4rZBPeevpxooya1hsKBBGBlO7UebYZXt
# PgthWuo+epiSUc0/yUTngIspQnL3ebLdhOon7v59emsCAwEAAaOCAYswggGHMA4G
# A1UdDwEB/wQEAwIHgDAMBgNVHRMBAf8EAjAAMBYGA1UdJQEB/wQMMAoGCCsGAQUF
# BwMIMCAGA1UdIAQZMBcwCAYGZ4EMAQQCMAsGCWCGSAGG/WwHATAfBgNVHSMEGDAW
# gBS6FtltTYUvcyl2mi91jGogj57IbzAdBgNVHQ4EFgQUjWS3iSH+VlhEhGGn6m8c
# No/drw0wWgYDVR0fBFMwUTBPoE2gS4ZJaHR0cDovL2NybDMuZGlnaWNlcnQuY29t
# L0RpZ2lDZXJ0VHJ1c3RlZEc0UlNBNDA5NlNIQTI1NlRpbWVTdGFtcGluZ0NBLmNy
# bDCBkAYIKwYBBQUHAQEEgYMwgYAwJAYIKwYBBQUHMAGGGGh0dHA6Ly9vY3NwLmRp
# Z2ljZXJ0LmNvbTBYBggrBgEFBQcwAoZMaHR0cDovL2NhY2VydHMuZGlnaWNlcnQu
# Y29tL0RpZ2lDZXJ0VHJ1c3RlZEc0UlNBNDA5NlNIQTI1NlRpbWVTdGFtcGluZ0NB
# LmNydDANBgkqhkiG9w0BAQsFAAOCAgEADS0jdKbR9fjqS5k/AeT2DOSvFp3Zs4yX
# gimcQ28BLas4tXARv4QZiz9d5YZPvpM63io5WjlO2IRZpbwbmKrobO/RSGkZOFvP
# iTkdcHDZTt8jImzV3/ZZy6HC6kx2yqHcoSuWuJtVqRprfdH1AglPgtalc4jEmIDf
# 7kmVt7PMxafuDuHvHjiKn+8RyTFKWLbfOHzL+lz35FO/bgp8ftfemNUpZYkPopzA
# ZfQBImXH6l50pls1klB89Bemh2RPPkaJFmMga8vye9A140pwSKm25x1gvQQiFSVw
# BnKpRDtpRxHT7unHoD5PELkwNuTzqmkJqIt+ZKJllBH7bjLx9bs4rc3AkxHVMnhK
# SzcqTPNc3LaFwLtwMFV41pj+VG1/calIGnjdRncuG3rAM4r4SiiMEqhzzy350yPy
# nhngDZQooOvbGlGglYKOKGukzp123qlzqkhqWUOuX+r4DwZCnd8GaJb+KqB0W2Nm
# 3mssuHiqTXBt8CzxBxV+NbTmtQyimaXXFWs1DoXW4CzM4AwkuHxSCx6ZfO/IyMWM
# WGmvqz3hz8x9Fa4Uv4px38qXsdhH6hyF4EVOEhwUKVjMb9N/y77BDkpvIJyu2XMy
# WQjnLZKhGhH+MpimXSuX4IvTnMxttQ2uR2M4RxdbbxPaahBuH0m3RFu0CAqHWlkE
# dhGhp3cCExwwggauMIIElqADAgECAhAHNje3JFR82Ees/ShmKl5bMA0GCSqGSIb3
# DQEBCwUAMGIxCzAJBgNVBAYTAlVTMRUwEwYDVQQKEwxEaWdpQ2VydCBJbmMxGTAX
# BgNVBAsTEHd3dy5kaWdpY2VydC5jb20xITAfBgNVBAMTGERpZ2lDZXJ0IFRydXN0
# ZWQgUm9vdCBHNDAeFw0yMjAzMjMwMDAwMDBaFw0zNzAzMjIyMzU5NTlaMGMxCzAJ
# BgNVBAYTAlVTMRcwFQYDVQQKEw5EaWdpQ2VydCwgSW5jLjE7MDkGA1UEAxMyRGln
# aUNlcnQgVHJ1c3RlZCBHNCBSU0E0MDk2IFNIQTI1NiBUaW1lU3RhbXBpbmcgQ0Ew
# ggIiMA0GCSqGSIb3DQEBAQUAA4ICDwAwggIKAoICAQDGhjUGSbPBPXJJUVXHJQPE
# 8pE3qZdRodbSg9GeTKJtoLDMg/la9hGhRBVCX6SI82j6ffOciQt/nR+eDzMfUBML
# JnOWbfhXqAJ9/UO0hNoR8XOxs+4rgISKIhjf69o9xBd/qxkrPkLcZ47qUT3w1lbU
# 5ygt69OxtXXnHwZljZQp09nsad/ZkIdGAHvbREGJ3HxqV3rwN3mfXazL6IRktFLy
# dkf3YYMZ3V+0VAshaG43IbtArF+y3kp9zvU5EmfvDqVjbOSmxR3NNg1c1eYbqMFk
# dECnwHLFuk4fsbVYTXn+149zk6wsOeKlSNbwsDETqVcplicu9Yemj052FVUmcJgm
# f6AaRyBD40NjgHt1biclkJg6OBGz9vae5jtb7IHeIhTZgirHkr+g3uM+onP65x9a
# bJTyUpURK1h0QCirc0PO30qhHGs4xSnzyqqWc0Jon7ZGs506o9UD4L/wojzKQtwY
# SH8UNM/STKvvmz3+DrhkKvp1KCRB7UK/BZxmSVJQ9FHzNklNiyDSLFc1eSuo80Vg
# vCONWPfcYd6T/jnA+bIwpUzX6ZhKWD7TA4j+s4/TXkt2ElGTyYwMO1uKIqjBJgj5
# FBASA31fI7tk42PgpuE+9sJ0sj8eCXbsq11GdeJgo1gJASgADoRU7s7pXcheMBK9
# Rp6103a50g5rmQzSM7TNsQIDAQABo4IBXTCCAVkwEgYDVR0TAQH/BAgwBgEB/wIB
# ADAdBgNVHQ4EFgQUuhbZbU2FL3MpdpovdYxqII+eyG8wHwYDVR0jBBgwFoAU7Nfj
# gtJxXWRM3y5nP+e6mK4cD08wDgYDVR0PAQH/BAQDAgGGMBMGA1UdJQQMMAoGCCsG
# AQUFBwMIMHcGCCsGAQUFBwEBBGswaTAkBggrBgEFBQcwAYYYaHR0cDovL29jc3Au
# ZGlnaWNlcnQuY29tMEEGCCsGAQUFBzAChjVodHRwOi8vY2FjZXJ0cy5kaWdpY2Vy
# dC5jb20vRGlnaUNlcnRUcnVzdGVkUm9vdEc0LmNydDBDBgNVHR8EPDA6MDigNqA0
# hjJodHRwOi8vY3JsMy5kaWdpY2VydC5jb20vRGlnaUNlcnRUcnVzdGVkUm9vdEc0
# LmNybDAgBgNVHSAEGTAXMAgGBmeBDAEEAjALBglghkgBhv1sBwEwDQYJKoZIhvcN
# AQELBQADggIBAH1ZjsCTtm+YqUQiAX5m1tghQuGwGC4QTRPPMFPOvxj7x1Bd4ksp
# +3CKDaopafxpwc8dB+k+YMjYC+VcW9dth/qEICU0MWfNthKWb8RQTGIdDAiCqBa9
# qVbPFXONASIlzpVpP0d3+3J0FNf/q0+KLHqrhc1DX+1gtqpPkWaeLJ7giqzl/Yy8
# ZCaHbJK9nXzQcAp876i8dU+6WvepELJd6f8oVInw1YpxdmXazPByoyP6wCeCRK6Z
# JxurJB4mwbfeKuv2nrF5mYGjVoarCkXJ38SNoOeY+/umnXKvxMfBwWpx2cYTgAnE
# tp/Nh4cku0+jSbl3ZpHxcpzpSwJSpzd+k1OsOx0ISQ+UzTl63f8lY5knLD0/a6fx
# ZsNBzU+2QJshIUDQtxMkzdwdeDrknq3lNHGS1yZr5Dhzq6YBT70/O3itTK37xJV7
# 7QpfMzmHQXh6OOmc4d0j/R0o08f56PGYX/sr2H7yRp11LB4nLCbbbxV7HhmLNriT
# 1ObyF5lZynDwN7+YAN8gFk8n+2BnFqFmut1VwDophrCYoCvtlUG3OtUVmDG0YgkP
# Cr2B2RP+v6TR81fZvAT6gt4y3wSJ8ADNXcL50CN/AAvkdgIm2fBldkKmKYcJRyvm
# fxqkhQ/8mJb2VVQrH4D6wPIOK+XW+6kvRBVK5xMOHds3OBqhK/bt1nz8MYIDdjCC
# A3ICAQEwdzBjMQswCQYDVQQGEwJVUzEXMBUGA1UEChMORGlnaUNlcnQsIEluYy4x
# OzA5BgNVBAMTMkRpZ2lDZXJ0IFRydXN0ZWQgRzQgUlNBNDA5NiBTSEEyNTYgVGlt
# ZVN0YW1waW5nIENBAhAKekqInsmZQpAGYzhNhpedMA0GCWCGSAFlAwQCAQUAoIHR
# MBoGCSqGSIb3DQEJAzENBgsqhkiG9w0BCRABBDAcBgkqhkiG9w0BCQUxDxcNMjIw
# NTEyMjEyOTQyWjArBgsqhkiG9w0BCRACDDEcMBowGDAWBBSFCPOGUVyz0wd9trS3
# wH8bSl5B3jAvBgkqhkiG9w0BCQQxIgQgJ5+j1rIsqer0cYpoYxiIys3qUy+s+tCy
# HjPNynOZ14AwNwYLKoZIhvcNAQkQAi8xKDAmMCQwIgQgnaaQFcNJxsGJeEW6NYKt
# cMiPpCk722q+nCvSU5J55jswDQYJKoZIhvcNAQEBBQAEggIAOWjmlh3NHz8vAveg
# 8tMTfG4UbvNnaLSXV1hifsPQKZ0nUvtEPobNb3rxnlDxpdq06J6dImCQuqPZ1Rbc
# nBkyAW6ut33MSGU6AfFs5f9kQgEHVRMkdVTyCf/pxAgV/N9Ho9B7bDLcoOOzTq3L
# Hz5IVSfFABV42TyMdK7/+4iEzL62SjyP+HTjFcxcX7X/XIXVbPdVzcgDO9bTJIwP
# WTJIoaUYE5X7xqSIUk9gsvVKS/zlO3GLJVEpzOqw3rtneyLJ05eVd3uBANgLJONt
# 45QOdh+P07/KaR5YXNAEMB/iGHm36GSqz1DLdVAr4WSq0vsn2+4xsbNgQyy8D3lD
# HSuwiEoJWsXnH0G3mn5X4YkAQDGrGxSPTHUObQMpupemwuqiLm3SOJMGtq+FtThd
# 6pmIXvIx4dpUpcuNSJMotFEcXF1vJtxzkN8JJqEqE526AUXWLfxnGjNYjU8yiYKB
# h0mLLdkjZcxLB6e7YDohldZTp+JLnke9uy8/jxoudhs3fROvKwhiZtqNecldS4My
# 8zvRx+1/9jWRn3V/2pN6R16/DZexeD+vuA+c8toe1Z9v9WxQPOgH9PSZDqEd/hMv
# QcMYwuKPV6wqsOC43icbIrtOeu/brxhW3NFUIijoWdQ4HcG89V948WxLRs7FcDmC
# jP7AHrrYrqfqQmp7F+kYWuy4hrs=
# SIG # End signature block
