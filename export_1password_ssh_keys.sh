
#!/bin/bash

# Script to sync SSH keys from 1Password to local .ssh folder
# Requires: 1Password CLI (op) to be installed and authenticated

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SSH_DIR="$HOME/.ssh"
BACKUP_DIR="$SSH_DIR/backup_$(date +%Y%m%d_%H%M%S)"

# Function to print colored messages
print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_blue() {
    echo -e "${BLUE}$1${NC}"
}

# Check if 1Password CLI is installed
if ! command -v op &> /dev/null; then
    print_error "1Password CLI (op) is not installed."
    echo "Please install it from: https://developer.1password.com/docs/cli/get-started/"
    exit 1
fi

# Get list of accounts
print_info "Checking 1Password accounts..."
accounts_json=$(op account list --format json 2>/dev/null || echo "[]")

if [ "$accounts_json" = "[]" ] || [ -z "$accounts_json" ]; then
    print_error "No 1Password accounts found or not signed in."
    echo "Please run: eval \$(op signin)"
    exit 1
fi

# Display accounts and let user select
echo ""
print_blue "=== Available 1Password Accounts ==="
echo ""

account_count=$(echo "$accounts_json" | jq 'length')
declare -a account_ids
declare -a account_names

index=1
echo "$accounts_json" | jq -c '.[]' | while read -r account; do
    account_id=$(echo "$account" | jq -r '.account_uuid')
    account_email=$(echo "$account" | jq -r '.email')
    account_url=$(echo "$account" | jq -r '.url')
    
    echo "$index) $account_email ($account_url)"
    echo "   Account ID: $account_id"
    echo ""
    
    index=$((index + 1))
done

# Read account selection
echo "Select accounts to sync (enter numbers separated by spaces, or 'all' for all accounts):"
read -r selection

# Parse selection
selected_accounts=()

if [ "$selection" = "all" ] || [ "$selection" = "ALL" ]; then
    print_info "Selected all accounts"
    selected_accounts=($(echo "$accounts_json" | jq -r '.[].account_uuid'))
else
    # Convert selection to array of account IDs
    for num in $selection; do
        if [[ "$num" =~ ^[0-9]+$ ]] && [ "$num" -ge 1 ] && [ "$num" -le "$account_count" ]; then
            account_id=$(echo "$accounts_json" | jq -r ".[$((num-1))].account_uuid")
            selected_accounts+=("$account_id")
        else
            print_warning "Invalid selection: $num (skipping)"
        fi
    done
fi

