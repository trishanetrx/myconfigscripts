# Initialize arrays to store the results
$successfullyChangedVms = @()
$failedVms = @()

# Get all VMs in the subscription (both Windows and Linux)
$vms = az vm list --output json | ConvertFrom-Json

# Display a numbered list of VMs
Write-Host "Select the VMs to update by entering the corresponding numbers (comma-separated):"
for ($i = 0; $i -lt $vms.Count; $i++) {
    $vmName = $vms[$i].name
    Write-Host "$($i+1). $vmName"
}

# Get the user input for VM selection
$vmNumbers = Read-Host "Enter the numbers of the VMs to update, separated by commas"

# Convert the user input into an array of selected VM indices
$selectedVmIndices = $vmNumbers -split ',' | ForEach-Object { ($_ -as [int]) - 1 }

# Loop through the selected VMs
foreach ($index in $selectedVmIndices) {
    if ($index -lt 0 -or $index -ge $vms.Count) {
        Write-Host "Invalid VM number: $($index + 1). Skipping..."
        continue
    }

    $vm = $vms[$index]
    $vmName = $vm.name
    $resourceGroupName = $vm.resourceGroup
    $osType = $vm.storageProfile.osDisk.osType
    Write-Host "Checking VM: $vmName (OS: $osType) in Resource Group: $resourceGroupName"

    try {
        # Get the current patch settings for the VM
        if ($osType -eq "Windows") {
            $currentPatchSettings = az vm show `
              --resource-group $resourceGroupName `
              --name $vmName `
              --query "osProfile.windowsConfiguration.patchSettings" `
              --output json
        } elseif ($osType -eq "Linux") {
            $currentPatchSettings = az vm show `
              --resource-group $resourceGroupName `
              --name $vmName `
              --query "osProfile.linuxConfiguration.patchSettings" `
              --output json
        }

        if ($currentPatchSettings -ne $null) {
            $patchSettings = $currentPatchSettings | ConvertFrom-Json

            if ($patchSettings.patchMode -ne "AutomaticByPlatform" -or $patchSettings.assessmentMode -ne "AutomaticByPlatform") {
                Write-Host "VM $vmName does not have patchMode or assessmentMode set to AutomaticByPlatform. Updating..."

                # Remove the existing patch settings based on the OS type
                if ($osType -eq "Windows") {
                    az vm update `
                      --resource-group $resourceGroupName `
                      --name $vmName `
                      --remove osProfile.windowsConfiguration.patchSettings
                } elseif ($osType -eq "Linux") {
                    az vm update `
                      --resource-group $resourceGroupName `
                      --name $vmName `
                      --remove osProfile.linuxConfiguration.patchSettings
                }

                # Set patchMode to AutomaticByPlatform and assessmentMode to AutomaticByPlatform
                if ($osType -eq "Windows") {
                    az vm update `
                      --resource-group $resourceGroupName `
                      --name $vmName `
                      --set osProfile.windowsConfiguration.patchSettings.patchMode=AutomaticByPlatform `
                      --set osProfile.windowsConfiguration.patchSettings.assessmentMode=AutomaticByPlatform
                } elseif ($osType -eq "Linux") {
                    az vm update `
                      --resource-group $resourceGroupName `
                      --name $vmName `
                      --set osProfile.linuxConfiguration.patchSettings.patchMode=AutomaticByPlatform `
                      --set osProfile.linuxConfiguration.patchSettings.assessmentMode=AutomaticByPlatform
                }

                Write-Host "Patch settings updated to AutomaticByPlatform for VM: $vmName"
                $successfullyChangedVms += $vmName
            } else {
                Write-Host "No change needed for VM: $vmName. Settings are already correct."
            }
        } else {
            Write-Host "No patch settings found for VM: $vmName. Setting to AutomaticByPlatform..."

            # Set patchMode to AutomaticByPlatform and assessmentMode to AutomaticByPlatform if no patch settings exist
            if ($osType -eq "Windows") {
                az vm update `
                  --resource-group $resourceGroupName `
                  --name $vmName `
                  --set osProfile.windowsConfiguration.patchSettings.patchMode=AutomaticByPlatform `
                  --set osProfile.windowsConfiguration.patchSettings.assessmentMode=AutomaticByPlatform
            } elseif ($osType -eq "Linux") {
                az vm update `
                  --resource-group $resourceGroupName `
                  --name $vmName `
                  --set osProfile.linuxConfiguration.patchSettings.patchMode=AutomaticByPlatform `
                  --set osProfile.linuxConfiguration.patchSettings.assessmentMode=AutomaticByPlatform
            }

            Write-Host "Patch settings updated to AutomaticByPlatform for VM: $vmName"
            $successfullyChangedVms += $vmName
        }
    } catch {
        Write-Host "Failed to update VM: $vmName in Resource Group: $resourceGroupName. Error: $_"
        $failedVms += $vmName
    }
}

# Output the results
Write-Host "`nSummary:"
Write-Host "--------------------------"
Write-Host "Successfully Changed VMs:"
$successfullyChangedVms | ForEach-Object { Write-Host $_ }

Write-Host "`nFailed VMs:"
$failedVms | ForEach-Object { Write-Host $_ }
