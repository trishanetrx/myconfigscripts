# Prompt the user for the subscription, resource group, and VM name
$subscription = Read-Host -Prompt "Enter the Subscription Name"
$resourceGroup = Read-Host -Prompt "Enter the Resource Group Name"
$vmName = Read-Host -Prompt "Enter the VM Name"

# Set the subscription context
Set-AzContext -Subscription $subscription

# Retrieve the VM object
$VirtualMachine = Get-AzVM -ResourceGroupName $resourceGroup -Name $vmName

# Determine if the VM is Windows or Linux
if ($VirtualMachine.StorageProfile.OsDisk.OsType -eq "Windows") {
    
    # Set Patch Mode for Windows VM
    Set-AzVMOperatingSystem -VM $VirtualMachine -Windows -PatchMode "AutomaticByPlatform"

    # Retrieve or set patch settings for Windows VM
    $AutomaticByPlatformSettings = $VirtualMachine.OSProfile.WindowsConfiguration.PatchSettings.AutomaticByPlatformSettings

    if ($null -eq $AutomaticByPlatformSettings) {
        $VirtualMachine.OSProfile.WindowsConfiguration.PatchSettings.AutomaticByPlatformSettings = New-Object -TypeName Microsoft.Azure.Management.Compute.Models.WindowsVMGuestPatchAutomaticByPlatformSettings -Property @{BypassPlatformSafetyChecksOnUserSchedule = $true}
    } else {
        $AutomaticByPlatformSettings.BypassPlatformSafetyChecksOnUserSchedule = $true
    }

} elseif ($VirtualMachine.StorageProfile.OsDisk.OsType -eq "Linux") {

    # Set Patch Mode for Linux VM
    Set-AzVMOperatingSystem -VM $VirtualMachine -Linux -PatchMode "AutomaticByPlatform"

    # Retrieve or set patch settings for Linux VM
    $AutomaticByPlatformSettings = $VirtualMachine.OSProfile.LinuxConfiguration.PatchSettings.AutomaticByPlatformSettings

    if ($null -eq $AutomaticByPlatformSettings) {
        $VirtualMachine.OSProfile.LinuxConfiguration.PatchSettings.AutomaticByPlatformSettings = New-Object -TypeName Microsoft.Azure.Management.Compute.Models.LinuxVMGuestPatchAutomaticByPlatformSettings -Property @{BypassPlatformSafetyChecksOnUserSchedule = $true}
    } else {
        $AutomaticByPlatformSettings.BypassPlatformSafetyChecksOnUserSchedule = $true
    }

}

# Update the VM with the modified settings
Update-AzVM -VM $VirtualMachine -ResourceGroupName $resourceGroup
