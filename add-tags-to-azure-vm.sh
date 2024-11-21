#!/bin/bash

# Prompt for Subscription ID
read -p "Enter the Azure Subscription ID: " SUBSCRIPTION_ID

# Set the subscription
az account set --subscription $SUBSCRIPTION_ID
if [ $? -ne 0 ]; then
    echo "Failed to set subscription. Please check the Subscription ID."
    exit 1
fi

# Prompt for Resource Group
read -p "Enter the Resource Group name: " RESOURCE_GROUP

# List available VMs in the resource group
echo "Fetching VMs in Resource Group '$RESOURCE_GROUP'..."
VM_LIST=$(az vm list --resource-group $RESOURCE_GROUP --query "[].{Name:name}" -o tsv)

if [ -z "$VM_LIST" ]; then
    echo "No VMs found in the specified resource group."
    exit 1
fi

echo "Available VMs:"
VM_ARRAY=()
INDEX=1
while read -r VM_NAME; do
    echo "$INDEX. $VM_NAME"
    VM_ARRAY+=("$VM_NAME")
    INDEX=$((INDEX + 1))
done <<< "$VM_LIST"

# Prompt user to select VMs
read -p "Enter the numbers of the VMs to tag (e.g., 1 3 5): " SELECTED_NUMBERS
SELECTED_VMS=()
for NUM in $SELECTED_NUMBERS; do
    SELECTED_VMS+=("${VM_ARRAY[$((NUM-1))]}")
done

# Prompt for Tag Key and Value
read -p "Enter the tag key: " TAG_KEY
read -p "Enter the tag value: " TAG_VALUE

# Loop through selected VMs and tag them
for VM in "${SELECTED_VMS[@]}"
do
    echo "Tagging VM: $VM in Resource Group: $RESOURCE_GROUP"
    az resource update \
        --resource-group $RESOURCE_GROUP \
        --name $VM \
        --resource-type "Microsoft.Compute/virtualMachines" \
        --set tags.$TAG_KEY=$TAG_VALUE \
        --output table
    if [ $? -eq 0 ]; then
        echo "Successfully tagged $VM."
    else
        echo "Failed to tag $VM."
    fi
done

echo "Tagging process completed!"
