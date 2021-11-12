# Script to enable a local kiosk user to auto-login
# ***** INTENDED TO BE RUN AS PART OF AN MDT DEPLOYMENT TASK SEQUENCE *****
# 
# Must be done this way because:
#    a). MDT finishes up by removing autologon registry entries via LTICleanup.wsf
#    b). Even waiting for the 'wscript' process to finish (deployment is 100% done) before setting the autologon reg keys is not enough
#    c). After task sequence finishes, unable to connect to deployment share to copy script to local due to Public net profile, so need to write it locally
#    d). I had issues running the .ps1 via task, so instead it runs a .bat that calls the .ps1
#    e). The Kiosk user account will be changed later via RMM, so the plain-text here is fine, I don't want to hear it
#
# There are probably other/better ways to accomplish all of this, but it's after 11:00 PM so tell it to yo momma
#



# Define the PS script to be written to disk
$PSscript = @'
# Script to enable auto-login for Windows systems
# This script calls a re-useable, generic registry check+set function
# Function queries the registry for a given VALUE, located at a given PATH (set in initial variables)
# If the value is found, contents are modified according to specs given
# If the value is not found, it is created



# Clear the error variable
$Error.Clear()



# Wait for the deployment to finish, otherwise the reg keys will not persist
# The script will now run at next startup, but leaving this here due to paranoia and general disappointment in the world
While (Get-Process -Name wscript -ErrorAction SilentlyContinue)
    {
        #Write-Host Deployment is running. Waiting for deployment to finish.
        Start-Sleep -Seconds 5
    }

Write-Host `r`nDeployment has finished. Proceeding with kiosk madness...



# Create the local Kiosk user account 
net user KioskUser "xxxxxxxxxxx"/add /y
net localgroup Administrators KioskUser /add
#net user Administrator /active:no



# Define some initial variables
$registryPath1 = "Microsoft.PowerShell.Core\Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon"
$registryPath2 = "Microsoft.PowerShell.Core\Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\PasswordLess\Device"

# This value sets the auto-logon user name
$regKey1_name = "DefaultUserName"
$regKey1_desiredValue = "KioskUser"
$regKey1_propType = "String"

# This value sets the auto-logon user password
$RegKey2_name = "DefaultPassword"
$regKey2_desiredValue = "xxxxxxxx"
$regKey2_propType = "String"

# This value enables the auto-login
$RegKey3_name = "AutoAdminLogon"
$regKey3_desiredValue = "1"
$regKey3_propType = "String"

# This value allegedly fixes a bug where the auto-login fails with 'incorrect password'
$RegKey4_name = "DevicePasswordLessBuildVersion"
$regKey4_desiredValue = "0"
$regKey4_propType = "Dword"


# Create a log file separator
$separator = "-------------------------------------------"

# Create a log file
$log = "C:\ProgramData\Scripts\kioskSetupError.txt"
if (!($log))
    {
        New-Item -Path $log
    }



# Clear the $Error variable
$Error.Clear()



# Defines the query and edit/add function
Function SetRegistryValue() {

    # Define the string parameters that this function requires
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true,ValueFromPipelineByPropertyName=$true)]
        #[AllowEmptyString()]
        [string]$Path,
        [string]$valueName,
        [string]$desiredValue,
        [ValidateSet('Dword', 'Qword', 'String', 'MultiString', 'ExpandedString', 'Binary', 'Unknown')]
        [string]$propertyType
    )

    try
        {
            # Clear the error variable at each run of the function
            $Error.Clear()

            # Get the reg value's current contents
            $valueContents = Get-ItemProperty -Path $Path -Name $valueName -ErrorAction Stop | Select-Object -ExpandProperty $valueName
            Write-Host Current value: $valueContents

            # Check the reg value contents, and update them if not already set to desired value
            if ($valueContents -ne $desiredValue)
                {
                    Write-Host Setting value to $desiredValue
                    Set-ItemProperty -Path $Path -Name $valueName -Value $desiredValue -ErrorAction SilentlyContinue
                    
                    # Make sure the key's value was properly set by the preceding command
                    $newValueContents = Get-ItemProperty -Path $Path -Name $valueName -ErrorAction Stop | Select-Object -ExpandProperty $valueName
                    if ($newValueContents -eq $desiredValue)
                        {
                            Write-Host New value: $newValueContents. Function was successful.
                            return
                        }
                    else
                        {
                            Write-Warning Unable to set the value of $valueName to $desiredValue
                            Write-Host $Error
                            $Error | Out-File -FilePath $log -Append
                            "`r`n$separator`r`n" | Out-File -FilePath $log -Append
                            return
                        }
                }
            else
                {
                    Write-Host Value is aready set to $desiredValue.
                    return
                }

            exit
        } # End try block

    catch [System.Management.Automation.PSArgumentException]
        {
            # The key does not exist, create it and set the value
            Write-Host The $valueName value was NOT found. Creating it now...

            # Add the key/value
            Try
                {
                    New-ItemProperty -Path $Path -Name $valueName -Value $desiredValue -PropertyType $propertyType -ErrorAction SilentlyContinue
                    Write-Host Added $valueName to the registry and set its value to $desiredValue
                    return
                }
            Catch
                {
                    Write-Host Unable to add the $valueName key!
                    Write-Host $Error
                    $Error | Out-File -FilePath $log -Append
                    "`r`n$separator`r`n" | Out-File -FilePath $log -Append
                    return
                }

            Write-Host

            return
        }

    catch [System.Management.Automation.ItemNotFoundException]
        {
            $messageINF = "The query failed. Double-check your REGISTRY PATH input."
            Write-Host $messageINF
            $messageINF | Out-File -FilePath $log -Append
            "`r`n$separator`r`n" | Out-File -FilePath $log -Append
            return
        }

    catch
        {
            Write-Host `r`nSomething terrible happened while executing the registry query.
            Write-Host Specific exception type: $Error[0].Exception.GetType().FullName
            Write-Host $Error `r`n
            $Error | Out-File -FilePath $log -Append
            "`r`n$separator`r`n" | Out-File -FilePath $log -Append
            return
        }

} # End function SetRegistryValue



