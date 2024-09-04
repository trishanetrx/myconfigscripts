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

# Function to list VMs and assign a VM to a maintenance schedule
function Assign-MaintenanceSchedule {
    param (
        [string]$subscriptionId,
        [string]$scheduleName
    )

    $resourceGroup = "my-test-resource-group"

    # Set the context to the selected subscription
    Set-AzContext -SubscriptionId $subscriptionId

    # List all VMs in the selected subscription
    $vms = Get-AzVM
    if ($vms.Count -eq 0) {
        Write-Host "No VMs available in the selected subscription."
        return
    }

    # Filter VMs that do not have a maintenance assignment
    $unassignedVMs = @()
    foreach ($vm in $vms) {
        # Check for existing maintenance schedule assignment
        $assignment = az maintenance assignment list --resource-group $vm.ResourceGroupName --resource-name $vm.Name --resource-type "virtualMachines" --provider-name "Microsoft.Compute" | ConvertFrom-Json
        
        if ($assignment.Count -eq 0) {
            $unassignedVMs += $vm
        }
    }

    if ($unassignedVMs.Count -eq 0) {
        Write-Host "All VMs in the selected subscription already have a maintenance schedule assigned."
        return
    }

    # Display the list of unassigned VMs
    Write-Host "Available VMs without a maintenance schedule:"
    for ($i = 0; $i -lt $unassignedVMs.Count; $i++) {
        Write-Host "$($i + 1). $($unassignedVMs[$i].Name)"
    }

    # Prompt the user to select a VM
    $vmIndex = Read-Host "Enter the number corresponding to the VM you want to assign"
    if (-not ($vmIndex -as [int]) -or $vmIndex -lt 1 -or $vmIndex -gt $unassignedVMs.Count) {
        Write-Host "Invalid selection. Returning to main menu."
        return
    }

    # Get the selected VM's name
    $vmName = $unassignedVMs[$vmIndex - 1].Name

    # Construct the maintenance configuration ID dynamically
    $maintenanceConfigId = "/subscriptions/$subscriptionId/resourceGroups/$resourceGroup/providers/Microsoft.Maintenance/maintenanceConfigurations/$scheduleName"

    # Assign the selected VM to the maintenance schedule
    az maintenance assignment create --resource-group $resourceGroup --resource-type virtualMachines --resource-name $vmName --provider-name Microsoft.Compute --configuration-assignment-name "myMaintenanceAssignment" --maintenance-configuration-id $maintenanceConfigId
}

# Function to let user choose subscription
function Choose-Subscription {
    # Get all subscriptions
    $subscriptions = Get-AzSubscription
    Write-Host "Available Subscriptions:"
    for ($i = 0; $i -lt $subscriptions.Count; $i++) {
        Write-Host "$($i + 1). $($subscriptions[$i].Name) ($($subscriptions[$i].Id))"
    }

    # Prompt the user to select a subscription
    $subscriptionIndex = Read-Host "Enter the number corresponding to your choice of subscription"
    if (-not ($subscriptionIndex -as [int]) -or $subscriptionIndex -lt 1 -or $subscriptionIndex -gt $subscriptions.Count) {
        Write-Host "Invalid selection. Exiting script."
        exit
    }

    # Return the selected subscription ID
    return $subscriptions[$subscriptionIndex - 1].Id
}

# Main script loop
do {
    # Prompt user to choose subscription at the start
    $subscriptionId = Choose-Subscription

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
            $scheduleName = Read-Host "Enter the maintenance schedule name"
            Assign-MaintenanceSchedule -subscriptionId $subscriptionId -scheduleName $scheduleName
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
