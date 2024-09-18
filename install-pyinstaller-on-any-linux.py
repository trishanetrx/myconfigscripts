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

        # Step 2: Install Python, pip, and necessary packages based on the distro
        if distro in ["ubuntu", "debian"]:
            print("Updating package list and installing Python and pip on Debian-based system...")
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

            # Step 3: Check if GCC (C compiler) is installed (this part is for Red Hat)
            print("Checking if GCC is installed...")
            try:
                subprocess.run(["gcc", "--version"], check=True)
                print("GCC is already installed.")
            except FileNotFoundError:
                print("GCC not found. Installing development tools (including GCC)...")
                subprocess.run(["sudo", "yum", "groupinstall", "-y", "Development Tools"], check=True)

        else:
            raise ValueError(f"Unsupported distribution: {distro}")

        # Step 4: Install wheel (required for building PyInstaller)
        print("Installing the wheel package...")
        subprocess.run(["pip3", "install", "--user", "wheel"], check=True)

        # Step 5: Install PyInstaller using pip
        print("Installing PyInstaller...")
        subprocess.run(["pip3", "install", "--user", "pyinstaller"], check=True)

        # Step 6: Handle PATH separately for Ubuntu/Debian and Red Hat
        local_bin_path = os.path.expanduser("~/.local/bin")

        if distro in ["ubuntu", "debian"]:
            # Ubuntu/Debian specific handling of the PATH
            if local_bin_path not in os.environ["PATH"]:
                print(f"Adding {local_bin_path} to PATH for Ubuntu/Debian...")
                with open(os.path.expanduser("~/.bashrc"), "a") as bashrc:
                    bashrc.write(f'\nexport PATH="{local_bin_path}:$PATH"\n')
                os.environ["PATH"] += os.pathsep + local_bin_path
        elif distro in ["rhel", "centos", "fedora"]:
            # Keep Red Hat settings as fixed previously
            if local_bin_path not in os.environ["PATH"]:
                print(f"Adding {local_bin_path} to PATH for Red Hat...")
                with open(os.path.expanduser("~/.bashrc"), "a") as bashrc:
                    bashrc.write(f'\nexport PATH="{local_bin_path}:$PATH"\n')
                os.environ["PATH"] += os.pathsep + local_bin_path

        # Step 7: Verify PyInstaller installation
        print("Verifying PyInstaller installation...")
        subprocess.run(["pyinstaller", "--version"], check=True)

        print("PyInstaller installed successfully!")
    
    except subprocess.CalledProcessError as e:
        print(f"An error occurred during installation: {e}")
    except Exception as e:
        print(f"An unexpected error occurred: {e}")

if __name__ == "__main__":
    install_pyinstaller()
