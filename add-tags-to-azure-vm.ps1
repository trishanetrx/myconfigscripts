# Function to display a menu and let the user select an option
function Select-Option {
    param (
        [string]$Prompt,
        [Array]$Options
    )
    
    Write-Host $Prompt
    $index = 1
    foreach ($option in $Options) {
        Write-Host "$index. $option"
        $index++
    }

    $choice = Read-Host "Enter the number of your choice"
    return $Options[$choice - 1]
}

# Fetch available subscriptions
Write-Host "Fetching available subscriptions..."
$subscriptionList = az account list --query "[].{Name:name, Id:id}" -o json | ConvertFrom-Json

if ($subscriptionList.Count -eq 0) {
    Write-Host "No subscriptions found."
    exit 1
}

# Let the user select a subscription
$subscriptionNames = $subscriptionList | ForEach-Object { $_.Name }
$selectedSubscription = Select-Option -Prompt "Select an Azure Subscription:" -Options $subscriptionNames

# Get the selected subscription's ID
$selectedSubscriptionId = ($subscriptionList | Where-Object { $_.Name -eq $selectedSubscription }).Id

# Set the selected subscription
az account set --subscription $selectedSubscriptionId
if ($?) {
    Write-Host "Successfully set subscription: $selectedSubscription"
} else {
    Write-Host "Failed to set subscription. Please check the Subscription."
    exit 1
}

# Fetch available resource groups
Write-Host "Fetching available Resource Groups..."
$resourceGroupList = az group list --query "[].name" -o tsv

if ($resourceGroupList -eq "") {
    Write-Host "No resource groups found."
    exit 1
}

# Let the user select a resource group
$selectedResourceGroup = Select-Option -Prompt "Select a Resource Group:" -Options $resourceGroupList

# List available VMs in the selected resource group
Write-Host "Fetching VMs in Resource Group '$selectedResourceGroup'..."
$vmList = az vm list --resource-group $selectedResourceGroup --query "[].name" -o tsv

if ($vmList -eq "") {
    Write-Host "No VMs found in the specified resource group."
    exit 1
}

# Let the user select VMs
$selectedVMs = @()
do {
    $selectedVM = Select-Option -Prompt "Select a VM to tag:" -Options $vmList
    $selectedVMs += $selectedVM

    $response = Read-Host "Do you want to select another VM? (y/n)"
} while ($response -eq 'y')

# Prompt for Tag Key and Value
$tagKey = Read-Host "Enter the tag key"
$tagValue = Read-Host "Enter the tag value"

# Validate the tag key and value
if ([string]::IsNullOrWhiteSpace($tagKey) -or [string]::IsNullOrWhiteSpace($tagValue)) {
    Write-Host "Tag key and value cannot be empty. Please provide valid inputs."
    exit 1
}

# Display all inputs to the user and confirm
Write-Host "You entered the following details:"
Write-Host "Subscription: $selectedSubscription"
Write-Host "Resource Group: $selectedResourceGroup"
Write-Host "Selected VMs: $($selectedVMs -join ', ')"
Write-Host "Tag Key: $tagKey"
Write-Host "Tag Value: $tagValue"

$confirm = Read-Host "Do you want to proceed with these details? (y/n)"
if ($confirm -ne 'y') {
    Write-Host "Exiting. Please restart the script to make changes."
    exit 0
}

# Debugging: Print tag key and value before applying
Write-Host "Debugging: Tag Key = '$tagKey', Tag Value = '$tagValue'"

# Loop through selected VMs and tag them
foreach ($vm in $selectedVMs) {
    Write-Host "Tagging VM: $vm in Resource Group: $selectedResourceGroup"
    
    # Construct the az command
    $tagCommand = "az resource update --resource-group $selectedResourceGroup --name $vm --resource-type 'Microsoft.Compute/virtualMachines' --set tags.$tagKey=$tagValue --output table"
    
    # Debugging: print the constructed command
    Write-Host "Running command: $tagCommand"

    # Execute the command
    Invoke-Expression $tagCommand

    if ($?) {
        Write-Host "Successfully tagged $vm."
    } else {
        Write-Host "Failed to tag $vm."
    }
}

Write-Host "Tagging process completed!"
