# Prompt the user for the subscription ID
read -p "Enter the subscription ID: " subscription_id

# Set the subscription ID
az account set --subscription "$subscription_id"

# Verify the subscription was set successfully
current_subscription=$(az account show --query "id" -o tsv)

if [ "$current_subscription" != "$subscription_id" ]; then
    echo "Failed to set the subscription. Please check the subscription ID and try again."
    exit 1
fi

# Initialize the counter
counter=1

# Initialize an array to store results
results=()

# Loop through all VMs in the subscription
for vm in $(az vm list --query "[].name" -o tsv); do
    # Retrieve the resource group for the VM
    rg=$(az vm list --query "[?name=='$vm'].resourceGroup" -o tsv)
    
    if [ -n "$rg" ]; then
        # Retrieve the AMA extension details
        ama_version=$(az vm extension list --resource-group "$rg" --vm-name "$vm" \
            --query "[?name=='AzureMonitorLinuxAgent'].typeHandlerVersion" -o tsv)
        
        if [ -n "$ama_version" ]; then
            result="$counter, $vm, $rg, $ama_version"
        else
            result="$counter, $vm, $rg, Not Installed"
        fi
    else
        result="$counter, $vm, Not Found, N/A"
    fi

    # Add result to the array
    results+=("$result")
    
    # Print the result to the console
    echo "$result"
    ((counter++))
done

# Ask the user if they want to save the output to a CSV file
read -p "Do you want to save the output to a CSV file? (yes/no): " save_to_csv

if [[ "$save_to_csv" =~ ^[Yy]([Ee][Ss])?$ ]]; then
    # Create the CSV file in the Cloud Shell
    output_file="vm_ama_report.csv"
    echo "Number, VM Name, Resource Group, AMA Version" > "$output_file"
    for line in "${results[@]}"; do
        echo "$line" >> "$output_file"
    done
    echo "Output saved to $output_file in your Cloud Shell environment."
else
    echo "Output was not saved."
fi
