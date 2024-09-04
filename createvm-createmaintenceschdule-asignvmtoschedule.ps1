# Azure VM and Maintenance Automation Script

# Function to create a VM
function Create-VM {
    param (
        [string]$vmName,
        [string]$vmType,  # windows or linux
        [string]$location
    )

    # Set default VM settings
    $resourceGroup = "my-test-resource-group"
    $vmSize = "Standard_B1ls"
    $adminUsername = "trishane"
    $adminPassword = "Power231*123"
    $vnetName = "myVnet"
    $subnetName = "default"
    $nsg = ""
    $patchMode = "AutomaticByPlatform"
    $assessmentMode = "AutomaticByPlatform"  # New setting

    if ($vmType -eq "windows") {
        $image = "MicrosoftWindowsServer:WindowsServer:2019-Datacenter:latest"
        # Create the Windows VM with both patchMode and assessmentMode set to AutomaticByPlatform
        az vm create --resource-group $resourceGroup --name $vmName --image $image --size $vmSize --admin-username $adminUsername --admin-password $adminPassword --vnet-name $vnetName --subnet $subnetName --nsg $nsg --enable-agent --patch-mode $patchMode --location $location

        # Set the assessment mode for the created Windows VM
        $vm = Get-AzVM -ResourceGroupName $resourceGroup -Name $vmName
        $vm.OsProfile.WindowsConfiguration.PatchSettings.AssessmentMode = $assessmentMode
        Update-AzVM -ResourceGroupName $resourceGroup -VM $vm
    } elseif ($vmType -eq "linux") {
        $image = "Canonical:UbuntuServer:18.04-LTS:latest"
        # Create the Linux VM with both patchMode and assessmentMode set to AutomaticByPlatform
        az vm create --resource-group $resourceGroup --name $vmName --image $image --size $vmSize --admin-username $adminUsername --authentication-type password --admin-password $adminPassword --vnet-name $vnetName --subnet $subnetName --nsg $nsg --enable-agent --patch-mode $patchMode --location $location

        # No assessment mode setting needed for Linux VM as Windows-specific
    } else {
        Write-Host "Invalid VM type specified."
    }
}

# Function to create a maintenance schedule
function Create-MaintenanceSchedule {
    param (
        [string]$scheduleName,
        [string]$location,
        [string]$maintenanceScope # Valid values: Extension, Host, InGuestPatch, OSImage, Resource, SQLDB, SQLManagedInstance
    )

    $resourceGroup = "my-test-resource-group"
    $recurrence = "1day"
    $startDateTime = "2024-09-04 00:00"
    $timeZone = "Sri Lanka Standard Time"
    
    az maintenance configuration create --resource-group $resourceGroup --name $scheduleName --location $location --maintenance-scope $maintenanceScope --recur-every $recurrence --start-date-time $startDateTime --time-zone $timeZone --extension-properties "{'InGuestPatchMode':'Platform'}"
}

# Function to assign a VM to a maintenance schedule
function Assign-MaintenanceSchedule {
    param (
        [string]$vmName,
        [string]$scheduleName
    )

    $resourceGroup = "my-test-resource-group"

    # Get the subscription ID dynamically
    $subscriptionId = (Get-AzContext).Subscription.Id
    $maintenanceConfigId = "/subscriptions/$subscriptionId/resourceGroups/$resourceGroup/providers/Microsoft.Maintenance/maintenanceConfigurations/$scheduleName"

    az maintenance assignment create --resource-group $resourceGroup --resource-type virtualMachines --resource-name $vmName --provider-name Microsoft.Compute --configuration-assignment-name "myMaintenanceAssignment" --maintenance-configuration-id $maintenanceConfigId
}

# Main script loop
do {
    Write-Host "`nSelect an action:"
    Write-Host "1. Create VM"
    Write-Host "2. Create Maintenance Schedule"
    Write-Host "3. Assign VM to Maintenance Schedule"
    Write-Host "4. Exit"

    $action = Read-Host "Enter the number corresponding to your choice"

    switch ($action) {
        "1" {
            $vmName = Read-Host "Enter the VM name"
            $vmTypeNumber = Read-Host "Enter the VM type: 1 for Windows, 2 for Linux"
            if ($vmTypeNumber -eq "1") {
                $vmType = "windows"
            } elseif ($vmTypeNumber -eq "2") {
                $vmType = "linux"
            } else {
                Write-Host "Invalid VM type specified. Please enter 1 for Windows or 2 for Linux."
                continue
            }
            $location = Read-Host "Enter the location (e.g., westus)"
            Create-VM -vmName $vmName -vmType $vmType -location $location
        }
        "2" {
            $scheduleName = Read-Host "Enter the maintenance schedule name"
            $location = Read-Host "Enter the location (e.g., eastus)"
            Write-Host "Select the maintenance scope:"
            Write-Host "1. Extension"
            Write-Host "2. Host"
            Write-Host "3. InGuestPatch"
            Write-Host "4. OSImage"
            Write-Host "5. Resource"
            Write-Host "6. SQLDB"
            Write-Host "7. SQLManagedInstance"
            $maintenanceScopeNumber = Read-Host "Enter the number corresponding to your choice"
            switch ($maintenanceScopeNumber) {
                "1" { $maintenanceScope = "Extension" }
                "2" { $maintenanceScope = "Host" }
                "3" { $maintenanceScope = "InGuestPatch" }
                "4" { $maintenanceScope = "OSImage" }
                "5" { $maintenanceScope = "Resource" }
                "6" { $maintenanceScope = "SQLDB" }
                "7" { $maintenanceScope = "SQLManagedInstance" }
                default { 
                    Write-Host "Invalid maintenance scope specified."
                    continue
                }
            }
            Create-MaintenanceSchedule -scheduleName $scheduleName -location $location -maintenanceScope $maintenanceScope
        }
        "3" {
            $vmName = Read-Host "Enter the VM name to assign"
            $scheduleName = Read-Host "Enter the maintenance schedule name"
            Assign-MaintenanceSchedule -vmName $vmName -scheduleName $scheduleName
        }
        "4" {
            Write-Host "Exiting script."
            break
        }
        default {
            Write-Host "Invalid action specified."
        }
    }

    Write-Host "`nAction completed. What would you like to do next?"

} while ($action -ne "4")

Write-Host "Script execution completed."
