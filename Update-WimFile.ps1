# This script updates a .wim file to prep it for import into MDT
# Define/update the paths to relevant files below
# Download cumulative updates from https://www.catalog.update.microsoft.com/Home.aspx



# Define paths to custom .wim folder, temporary mount folder, and ISOs folder
$wimDir = "E:\Path\To\Wims\Directory"
$mountDir = "E:\Path\To\Empty\MountDirectory"
#$isoDir = "E:\ISOs"
$updatesFolder = "E:\Path\To\Folder\Containing\msuFiles"
$dismPath = "C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\Deployment Tools\amd64\DISM"


#Define the name of the .wim file we want to modify
$wimFile = "W10_pro_xxxx.wim"


# Get the .wim file image indexes
[int[]] $indexes = get-windowsimage -ImagePath "$wimDir\$wimFile" | Select -ExpandProperty ImageIndex


# Loop through the image indexes and make changes to all of them
foreach ($index in $indexes)
    {
        # Update the user as to the progress
        Write-Host Updating $wimFile at index: $index `r`n


        # Mount the .wim
        Mount-WindowsImage -Path $mountDir -ImagePath $wimDir\$wimFile -Index $index | Out-Null

        # Enable .NET 3.5 for Automate agent - assumes an .iso is mounted to F:
        Write-Host Enabling .NET 3.5
        DISM /Image:E:\WIM-Update\Mount /Enable-Feature /FeatureName:NetFx3 /All /LimitAccess /Source:F:\sources\sxs

        Write-Host Applying Windows Updates...
        #Copy and paste this line below, updating for each .msu file (I had trouble looping this)
        Start-Process "$dismPath\dism.exe" -ArgumentList '/Add-Package /Image:"$mountDir" /Packagepath:"$updatesFolder\kb5004945.msu"' -Wait -NoNewWindow | Out-Null

        Write-Host Making sure MyOrg folders are present...
        # Make sure the your custom folders are present
        if (!(Test-Path $mountDir\ProgramData\MyOrg))
            {
                mkdir $mountDir\ProgramData\MyOrg | Out-Null
                mkdir $mountDir\ProgramData\MyOrg\Apps | Out-Null
                mkdir $mountDir\ProgramData\MyOrg\Scripts | Out-Null
            }


        #### Experimental section, not used but don't want to delete just yet ####
        <#
        # Update the DSC startup config (will overwrite if exists)
        Write-Host Copying over the DSC startup config...`r`n
        #Copy-Item -Path $wimDir\AutomationFiles\MyOrg\Pending.mof -Destination $mountDir\Windows\System32\Configuration\Pending.mof -Force | Out-Null
        if (Test-Path $mountDir\Windows\System32\Configuration\Pending.mof)
            {
                Remove-Item -Path $mountDir\Windows\System32\Configuration\Pending.mof -Force | Out-Null
            }
        #>


        # Copy over ISOs (Comment out if not needed)
        #if (!(Test-Path $mountDir\ISOs)) {mkdir $mountDir\ISOs}
        #Copy-Item -Path $isoDir\2012R2-vmguest.iso -Destination $mountDir\ISOs\2012R2-vmguest.iso -Force | Out-Null
        #Copy-Item -Path $isoDir\pmagic_2015_05_04.iso -Destination $mountDir\ISOs\pmagic_2015_05_04.iso -Force | Out-Null
        #Copy-Item -Path $isoDir\ShadowProtectRE_v5_wLSI.iso -Destination $mountDir\ISOs\ShadowProtectRE_v5_wLSI.iso -Force | Out-Null


        # Commit changes and unmount
        Write-Host Done! Committing changes to $wimFile at index: $index `r`n
        dism /commit-image /MountDir:$mountDir /CheckIntegrity | Out-Null
        dism /unmount-wim /mountdir:$mountDir /Commit | Out-Null

    } # End foreach



# Finish up - if there are remnants left over afterwards, use "dism /cleanup-wim" to remove them
Write-Host Finished updating $wimFile `r`n
pause

