import os
import subprocess
import platform
import sys

def is_terraform_installed():
    try:
        subprocess.run(["terraform", "version"], stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=True)
        print("Terraform CLI is already installed.")
        return True
    except subprocess.CalledProcessError:
        return False
    except FileNotFoundError:
        return False

def install_terraform():
    os_type = platform.system().lower()

    if os_type == "windows":
        print("Downloading and installing Terraform for Windows...")
        url = "https://releases.hashicorp.com/terraform/1.6.0/terraform_1.6.0_windows_amd64.zip"
        download_and_install_terraform(url, "windows")

    elif os_type == "linux":
        distro = subprocess.run(["lsb_release", "-is"], stdout=subprocess.PIPE, text=True).stdout.strip().lower()

        if distro == "ubuntu" or distro == "debian":
            print("Installing Terraform on Ubuntu/Debian...")

            subprocess.run(["sudo", "apt-get", "update"], check=True)
            subprocess.run(["sudo", "apt-get", "install", "-y", "gnupg", "software-properties-common"], check=True)

            wget_process = subprocess.Popen(["wget", "-O-", "https://apt.releases.hashicorp.com/gpg"], stdout=subprocess.PIPE)
            gpg_process = subprocess.Popen(["gpg", "--dearmor"], stdin=wget_process.stdout, stdout=subprocess.PIPE)
            with open("/usr/share/keyrings/hashicorp-archive-keyring.gpg", "wb") as f:
                f.write(gpg_process.communicate()[0])

            wget_process.wait()
            gpg_process.wait()

            subprocess.run(["gpg", "--no-default-keyring", "--keyring", 
                            "/usr/share/keyrings/hashicorp-archive-keyring.gpg", "--fingerprint"], check=True)

            ubuntu_release = subprocess.run(["lsb_release", "-cs"], stdout=subprocess.PIPE, text=True).stdout.strip()

            repo_entry = f"deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com {ubuntu_release} main"
            subprocess.run(["sudo", "tee", "/etc/apt/sources.list.d/hashicorp.list"], input=repo_entry, text=True, check=True)

            subprocess.run(["sudo", "apt-get", "update"], check=True)
            subprocess.run(["sudo", "apt-get", "install", "-y", "terraform"], check=True)

        elif distro == "rhel" or distro == "centos":
            print("Installing Terraform on RHEL/CentOS...")
            subprocess.run(["sudo", "yum", "install", "-y", "yum-utils"], check=True)
            subprocess.run(["sudo", "yum-config-manager", "--add-repo", 
                            "https://rpm.releases.hashicorp.com/RHEL/hashicorp.repo"], check=True)
            subprocess.run(["sudo", "yum", "-y", "install", "terraform"], check=True)
        else:
            print(f"Unsupported Linux distribution: {distro}")
            sys.exit(1)
    else:
        print(f"Unsupported operating system: {os_type}")
        sys.exit(1)

    print("Terraform has been successfully installed.")

def download_and_install_terraform(url, os_type):
    import zipfile
    import urllib.request
    import shutil

    terraform_zip = "terraform.zip"
    terraform_dir = os.path.join(os.getcwd(), "terraform")

    urllib.request.urlretrieve(url, terraform_zip)
    
    with zipfile.ZipFile(terraform_zip, 'r') as zip_ref:
        zip_ref.extractall(terraform_dir)

    terraform_binary = os.path.join(terraform_dir, "terraform.exe" if os_type == "windows" else "terraform")

    if os_type == "windows":
        destination = os.path.join(os.environ['WINDIR'], 'System32', 'terraform.exe')
    else:
        destination = "/usr/local/bin/terraform"

    shutil.move(terraform_binary, destination)
    print(f"Terraform installed at {destination}")

    os.remove(terraform_zip)
    shutil.rmtree(terraform_dir)

def create_folder(destination):
    try:
        if not os.path.exists(destination):
            os.makedirs(destination)
            print(f"Created folder at {destination}")
        else:
            print(f"Folder already exists at {destination}")
    except Exception as e:
        print(f"Error creating folder: {e}")

