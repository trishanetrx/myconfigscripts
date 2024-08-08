# Function to check if a file path is valid
function Test-LocalFilePath {
    param (
        [string]$path
    )
    return Test-Path $path
}

# Prompt the user for necessary information
$accountKey = Read-Host "Please enter your storage account key"

# Loop until a valid local file path is provided
do {
    $localFilePath = Read-Host "Please enter the local path to the file"
    if (-not (Test-LocalFilePath -path $localFilePath)) {
        Write-Host "The local file path '$localFilePath' is invalid. Please check the path and try again." -ForegroundColor Red
    }
} while (-not (Test-LocalFilePath -path $localFilePath))

$storageAccountName = Read-Host "Please enter the storage account name"
$containerName = Read-Host "Please enter the container name"

# AzCopy login
Write-Host "Opening web UI for AzCopy login..."
Start-Process -NoNewWindow -FilePath "azcopy" -ArgumentList "login" | Out-Null
Write-Host "Please complete the login in the web browser..."

# Wait for the user to complete the login
$loginComplete = $false
while (-not $loginComplete) {
    Start-Sleep -Seconds 5
    try {
        $loginStatus = azcopy env
        if ($loginStatus) {
            $loginComplete = $true
        }
    } catch {
        # Ignore the exception and keep waiting
    }
}

Write-Host "Login completed successfully!"

# Set the storage account key as an environment variable
[System.Environment]::SetEnvironmentVariable('AZCOPY_ACCOUNT_KEY', $accountKey, 'Process')
Write-Host "Environment variable AZCOPY_ACCOUNT_KEY set successfully!"

# Construct the destination URL
$destinationUrl = "https://$storageAccountName.blob.core.windows.net/$containerName/$(Split-Path $localFilePath -Leaf)"

# Run the AzCopy command to copy the file
Write-Host "Starting AzCopy file transfer..."
$azCopyCommand = "azcopy copy `"$localFilePath`" `"$destinationUrl`""
Write-Host "Running command: $azCopyCommand"
Invoke-Expression $azCopyCommand

Write-Host "AzCopy file transfer initiated. Please check the progress in the command prompt or terminal."
