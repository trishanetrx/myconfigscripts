import requests

# Cloudflare API credentials
API_TOKEN = 'vpkUjkzP7LlQFiZ-4brTU-O0n9bcK5PZaiwThe18'
ZONE_ID = '61b10f34c3310f625882d330cc01f72c'

# Cloudflare API endpoint
API_URL = f'https://api.cloudflare.com/client/v4/zones/{ZONE_ID}/dns_records'

# Headers for authentication
headers = {
    'Authorization': f'Bearer {API_TOKEN}',
    'Content-Type': 'application/json',
}

def list_dns_records():
    """List all DNS records for the specified zone."""
    response = requests.get(API_URL, headers=headers)
    if response.status_code == 200:
        return response.json()
    else:
        print(f"Error: {response.status_code} - {response.text}")
        return None

def add_dns_record(record_type, name, content, ttl=3600, proxied=False):
    """Add a new DNS record."""
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

def delete_dns_record(record_id):
    """Delete a DNS record."""
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
    # List DNS records initially
    dns_records = list_dns_records()
    print_dns_records(dns_records)

    # User interaction loop
    while True:
        print("\nWhat would you like to do?")
        print("1. Add a new DNS record")
        print("2. Delete an existing DNS record")
        print("3. Exit")

        choice = input("Enter your choice (1/2/3): ")

        if choice == '1':
            # Add a new DNS record
            record_type = input("Enter record type (A/CNAME/MX, etc.): ")
            name = input("Enter record name: ")
            content = input("Enter record content: ")
            proxied = input("Is the record proxied? (True/False): ").lower() == 'true'
            
            new_record = add_dns_record(record_type, name, content, proxied=proxied)
            if new_record:
                print("Added DNS Record:", new_record)

        elif choice == '2':
            # Delete an existing DNS record
            dns_records = list_dns_records()  # Fetch updated list before deletion
            print_dns_records(dns_records)

            delete_choices = input("Enter the numbers of the records to delete (e.g., 1 3 4): ")
            delete_ids = [dns_records['result'][int(idx)-1]['id'] for idx in delete_choices.split() if int(idx) <= len(dns_records['result'])]
            
            for record_id in delete_ids:
                deleted_record = delete_dns_record(record_id)
                if deleted_record:
                    print(f"Deleted DNS Record ID {record_id}")

            # Fetch updated list after deletion
            dns_records = list_dns_records()
            print_dns_records(dns_records)

        elif choice == '3':
            # Exit the program
            print("Exiting...")
            break

        else:
            print("Invalid choice. Please enter 1, 2, or 3.")
