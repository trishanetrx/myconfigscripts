# Run this script in Administrator PowerShell

# --- Log setup ---
$LogFile = "$env:TEMP\cli_install_log.txt"
New-Item -ItemType File -Path $LogFile -Force | Out-Null

function Log {
    param ($msg)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Add-Content -Path $LogFile -Value "$timestamp - $msg"
    Write-Host $msg
}

# --- Refresh PATH ---
function Refresh-EnvPath {
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine")
}

# --- Install function for EXE/MSI tools ---
function Install-CLI {
    param (
        [string]$Name,
        [string]$InstallerUrl,
        [string]$InstallerPath,
        [string]$InstallArgs,
        [string]$CheckCmd
    )

    if (Get-Command $CheckCmd -ErrorAction SilentlyContinue) {
        Log "$Name already installed."
        return
    }

    Log "Downloading $Name..."
    Invoke-WebRequest -Uri $InstallerUrl -OutFile $InstallerPath -UseBasicParsing

    Log "Installing $Name..."
    if ([string]::IsNullOrWhiteSpace($InstallArgs)) {
        Start-Process -FilePath $InstallerPath -Wait
    } else {
        Start-Process -FilePath $InstallerPath -ArgumentList $InstallArgs -Wait
    }

    Refresh-EnvPath
    Start-Sleep -Seconds 5

    if (Get-Command $CheckCmd -ErrorAction SilentlyContinue) {
        Log "$Name installation successful."
    } else {
        Log "⚠️ $Name may not have installed correctly. Please check manually."
    }

    Remove-Item $InstallerPath -Force -ErrorAction SilentlyContinue
}

# --- Special installer for kubectl (non-interactive .exe) ---
function Install-Kubectl {
    if (Get-Command "kubectl" -ErrorAction SilentlyContinue) {
        Log "kubectl already installed."
        return
    }

    $Url = "https://dl.k8s.io/release/v1.23.0/bin/windows/amd64/kubectl.exe"
    $DestDir = "C:\Program Files\kubectl"
    $DestFile = "$DestDir\kubectl.exe"

    Log "Downloading kubectl..."
    New-Item -ItemType Directory -Path $DestDir -Force | Out-Null
    Invoke-WebRequest -Uri $Url -OutFile $DestFile -UseBasicParsing

    [System.Environment]::SetEnvironmentVariable("Path", $env:Path + ";$DestDir", [System.EnvironmentVariableTarget]::Machine)
    Refresh-EnvPath
    Start-Sleep -Seconds 3

    if (Get-Command "kubectl" -ErrorAction SilentlyContinue) {
        Log "kubectl installed and added to PATH."
    } else {
        Log "⚠️ kubectl may not have installed correctly."
    }
}

# --- Python and pip fix ---
function Install-PythonWithPip {
    if ((Get-Command python -ErrorAction SilentlyContinue) -and (Get-Command pip -ErrorAction SilentlyContinue)) {
        Log "Python and pip already installed."
        return
    }

    Log "Installing Python with pip..."
    $pythonInstaller = "$env:TEMP\python-installer.exe"
    Invoke-WebRequest -Uri "https://www.python.org/ftp/python/3.12.0/python-3.12.0-amd64.exe" -OutFile $pythonInstaller
    Start-Process -FilePath $pythonInstaller -ArgumentList "/quiet InstallAllUsers=1 PrependPath=1 Include_pip=1" -Wait
    Refresh-EnvPath
    Start-Sleep -Seconds 5
    Log "Python installation complete. Verifying:"
    python --version
    pip --version
}

# --- Begin installation steps ---
$TempDir = "$env:TEMP"

Install-PythonWithPip

Install-CLI "Git" `
    "https://github.com/git-for-windows/git/releases/download/v2.42.0.windows.1/Git-2.42.0-64-bit.exe" `
    "$TempDir\git_installer.exe" `
    "/SILENT" `
    "git"

Install-CLI "AWS CLI" `
    "https://awscli.amazonaws.com/AWSCLIV2.msi" `
    "$TempDir\awscli_installer.msi" `
    "/qn" `
    "aws"

Install-CLI "Azure CLI" `
    "https://aka.ms/installazurecliwindows" `
    "$TempDir\azurecli_installer.msi" `
    "/quiet" `
    "az"

Install-Kubectl

Log "`n✅ All installations attempted. You can safely re-run this script anytime."
