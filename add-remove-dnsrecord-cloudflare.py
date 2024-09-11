import requests

# Cloudflare API credentials
ZONE_ID = '61b10f34c3310f625882d330cc01f72c'

# Cloudflare API endpoint
API_URL = f'https://api.cloudflare.com/client/v4/zones/{ZONE_ID}/dns_records'

def get_api_token():
    """Prompt user for the Cloudflare API token."""
    return input("Enter your Cloudflare API token: ")

def list_dns_records(api_token):
    """List all DNS records for the specified zone."""
    headers = {
        'Authorization': f'Bearer {api_token}',
        'Content-Type': 'application/json',
    }
    response = requests.get(API_URL, headers=headers)
    if response.status_code == 200:
        return response.json()
    else:
        print(f"Error: {response.status_code} - {response.text}")
        return None

def add_dns_record(api_token, record_type, name, content, ttl=3600, proxied=False):
    """Add a new DNS record."""
    headers = {
        'Authorization': f'Bearer {api_token}',
        'Content-Type': 'application/json',
    }
    data = {
        'type': record_type,
        'name': name,
        'content': content,
        'ttl': ttl,
        'proxied': proxied
    }
    response = requests.post(API_URL, headers=headers, json=data)
    if response.status_code == 200:
        return response.json()
    else:
        print(f"Error: {response.status_code} - {response.text}")
        return None

def delete_dns_record(api_token, record_id):
    """Delete a DNS record."""
    headers = {
        'Authorization': f'Bearer {api_token}',
        'Content-Type': 'application/json',
    }
    delete_url = f"{API_URL}/{record_id}"
    response = requests.delete(delete_url, headers=headers)
    if response.status_code == 200:
        return response.json()
    else:
        print(f"Error: {response.status_code} - {response.text}")
        return None

def print_dns_records(records):
    """Print DNS records with numbers."""
    if records:
        print("DNS Records:")
        for idx, record in enumerate(records['result'], start=1):
            print(f"{idx}. ID: {record['id']}, Type: {record['type']}, Name: {record['name']}, Content: {record['content']}, Proxied: {record['proxied']}")
    else:
        print("No DNS records found.")

if __name__ == "__main__":
    # Prompt the user for the API token
    api_token = get_api_token()

    # List DNS records initially
    dns_records = list_dns_records(api_token)
    print_dns_records(dns_records)

    # User interaction loop
    while True:
        print("\nWhat would you like to do?")
        print("1. View current DNS records")
        print("2. Add a new DNS record")
        print("3. Delete an existing DNS record")
        print("4. Exit")

        choice = input("Enter your choice (1/2/3/4): ")

        if choice == '1':
            # View current DNS records
            dns_records = list_dns_records(api_token)
            print_dns_records(dns_records)

        elif choice == '2':
            # Add a new DNS record
            print("Select record type:")
            record_types = ["A", "AAAA", "CNAME", "MX", "TXT", "SRV", "NS", "PTR", "CAA"]
            for idx, record_type in enumerate(record_types, start=1):
                print(f"{idx}. {record_type}")
            record_type_choice = input("Enter the number of the record type or 'b' to go back: ")
            if record_type_choice.lower() == 'b':
                continue
            record_type = record_types[int(record_type_choice) - 1]

            name = input("Enter record name: ")
            content = input("Enter record content: ")
            proxied = input("Is the record proxied? (True/False): ").lower() == 'true'
            
            new_record = add_dns_record(api_token, record_type, name, content, proxied=proxied)
            if new_record:
                print("Added DNS Record:", new_record)

        elif choice == '3':
            # Delete an existing DNS record
            dns_records = list_dns_records(api_token)  # Fetch updated list before deletion
            print_dns_records(dns_records)

            delete_choices = input("Enter the numbers of the records to delete (e.g., 1 3 4) or 'b' to go back: ")
            if delete_choices.lower() == 'b':
                continue

            delete_ids = [dns_records['result'][int(idx)-1]['id'] for idx in delete_choices.split() if int(idx) <= len(dns_records['result'])]
            
            for record_id in delete_ids:
                deleted_record = delete_dns_record(api_token, record_id)
                if deleted_record:
                    print(f"Deleted DNS Record ID {record_id}")

            # Fetch updated list after deletion
            dns_records = list_dns_records(api_token)
            print_dns_records(dns_records)

        elif choice == '4':
            # Exit the program
            print("Exiting...")
            break

        else:
            print("Invalid choice. Please enter 1, 2, 3, or 4.")
