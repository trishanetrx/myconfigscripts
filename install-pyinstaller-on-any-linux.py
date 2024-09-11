import os
import subprocess

def install_pyinstaller():
    try:
        # Step 1: Check the Linux distribution
        distro = ""
        with open("/etc/os-release") as f:
            for line in f:
                if line.startswith("ID="):
                    distro = line.strip().split("=")[1].lower().replace('"', '')

        if not distro:
            raise ValueError("Unable to determine Linux distribution")

        print(f"Detected Linux distribution: {distro}")

        # Step 2: Update the package list and install Python and pip based on the distro
        if distro in ["ubuntu", "debian"]:
            print("Updating package list and installing Python and pip on Debian-based system...")
            # Suppress interactive prompts during package installation
            subprocess.run(
                ["sudo", "DEBIAN_FRONTEND=noninteractive", "apt-get", "update"], check=True
            )
            subprocess.run(
                ["sudo", "DEBIAN_FRONTEND=noninteractive", "apt-get", "install", "-y", "python3", "python3-pip"], check=True
            )
        elif distro in ["rhel", "centos", "fedora"]:
            print("Updating package list and installing Python and pip on Red Hat-based system...")
            subprocess.run(
                ["sudo", "yum", "install", "-y", "python3", "python3-pip"], check=True
            )
        else:
            raise ValueError(f"Unsupported distribution: {distro}")

        # Step 3: Install PyInstaller using pip
        print("Installing PyInstaller...")
        subprocess.run(["pip3", "install", "pyinstaller"], check=True)

        # Step 4: Verify installation
        print("Verifying PyInstaller installation...")
        subprocess.run(["pyinstaller", "--version"], check=True)
        
        print("PyInstaller installed successfully!")
    
    except subprocess.CalledProcessError as e:
        print(f"An error occurred during installation: {e}")
    except Exception as e:
        print(f"An unexpected error occurred: {e}")

if __name__ == "__main__":
    install_pyinstaller()
