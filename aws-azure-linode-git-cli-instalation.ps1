
# Run this script in Administrator PowerShell

# --- Administrator Check ---
if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Error "This script must be run as an Administrator. Please restart PowerShell with elevated privileges."
    exit 1
}

# --- Log setup ---
$LogFile = Join-Path $env:TEMP "cli_install_log.txt"
if (!(Test-Path $LogFile)) {
    New-Item -ItemType File -Path $LogFile -Force | Out-Null
}

function Log {
    param ([string]$msg)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Add-Content -Path $LogFile -Value "$timestamp - $msg"
    Write-Host $msg
}

# --- Refresh PATH ---
function Refresh-EnvPath {
    Log "Refreshing environment PATH..."
    $machinePath = [System.Environment]::GetEnvironmentVariable("Path", "Machine")
    $userPath = [System.Environment]::GetEnvironmentVariable("Path", "User")
    $env:Path = "$machinePath;$userPath"
}

# --- Install function for EXE/MSI tools ---
function Install-CLI {
    param (
        [Parameter(Mandatory=$true)][string]$Name,
        [Parameter(Mandatory=$true)][string]$InstallerUrl,
        [Parameter(Mandatory=$true)][string]$InstallerPath,
        [string]$InstallArgs = "",
        [Parameter(Mandatory=$true)][string]$CheckCmd
    )

    if (Get-Command $CheckCmd -ErrorAction SilentlyContinue) {
        Log "$Name is already installed."
        return
    }

    try {
        Log "Downloading $Name from $InstallerUrl..."
        Invoke-WebRequest -Uri $InstallerUrl -OutFile $InstallerPath -UseBasicParsing -ErrorAction Stop

        Log "Installing $Name..."
        $process = Start-Process -FilePath $InstallerPath -ArgumentList $InstallArgs -Wait -PassThru
        if ($process.ExitCode -ne 0) {
            throw "Installation of $Name failed with exit code $($process.ExitCode)."
        }

        Refresh-EnvPath
        Start-Sleep -Seconds 5

        if (Get-Command $CheckCmd -ErrorAction SilentlyContinue) {
            Log "✅ $Name installation successful."
        } else {
            Log "⚠️ $Name was installed, but '$CheckCmd' is still not found in PATH. You may need to restart your shell."
        }
    }
    catch {
        Log "❌ Error installing $($Name): $($_.Message)"
    }
    finally {
        if (Test-Path $InstallerPath) {
            Remove-Item $InstallerPath -Force -ErrorAction SilentlyContinue
        }
    }
}

# --- Special installer for kubectl (binary download) ---
function Install-Kubectl {
    if (Get-Command "kubectl" -ErrorAction SilentlyContinue) {
        Log "kubectl is already installed."
        return
    }

    # Latest stable version as of Mar 2026: v1.35.2
    $Url = "https://dl.k8s.io/release/v1.35.2/bin/windows/amd64/kubectl.exe"
    $DestDir = "C:\Program Files\kubectl"
    $DestFile = Join-Path $DestDir "kubectl.exe"

    try {
        Log "Downloading kubectl v1.35.2..."
        if (!(Test-Path $DestDir)) {
            New-Item -ItemType Directory -Path $DestDir -Force | Out-Null
        }
        Invoke-WebRequest -Uri $Url -OutFile $DestFile -UseBasicParsing -ErrorAction Stop

        Log "Adding kubectl to Machine PATH..."
        $oldPath = [System.Environment]::GetEnvironmentVariable("Path", "Machine")
        if ($oldPath -notlike "*$DestDir*") {
            [System.Environment]::SetEnvironmentVariable("Path", "$oldPath;$DestDir", [System.EnvironmentVariableTarget]::Machine)
        }
        
        Refresh-EnvPath
        Start-Sleep -Seconds 3

        if (Get-Command "kubectl" -ErrorAction SilentlyContinue) {
            Log "✅ kubectl installed and added to PATH."
        } else {
            Log "⚠️ kubectl installed, but not found in current session PATH."
        }
    }
    catch {
        Log "❌ Error installing kubectl: $($_.Message)"
    }
}

