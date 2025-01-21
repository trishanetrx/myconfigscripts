#!/bin/bash

# Prompt the user for the Git repository URL
read -p "Enter the Git repository clone URL: " REPO_URL

# Clone the repository into a temporary directory
TEMP_DIR=$(mktemp -d)
echo "Cloning repository..."
git clone "$REPO_URL" "$TEMP_DIR"
cd "$TEMP_DIR" || exit 1

# Fetch all branches
echo "Fetching all branches..."
git fetch --all

# Iterate over all branches
for branch in $(git branch -r | grep -v '\->' | sed 's/origin\///'); do
    # Skip the main branch
    if [ "$branch" == "main" ] || [ "$branch" == "master" ]; then
        echo "Skipping the main branch: $branch"
        continue
    fi

    echo "Checking out branch: $branch"
    git checkout "$branch"

    # Files to check for 'actions/upload-artifact@v1'
    files=("adf_deploy_dev.yml" "adf_deploy_prod.yml" "adf_deploy_tst.yml")
    
    # Iterate over each file
    for file in "${files[@]}"; do
        if [ -f "$file" ]; then
            echo "Found $file in $branch. Checking contents..."
            
            # Look for the line with 'actions/upload-artifact@v1'
            if grep -q "actions/upload-artifact@v1" "$file"; then
                echo "Updating actions/upload-artifact@v1 to actions/upload-artifact@v3 in $file..."
                
                # Replace actions/upload-artifact@v1 with actions/upload-artifact@v3
                sed -i 's|uses: actions/upload-artifact@v1|uses: actions/upload-artifact@v3|' "$file"
                
                # Add and commit the changes
                git add "$file"
                git commit -m "Update actions/upload-artifact@v1 to actions/upload-artifact@v3 in $file"
                git push origin "$branch"
            else
                echo "No actions/upload-artifact@v1 found in $file. Skipping..."
            fi
        else
            echo "$file not found in $branch. Skipping..."
        fi
    done
done

# Switch back to the main branch (or master)
git checkout main

# Cleanup the temporary directory
echo "Cleaning up..."
rm -rf "$TEMP_DIR"

echo "All done!"
