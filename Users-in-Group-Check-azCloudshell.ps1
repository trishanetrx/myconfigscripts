# Load Az module
Import-Module Az -Force

# Ensure you're logged in
if (-not (Get-AzContext)) {
    Connect-AzAccount
}

# Step 1: List Subscriptions
$subscriptions = Get-AzSubscription
Write-Host "`nAvailable Subscriptions:`n"
for ($i = 0; $i -lt $subscriptions.Count; $i++) {
    Write-Host "$($i + 1). $($subscriptions[$i].Name) ($($subscriptions[$i].Id))"
}

$subIndex = Read-Host "Enter the number of the subscription to use"
if (-not ($subIndex -as [int]) -or $subIndex -lt 1 -or $subIndex -gt $subscriptions.Count) {
    Write-Host "Invalid subscription selection." -ForegroundColor Red
    exit
}
$selectedSub = $subscriptions[$subIndex - 1]
Set-AzContext -SubscriptionId $selectedSub.Id
Write-Host "`nSwitched to subscription: $($selectedSub.Name)`n"

# Step 2: Get VMs
$vms = Get-AzVM
if ($vms.Count -eq 0) {
    Write-Host "No VMs found in the selected subscription." -ForegroundColor Red
    exit
}

Write-Host "Available VMs:`n"
for ($i = 0; $i -lt $vms.Count; $i++) {
    Write-Host "$($i + 1). $($vms[$i].Name) [RG: $($vms[$i].ResourceGroupName)]"
}

$vmIndex = Read-Host "Enter the number of the VM to target"
if (-not ($vmIndex -as [int]) -or $vmIndex -lt 1 -or $vmIndex -gt $vms.Count) {
    Write-Host "Invalid VM selection." -ForegroundColor Red
    exit
}
$vm = $vms[$vmIndex - 1]
$rg = $vm.ResourceGroupName
$vmName = $vm.Name
$osType = $vm.StorageProfile.OSDisk.OSType

Write-Host "`nSelected VM: $vmName (OS: $osType)`n"

# Step 3: Prepare commands
if ($osType -eq "Linux") {
    $listGroupsCmd = "getent group | cut -d: -f1"
    $getUsersInGroupCmdTemplate = "getent group '{0}' | cut -d: -f4"
    $cmdType = 'RunShellScript'
} else {
    $listGroupsCmd = "Get-LocalGroup | Select-Object -ExpandProperty Name"
    $getUsersInGroupCmdTemplate = "Get-LocalGroupMember -Group '{0}' | Select-Object -ExpandProperty Name"
    $cmdType = 'RunPowerShellScript'
}

# Step 4: List groups
Write-Host "Fetching groups on VM..."
$groupResult = Invoke-AzVMRunCommand -ResourceGroupName $rg -Name $vmName -CommandId $cmdType -ScriptString $listGroupsCmd

$groupList = $groupResult.Value[0].Message -split "`r`n|`n" | Where-Object { $_.Trim() -ne "" }

if ($groupList.Count -eq 0) {
    Write-Host "No groups found." -ForegroundColor Red
    exit
}

# Step 5: Show group list
Write-Host "`nGroups found on VM:`n"
for ($i = 0; $i -lt $groupList.Count; $i++) {
    Write-Host "$($i + 1). $($groupList[$i])"
}

$groupIndex = Read-Host "Enter the number of the group to view members"
if (-not ($groupIndex -as [int]) -or $groupIndex -lt 1 -or $groupIndex -gt $groupList.Count) {
    Write-Host "Invalid group selection." -ForegroundColor Red
    exit
}
$selectedGroup = $groupList[$groupIndex - 1]
Write-Host "`nSelected group: $selectedGroup`n"

# Step 6: Fetch users in selected group
$usersCmd = [string]::Format($getUsersInGroupCmdTemplate, $selectedGroup)
$userResult = Invoke-AzVMRunCommand -ResourceGroupName $rg -Name $vmName -CommandId $cmdType -ScriptString $usersCmd

Write-Host "`nUsers in group '$selectedGroup':"
if ($userResult.Value[0].Message.Trim()) {
    Write-Host $userResult.Value[0].Message
} else {
    Write-Host "(No users found in group or group is empty)"
}