# --- Terraform installer (ZIP extract) ---
function Install-Terraform {
    if (Get-Command "terraform" -ErrorAction SilentlyContinue) {
        Log "Terraform is already installed."
        return
    }

    # Latest stable version as of Mar 2026: 1.14.7
    $Version = "1.14.7"
    $Url = "https://releases.hashicorp.com/terraform/$Version/terraform_$( $Version )_windows_amd64.zip"
    $DestDir = "C:\Program Files\terraform"
    $ZipFile = Join-Path $env:TEMP "terraform.zip"

    try {
        Log "Downloading Terraform v$Version..."
        Invoke-WebRequest -Uri $Url -OutFile $ZipFile -UseBasicParsing -ErrorAction Stop

        Log "Extracting Terraform..."
        if (!(Test-Path $DestDir)) {
            New-Item -ItemType Directory -Path $DestDir -Force | Out-Null
        }
        Expand-Archive -Path $ZipFile -DestinationPath $DestDir -Force

        Log "Adding Terraform to Machine PATH..."
        $oldPath = [System.Environment]::GetEnvironmentVariable("Path", "Machine")
        if ($oldPath -notlike "*$DestDir*") {
            [System.Environment]::SetEnvironmentVariable("Path", "$oldPath;$DestDir", [System.EnvironmentVariableTarget]::Machine)
        }
        
        Refresh-EnvPath
        Start-Sleep -Seconds 3

        if (Get-Command "terraform" -ErrorAction SilentlyContinue) {
            Log "✅ Terraform installed and added to PATH."
        } else {
            Log "⚠️ Terraform installed, but not found in current session PATH."
        }
    }
    catch {
        Log "❌ Error installing Terraform: $($_.Message)"
    }
    finally {
        if (Test-Path $ZipFile) {
            Remove-Item $ZipFile -Force -ErrorAction SilentlyContinue
        }
    }
}

# --- Python and pip installer ---
function Install-PythonWithPip {
    if ((Get-Command python -ErrorAction SilentlyContinue) -and (Get-Command pip -ErrorAction SilentlyContinue)) {
        Log "Python and pip are already installed."
        return
    }

    try {
        Log "Installing Python 3.12.10 with pip..."
        $pythonInstaller = Join-Path $env:TEMP "python-installer.exe"
        # Latest 3.12.x maintenance release
        Invoke-WebRequest -Uri "https://www.python.org/ftp/python/3.12.10/python-3.12.10-amd64.exe" -OutFile $pythonInstaller -UseBasicParsing -ErrorAction Stop
        
        Log "Running Python installer (silent)..."
        $args = "/quiet InstallAllUsers=1 PrependPath=1 Include_pip=1"
        $process = Start-Process -FilePath $pythonInstaller -ArgumentList $args -Wait -PassThru
        
        if ($process.ExitCode -ne 0) {
            throw "Python installation failed with exit code $($process.ExitCode)."
        }

        Refresh-EnvPath
        Start-Sleep -Seconds 5
        
        if (Get-Command python -ErrorAction SilentlyContinue) {
            Log "✅ Python installation complete."
            python --version
            pip --version
        } else {
            Log "⚠️ Python installed, but 'python' command not found. Manual PATH check required."
        }
    }
    catch {
        Log "❌ Error installing Python: $($_.Message)"
    }
    finally {
        if (Test-Path $pythonInstaller) {
            Remove-Item $pythonInstaller -Force -ErrorAction SilentlyContinue
        }
    }
}

# --- Linode CLI install via pip ---
function Install-LinodeCLI {
    if (Get-Command linode-cli -ErrorAction SilentlyContinue) {
        Log "Linode CLI is already installed."
        return
    }

    try {
        Log "Installing Linode CLI via pip..."
        # Ensure pip is up to date first
        python -m pip install --upgrade pip --quiet
        pip install linode-cli --quiet

        Refresh-EnvPath
        Start-Sleep -Seconds 2

        if (Get-Command linode-cli -ErrorAction SilentlyContinue) {
            Log "✅ Linode CLI installation successful."
            linode-cli --version
        } else {
             Log "⚠️ Linode CLI installed, but 'linode-cli' not found in PATH."
        }
    }
    catch {
        Log "❌ Error installing Linode CLI: $($_.Message)"
    }
}

# --- Main installation flow ---
Log "--- Starting CLI Tool Installations ---"
$TempDir = $env:TEMP

# 1. Base requirements
Install-PythonWithPip
Install-LinodeCLI

# 2. Version-controlled Git (Latest v2.53.0)
Install-CLI "Git" `
    "https://github.com/git-for-windows/git/releases/download/v2.53.0.windows.1/Git-2.53.0-64-bit.exe" `
    (Join-Path $TempDir "git_installer.exe") `
    "/SILENT" `
    "git"

# 3. AWS CLI (Always points to latest v2)
Install-CLI "AWS CLI" `
    "https://awscli.amazonaws.com/AWSCLIV2.msi" `
    (Join-Path $TempDir "awscli_installer.msi") `
    "/qn" `
    "aws"

# 4. Azure CLI (Always points to latest)
Install-CLI "Azure CLI" `
    "https://aka.ms/installazurecliwindows" `
    (Join-Path $TempDir "azurecli_installer.msi") `
    "/quiet" `
    "az"

# 5. Kubectl (Binary download)
Install-Kubectl

# 6. Terraform (ZIP extraction)
Install-Terraform

Log "`n✅ Process finished. If some commands are still not recognized, please restart your terminal."
