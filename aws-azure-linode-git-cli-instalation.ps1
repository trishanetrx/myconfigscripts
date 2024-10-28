# Install-CLIs.ps1
# Run this script in PowerShell as Administrator on a newly installed Windows 10 machine.

# Define log file path
$logFilePath = "$env:TEMP\install_log.txt"

# Function to check if a CLI has already been installed
function IsInstalled {
    param([string]$cliName)
    return Select-String -Path $logFilePath -Pattern $cliName -Quiet
}

# Function to log successful installations
function LogInstallation {
    param([string]$cliName)
    Add-Content -Path $logFilePath -Value "$cliName installed successfully."
}

# Function to check and install Python if not present
function Install-Python {
    if (IsInstalled "Python") {
        Write-Host "Python is already installed (logged). Skipping installation."
    } elseif (Get-Command "python" -ErrorAction SilentlyContinue) {
        Write-Host "Python is already installed. Skipping installation."
        LogInstallation "Python"
    } else {
        Write-Host "Python not found. Installing Python..."
        $PythonInstaller = "$env:TEMP\python_installer.exe"
        Invoke-WebRequest -Uri "https://www.python.org/ftp/python/3.9.7/python-3.9.7-amd64.exe" -OutFile $PythonInstaller
        Start-Process -FilePath $PythonInstaller -ArgumentList "/quiet InstallAllUsers=1 PrependPath=1" -Wait
        python --version
        Write-Host "Python installed successfully."
        LogInstallation "Python"
        Remove-Item $PythonInstaller -Force
    }
}

# Function to install pip if not available
function Install-Pip {
    if (IsInstalled "pip") {
        Write-Host "pip is already installed (logged). Skipping installation."
    } elseif (Get-Command "pip" -ErrorAction SilentlyContinue) {
        Write-Host "pip is already installed. Skipping installation."
        LogInstallation "pip"
    } else {
        Write-Host "pip not found. Installing pip..."
        $PipInstaller = "$env:TEMP\get-pip.py"
        Invoke-WebRequest -Uri "https://bootstrap.pypa.io/get-pip.py" -OutFile $PipInstaller
        python $PipInstaller
        python -m pip --version
        Write-Host "pip installed successfully."
        LogInstallation "pip"
        Remove-Item $PipInstaller -Force
    }
}

# Function to check and install WSL if not present
function Install-WSL {
    if (IsInstalled "WSL") {
        Write-Host "WSL is already installed (logged). Skipping installation."
    } elseif (Get-Command "wsl" -ErrorAction SilentlyContinue) {
        Write-Host "WSL is already installed. Skipping installation."
        LogInstallation "WSL"
    } else {
        Write-Host "WSL not found. Installing WSL..."
        wsl --install
        Write-Host "Please restart your computer to complete WSL installation."
        LogInstallation "WSL"
        exit
    }
}

# Function to check and install curl if not present
function Install-Curl {
    if (IsInstalled "curl") {
        Write-Host "curl is already installed (logged). Skipping installation."
    } elseif (Get-Command "curl" -ErrorAction SilentlyContinue) {
        Write-Host "curl is already installed. Skipping installation."
        LogInstallation "curl"
    } else {
        Write-Host "curl not found. Installing curl..."
        $CurlInstaller = "$env:TEMP\curl_installer.msi"
        Invoke-WebRequest -Uri "https://curl.se/windows/dl-7.79.1/curl-7.79.1-win64-mingw.msi" -OutFile $CurlInstaller
        Start-Process -FilePath $CurlInstaller -ArgumentList "/quiet" -Wait
        Write-Host "curl installed successfully."
        LogInstallation "curl"
        Remove-Item $CurlInstaller -Force
    }
}

# Function to check and install Git if not present
function Install-Git {
    if (IsInstalled "Git") {
        Write-Host "Git is already installed (logged). Skipping installation."
    } elseif (Get-Command "git" -ErrorAction SilentlyContinue) {
        Write-Host "Git is already installed. Skipping installation."
        LogInstallation "Git"
    } else {
        Write-Host "Git not found. Installing Git..."
        $GitInstaller = "$env:TEMP\git_installer.exe"
        Invoke-WebRequest -Uri "https://github.com/git-for-windows/git/releases/download/v2.42.0.windows.1/Git-2.42.0-64-bit.exe" -OutFile $GitInstaller
        Start-Process -FilePath $GitInstaller -ArgumentList "/SILENT" -Wait
        Write-Host "Git installed successfully."
        LogInstallation "Git"
        Remove-Item $GitInstaller -Force
    }
}

# Function to install AWS CLI
function Install-AWSCLI {
    if (IsInstalled "AWS CLI") {
        Write-Host "AWS CLI is already installed (logged). Skipping installation."
    } elseif (Get-Command "aws" -ErrorAction SilentlyContinue) {
        Write-Host "AWS CLI is already installed. Skipping installation."
        LogInstallation "AWS CLI"
    } else {
        Write-Host "Installing AWS CLI..."
        $AWSInstallerUrl = "https://awscli.amazonaws.com/AWSCLIV2.msi"
        $InstallerPath = "$env:TEMP\AWSCLI_installer.msi"
        Invoke-WebRequest -Uri $AWSInstallerUrl -OutFile $InstallerPath
        Start-Process -FilePath msiexec.exe -ArgumentList "/i $InstallerPath /qn" -Wait
        Write-Host "AWS CLI installation completed successfully."
        LogInstallation "AWS CLI"
        Remove-Item $InstallerPath -Force
    }
}

# Function to install Azure CLI
function Install-AzureCLI {
    if (IsInstalled "Azure CLI") {
        Write-Host "Azure CLI is already installed (logged). Skipping installation."
    } elseif (Get-Command "az" -ErrorAction SilentlyContinue) {
        Write-Host "Azure CLI is already installed. Skipping installation."
        LogInstallation "Azure CLI"
    } else {
        Write-Host "Installing Azure CLI..."
        $AzureInstallerUrl = "https://aka.ms/installazurecliwindows"
        $InstallerPath = "$env:TEMP\AzureCLI.msi"
        Invoke-WebRequest -Uri $AzureInstallerUrl -OutFile $InstallerPath
        Start-Process -FilePath msiexec.exe -ArgumentList "/i $InstallerPath /quiet" -Wait
        Write-Host "Azure CLI installation completed successfully."
        LogInstallation "Azure CLI"
        Remove-Item $InstallerPath -Force
    }
}

# Function to install kubectl
function Install-Kubectl {
    if (IsInstalled "kubectl") {
        Write-Host "kubectl is already installed (logged). Skipping installation."
    } elseif (Get-Command "kubectl" -ErrorAction SilentlyContinue) {
        Write-Host "kubectl is already installed. Skipping installation."
        LogInstallation "kubectl"
    } else {
        Write-Host "Installing kubectl..."
        $KubectlPath = "$env:USERPROFILE\kubectl.exe"
        Invoke-WebRequest -Uri "https://dl.k8s.io/release/v1.23.0/bin/windows/amd64/kubectl.exe" -OutFile $KubectlPath
        [System.Environment]::SetEnvironmentVariable("Path", $env:Path + ";$env:USERPROFILE", [System.EnvironmentVariableTarget]::Machine)
        Write-Host "kubectl installed successfully."
        LogInstallation "kubectl"
    }
}

# Run all installations
Install-Python
Install-Pip
Install-WSL
Install-Curl
Install-Git
Install-AWSCLI
Install-AzureCLI
Install-Kubectl

Write-Host "All CLI installations are complete. Restart your machine if WSL was installed for changes to take effect."