# Execute the query functions, using the expanded variables as parameters
SetRegistryValue -Path $registryPath1 -valueName $regKey1_name -desiredValue $regKey1_desiredValue -propertyType $regKey1_propType
SetRegistryValue -Path $registryPath1 -valueName $regKey2_name -desiredValue $regKey2_desiredValue -propertyType $regKey2_propType
SetRegistryValue -Path $registryPath1 -valueName $regKey3_name -desiredValue $regKey3_desiredValue -propertyType $regKey3_propType
SetRegistryValue -Path $registryPath2 -valueName $regKey4_name -desiredValue $regKey4_desiredValue -propertyType $regKey4_propType


if (!($Error))
    {
        Start-Sleep -Seconds 30
        Write-Host All good. Restarting...
        #pause
        #Unregister-ScheduledTask -TaskName "EnableKioskAdmin"
        schTasks /change /disable /TN "EnableKioskAdmin"
        Remove-Item -Path "C:\ProgramData\Scripts\Enable-KioskAutoLogon.ps1" -Force
        Restart-Computer -Force
    }
else
    {
        #$Error | Out-File -FilePath C:\ProgramData\kioskSetupError.txt -Encoding UTF8
        $Error | Out-File -FilePath $log -Append
        "`r`n$separator`r`n" | Out-File -FilePath $log -Append
        exit
    }

'@



$BATscript = @'
C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "C:\ProgramData\Scripts\Enable-KioskAutoLogon.ps1"  1>C:\ProgramData\Scripts\enable-kiosk-task.log 2>&1
schTasks /change /disable /TN "EnableKioskAdmin"
'@



# Local path where the PS and BAT scripts will be written
$localPSFilePath = "C:\ProgramData\Scripts\Enable-KioskAutoLogon.ps1"
$localCmdFilePath = "C:\ProgramData\Scripts\enable-kiosk.bat"



# Create the PS script
Try
    {
        # Create the script
        $Error.Clear()
        Set-Content -Path $localPSFilePath -Value $PSscript -Encoding ascii

        # Verify
        if ($localPSFilePath)
            {
                Write-Host Finished `'write PS script`' task.
            }
        else
            {
                Write-Host No exception was encountered, but the `'write PS script`' task has failed.
                Exit
            }
    }

Catch
    {
        Write-Host An exception was encountered in the `'write ps script`' task.
        Write-Host Detail: $Error
        exit
    }



# Create the BAT script
Try
    {
        # Create the script
        $Error.Clear()
        $BATscript | Out-File -FilePath $localCmdFilePath -Encoding ascii

        # Verify
        if ($localCmdFilePath)
            {
                Write-Host Finished `'write BAT script`' task.
            }
        else
            {
                Write-Host No exception was encountered, but the `'write BAT script`' task has failed.
                Exit
            }
    }

Catch
    {
        Write-Host An exception was encountered in the `'write BAT script`' task.
        Write-Host Detail: $Error
        exit
    }




# create scheduled task to execute .ps1 after deployment finishes, and then reboot
# First define the task parameters
$action = New-ScheduledTaskAction -Execute cmd.exe -Argument "/c $localCmdFilePath"
#$runTime = (Get-Date).AddMinutes(2)
$taskTrigger = New-ScheduledTaskTrigger -AtStartup


# Register the scheduled task
Register-ScheduledTask -Action $action -Trigger $taskTrigger `
 -TaskName "EnableKioskAdmin" `
 -Description "Enable KioskAdmin auto-login"`
 -User "System" -RunLevel Highest


# Before exiting, enable task history for later troubleshooting in addition to the log files
$logName = 'Microsoft-Windows-TaskScheduler/Operational'
$log = New-Object System.Diagnostics.Eventing.Reader.EventLogConfiguration $logName
$log.IsEnabled=$true
$log.SaveChanges()