if [ ${#selected_accounts[@]} -eq 0 ]; then
    print_error "No valid accounts selected."
    exit 1
fi

print_info "Will sync from ${#selected_accounts[@]} account(s)"
echo ""

# Create .ssh directory if it doesn't exist
if [ ! -d "$SSH_DIR" ]; then
    print_info "Creating $SSH_DIR directory..."
    mkdir -p "$SSH_DIR"
    chmod 700 "$SSH_DIR"
fi

# Create backup directory for existing keys
print_info "Creating backup directory at $BACKUP_DIR..."
mkdir -p "$BACKUP_DIR"

# Counter for total keys synced
total_keys_synced=0

# Process each selected account
for account_id in "${selected_accounts[@]}"; do
    account_info=$(echo "$accounts_json" | jq -r ".[] | select(.account_uuid == \"$account_id\")")
    account_email=$(echo "$account_info" | jq -r '.email')
    
    echo ""
    print_blue "=== Processing Account: $account_email ==="
    echo ""
    
    # Get all SSH keys from this account
    print_info "Fetching SSH keys from 1Password account: $account_email..."
    
    # Search for items with SSH key category or tag
    ssh_items=$(op item list --categories "SSH Key" --account "$account_id" --format json 2>/dev/null || echo "[]")
    
    if [ "$ssh_items" = "[]" ]; then
        print_warning "No SSH keys found in 'SSH Key' category."
        print_info "Searching for items with 'ssh' in the title..."
        ssh_items=$(op item list --account "$account_id" --format json 2>/dev/null | jq '[.[] | select(.title | ascii_downcase | contains("ssh"))]' || echo "[]")
    fi
    
    # Count items
    item_count=$(echo "$ssh_items" | jq 'length')
    
    if [ "$item_count" -eq 0 ]; then
        print_warning "No SSH keys found in this account."
        continue
    fi
    
    print_info "Found $item_count SSH key item(s) in this account."
    
    # Process each SSH key
    echo "$ssh_items" | jq -c '.[]' | while read -r item; do
        item_id=$(echo "$item" | jq -r '.id')
        item_title=$(echo "$item" | jq -r '.title')
        
        print_info "Processing: $item_title"
        
        # Get the full item details
        item_details=$(op item get "$item_id" --account "$account_id" --format json)
        
        # Extract private key
        private_key=$(echo "$item_details" | jq -r '.fields[] | select(.label == "private key" or .id == "private_key" or .type == "CONCEALED") | .value' | head -n 1)
        
        # Extract public key
        public_key=$(echo "$item_details" | jq -r '.fields[] | select(.label == "public key" or .id == "public_key") | .value' | head -n 1)
        
        # Generate filename from title (sanitize it)
        filename=$(echo "$item_title" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9._-]/_/g' | sed 's/^_*//' | sed 's/_*$//')
        
        # Add account identifier to filename to avoid conflicts between accounts
        account_short=$(echo "$account_email" | cut -d'@' -f1 | sed 's/[^a-z0-9._-]/_/g')
        
        # Default to id_rsa style name if filename is empty or too generic
        if [ -z "$filename" ] || [ "$filename" = "ssh_key" ]; then
            filename="id_rsa_${account_short}_${item_id:0:8}"
        else
            # Append account identifier if multiple accounts selected
            if [ ${#selected_accounts[@]} -gt 1 ]; then
                filename="${filename}_${account_short}"
            fi
        fi
        
        private_key_path="$SSH_DIR/$filename"
        public_key_path="$SSH_DIR/${filename}.pub"
        
        # Backup existing keys if they exist
        if [ -f "$private_key_path" ]; then
            print_warning "Backing up existing key: $private_key_path"
            cp "$private_key_path" "$BACKUP_DIR/"
            [ -f "$public_key_path" ] && cp "$public_key_path" "$BACKUP_DIR/"
        fi
        
        # Save private key
        if [ -n "$private_key" ] && [ "$private_key" != "null" ]; then
            echo "$private_key" > "$private_key_path"
            chmod 600 "$private_key_path"
            print_info "Saved private key: $private_key_path"
        else
            print_warning "No private key found for: $item_title"
            continue
        fi
        
        # Save public key
        if [ -n "$public_key" ] && [ "$public_key" != "null" ]; then
            echo "$public_key" > "$public_key_path"
            chmod 644 "$public_key_path"
            print_info "Saved public key: $public_key_path"
        else
            print_warning "No public key found for: $item_title"
            # Try to generate public key from private key if possible
            if command -v ssh-keygen &> /dev/null; then
                print_info "Attempting to generate public key from private key..."
                if ssh-keygen -y -f "$private_key_path" > "$public_key_path" 2>/dev/null; then
                    chmod 644 "$public_key_path"
                    print_info "Generated public key: $public_key_path"
                else
                    print_warning "Could not generate public key from private key"
                fi
            fi
        fi
        
        echo ""
    done
    
    # Update total count
    total_keys_synced=$((total_keys_synced + item_count))
done

echo ""
print_blue "=== Sync Complete ==="
print_info "Total SSH keys synced: $total_keys_synced"
print_info "Keys saved to: $SSH_DIR"
print_info "Backup created at: $BACKUP_DIR"

echo ""
echo "To use these keys, you may need to add them to your SSH agent:"
echo "  ssh-add ~/.ssh/your_key_name"
echo ""
echo "Or configure them in ~/.ssh/config"
