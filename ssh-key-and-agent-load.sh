#!/bin/bash

# Prompt the user for the path to the private key
read -p "Please enter the full path to your private SSH key: " key_path

# Verify the provided key path exists
if [ ! -f "$key_path" ]; then
    echo "The file $key_path does not exist. Please check the path and try again."
    exit 1
fi

# Define the script content
script_content="#!/bin/bash

# Check if SSH agent is running
if [ -z \"\$SSH_AUTH_SOCK\" ] || ! ssh-add -l &> /dev/null; then
    eval \"\$(ssh-agent -s)\"
    ssh-add $key_path
fi
"

# Define the path for the new script
script_path="$HOME/.ssh/start_ssh_agent.sh"

# Create the script file and write the content to it
echo "$script_content" > "$script_path"

# Make the script executable
chmod +x "$script_path"

# Add the script to ~/.bashrc if it's not already added
bashrc_line="if [ -f ~/.ssh/start_ssh_agent.sh ]; then . ~/.ssh/start_ssh_agent.sh; fi"
if ! grep -Fxq "$bashrc_line" "$HOME/.bashrc"; then
    echo "$bashrc_line" >> "$HOME/.bashrc"
fi

# Inform the user of the changes
echo "The SSH agent startup script has been created at $script_path"
echo "The script has been added to your ~/.bashrc file."
echo "To apply the changes, run: source ~/.bashrc"

