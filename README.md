# 1password

A Bash script to sync SSH keys from 1Password to your local `~/.ssh` directory using the 1Password CLI (`op`).

## Overview

`export_1password_ssh_keys.sh` connects to one or more 1Password accounts via the 1Password CLI, retrieves SSH key items, and writes the private and public keys to `~/.ssh/` with appropriate permissions. It backs up any existing keys before overwriting, supports multi-account selection, and can generate public keys from private keys when the public key is missing.

## Prerequisites

- **1Password CLI (`op`)** — installed and authenticated. Install from <https://developer.1password.com/docs/cli/get-started/>.
- **`jq`** — for JSON parsing of `op` CLI output.
- **`ssh-keygen`** (optional) — used to derive public keys from private keys when the public key field is missing.
- A signed-in 1Password account with SSH key items stored.

## Setup

```bash
git clone https://github.com/biofool/1password.git
cd 1password
chmod +x export_1password_ssh_keys.sh
```

### Sign in to 1Password CLI

```bash
eval $(op signin)
```

## How to Run

```bash
./export_1password_ssh_keys.sh
```

The script will:

1. List your available 1Password accounts.
2. Prompt you to select accounts (by number) or choose `all`.
3. Fetch all SSH key items from each selected account (searching the "SSH Key" category, falling back to title-based search).
4. Back up any existing keys in `~/.ssh/` to a timestamped `backup_YYYYMMDD_HHMMSS/` directory.
5. Write private keys (`chmod 600`) and public keys (`chmod 644`) to `~/.ssh/`.
6. If a public key is missing, attempt to generate it from the private key using `ssh-keygen -y`.
7. Print a summary and instructions for adding keys to the SSH agent.

## Project Structure

```
1password/
├── README.md                       # This file
└── export_1password_ssh_keys.sh    # SSH key sync script
```

## Notes

- Key filenames are derived from the 1Password item title (sanitized to lowercase alphanumeric + `._-`).
- When syncing from multiple accounts, the account email prefix is appended to filenames to avoid conflicts.
- Existing keys are backed up before overwriting — no data is lost.
- After syncing, add keys to your SSH agent with `ssh-add ~/.ssh/your_key_name` or configure them in `~/.ssh/config`.
