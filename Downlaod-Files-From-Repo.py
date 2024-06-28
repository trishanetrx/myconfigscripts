import requests
import os

def download_file_from_github(repo, file_name, output_path, token=None):
    url = f"https://raw.githubusercontent.com/{repo}/main/{file_name}"
    headers = {"Accept": "application/vnd.github.v3.raw"}
    if token:
        headers["Authorization"] = f"token {token}"
    
    response = requests.get(url, headers=headers)
    
    if response.status_code == 200:
        with open(output_path, 'wb') as f:
            f.write(response.content)
        print(f"File downloaded successfully: {output_path}")
    else:
        print(f"Failed to download file '{file_name}': {response.status_code} - {response.text}")

def list_files(repo):
    url = f"https://api.github.com/repos/{repo}/contents/"
    response = requests.get(url)
    
    if response.status_code == 200:
        files = [item['name'] for item in response.json() if item['type'] == 'file']
        return files
    else:
        print(f"Failed to list files: {response.status_code} - {response.text}")
        return []

def download_selected_files(repo, output_dir, token=None):
    files = list_files(repo)
    if not files:
        print("No files found in the repository.")
        return
    
    print("List of files in the repository:")
    for index, file_name in enumerate(files, start=1):
        print(f"{index}. {file_name}")
    
    try:
        choices = input("\nEnter the numbers of the files you want to download (comma-separated): ").strip()
        selected_indices = [int(i.strip()) - 1 for i in choices.split(",")]
        selected_files = [files[i] for i in selected_indices]
    except (ValueError, IndexError):
        print("Invalid input. Please enter valid numbers separated by commas.")
        return

    if not os.path.exists(output_dir):
        os.makedirs(output_dir)

    for file_name in selected_files:
        output_path = os.path.join(output_dir, file_name)
        download_file_from_github(repo, file_name, output_path, token)

# Example usage
repo = "trishanetrx/myconfigscripts"  # Replace with your GitHub repository path
output_dir = "/home"  # Replace with the desired local output directory
token = "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"  # Replace with your GitHub token if the repository is private, else set it to None

download_selected_files(repo, output_dir, token)