def write_terraform_config(cloud_platform, destination, config_params):
    terraform_template = {
        "aws": f"""
terraform {{
  required_providers {{
    aws = {{
      source = "hashicorp/aws"
      version = ">= 3.0.0"
    }}
  }}
}}

provider "aws" {{
  access_key = "{config_params.get('aws_access_key', '')}"
  secret_key = "{config_params.get('aws_secret_key', '')}"
  region     = "us-west-2"
}}

resource "aws_instance" "example" {{
  ami           = "ami-0c55b159cbfafe1f0"
  instance_type = "t2.micro"
}}
""",
        "azure": f"""
terraform {{
  required_providers {{
    azurerm = {{
      source = "hashicorp/azurerm"
      version = ">= 2.0.0"
    }}
  }}
}}

provider "azurerm" {{
  subscription_id = "{config_params.get('azure_subscription_id', '')}"
  client_id       = "{config_params.get('azure_client_id', '')}"
  client_secret   = "{config_params.get('azure_client_secret', '')}"
  tenant_id       = "{config_params.get('azure_tenant_id', '')}"
  features        {{}}
}}

resource "azurerm_resource_group" "example" {{
  name     = "example-resources"
  location = "West Europe"
}}
""",
        "digitalocean": f"""
terraform {{
  required_providers {{
    digitalocean = {{
      source = "digitalocean/digitalocean"
      version = ">= 2.0.0"
    }}
  }}
}}

provider "digitalocean" {{
  token = "{config_params.get('do_token', '')}"
}}

resource "digitalocean_droplet" "example" {{
  image  = "ubuntu-20-04-x64"
  name   = "example-droplet"
  region = "nyc1"
  size   = "s-1vcpu-1gb"
}}
""",
        "linode": f"""
terraform {{
  required_providers {{
    linode = {{
      source = "linode/linode"
      version = ">= 1.16.0"
    }}
  }}
}}

provider "linode" {{
  token = "{config_params.get('linode_token', '')}"
}}

resource "linode_instance" "example" {{
  image   = "linode/ubuntu22.04"
  region  = "us-east"
  type    = "g6-nanode-1"
  label   = "example-instance"
}}
"""
    }
    
    try:
        config = terraform_template.get(cloud_platform.lower(), "")
        if config:
            config_path = os.path.join(destination, "main.tf")
            with open(config_path, 'w') as f:
                f.write(config)
            print(f"Terraform config written to {config_path}")
        else:
            print(f"Cloud platform '{cloud_platform}' not supported.")
    except Exception as e:
        print(f"Error writing config: {e}")

def terraform_init(destination):
    try:
        subprocess.run(["terraform", "init"], cwd=destination, check=True)
        print("Terraform initialized successfully.")
    except subprocess.CalledProcessError as e:
        print(f"Terraform init failed: {e}")

def get_cloud_platform():
    platforms = {
        1: 'aws',
        2: 'azure',
        3: 'digitalocean',
        4: 'linode'
    }
    print("Select a cloud platform:")
    for key, value in platforms.items():
        print(f"{key}. {value.capitalize()}")
    
    try:
        selection = int(input("Enter the number corresponding to your choice: ").strip())
        if selection in platforms:
            return platforms[selection]
        else:
            print("Invalid selection. Please try again.")
            return get_cloud_platform()
    except ValueError:
        print("Invalid input. Please enter a number.")
        return get_cloud_platform()

def get_config_params(cloud_platform):
    config_params = {}
    
    if cloud_platform == 'aws':
        config_params['aws_access_key'] = input("Enter your AWS Access Key: ").strip()
        config_params['aws_secret_key'] = input("Enter your AWS Secret Key: ").strip()
    
    elif cloud_platform == 'azure':
        config_params['azure_subscription_id'] = input("Enter your Azure Subscription ID: ").strip()
        config_params['azure_client_id'] = input("Enter your Azure Client ID: ").strip()
        config_params['azure_client_secret'] = input("Enter your Azure Client Secret: ").strip()
        config_params['azure_tenant_id'] = input("Enter your Azure Tenant ID: ").strip()
    
    elif cloud_platform == 'digitalocean':
        config_params['do_token'] = input("Enter your DigitalOcean token: ").strip()

    elif cloud_platform == 'linode':
        config_params['linode_token'] = input("Enter your Linode token: ").strip()

    return config_params

def main():
    print("Welcome to Terraform Project Setup")

    if not is_terraform_installed():
        print("Terraform is not installed. Installing Terraform...")
        install_terraform()

    cloud_platform = get_cloud_platform()
    
    destination_folder = input("Enter the destination folder path: ").strip()

    config_params = get_config_params(cloud_platform)

    create_folder(destination_folder)
    
    write_terraform_config(cloud_platform, destination_folder, config_params)
    
    terraform_init(destination_folder)

if __name__ == "__main__":
    main()
