# Technical Marketing Summary — 1password

## One-Line Positioning

A Bash utility that automates syncing SSH keys from 1Password vaults to the local `~/.ssh` directory, with multi-account support, automatic backups, and public-key derivation.

## Target Users / Personas

- **Developers / DevOps engineers** who store SSH keys in 1Password and need them on local machines for git, SSH, or deployment workflows.
- **Security-conscious teams** managing SSH keys centrally in 1Password and distributing them to workstations.
- **Multi-account users** who have SSH keys across multiple 1Password accounts (personal + work) and want to sync them all in one operation.

## Key Features (Grounded in Code)

- **Multi-account selection** — lists all signed-in 1Password accounts and lets the user pick specific accounts or sync all.
- **SSH Key category search** — queries `op item list --categories "SSH Key"` with a fallback title-based search (`contains("ssh")`).
- **Private & public key extraction** — parses item fields for `private key` and `public key` values via `jq`.
- **Automatic backups** — existing keys in `~/.ssh/` are copied to a timestamped `backup_YYYYMMDD_HHMMSS/` directory before overwriting.
- **Correct file permissions** — private keys set to `chmod 600`, public keys to `chmod 644`.
- **Public key derivation** — if the public key field is missing, generates it from the private key using `ssh-keygen -y`.
- **Sanitized filenames** — item titles are lowercased and sanitized to alphanumeric + `._-`; account email prefix appended for multi-account syncs to avoid conflicts.
- **Colored terminal output** — color-coded `[INFO]`, `[WARNING]`, and `[ERROR]` messages for clear feedback.
- **Error handling** — `set -e` ensures the script exits on any error.

## Technical Differentiators

- **Multi-account aware** — unlike simple single-account scripts, this handles multiple 1Password accounts in one run with conflict-free filenames.
- **Backup-first approach** — no existing key is ever overwritten without a timestamped backup.
- **Fallback search** — if the "SSH Key" category yields no results, falls back to searching item titles for "ssh".
- **Public key auto-generation** — derives missing public keys from private keys, ensuring both files always exist.
- **Pure Bash + jq** — no Python or other runtime dependencies beyond `op`, `jq`, and optionally `ssh-keygen`.

## Use Cases

- Setting up a new workstation by pulling all SSH keys from 1Password.
- Syncing keys after adding a new SSH key to 1Password.
- Distributing different keys from personal and work 1Password accounts to the same machine.
- Recovering SSH keys after a machine rebuild.

## Benefits / Value Proposition

- **Time-saving** — sync all SSH keys in one interactive command instead of manually exporting each key.
- **Safe** — automatic backups prevent accidental key loss.
- **Multi-account** — handle personal and work accounts in a single run.
- **Correct permissions** — keys are written with proper SSH permissions automatically.
- **Self-documenting** — colored output and post-sync instructions guide the user.

## Tech Stack

- **Language**: Bash
- **Dependencies**: 1Password CLI (`op`), `jq`, `ssh-keygen` (optional)
- **Platform**: Linux / macOS (any system with Bash and the 1Password CLI)

## Known Limitations

- Requires the 1Password CLI to be installed and authenticated (`op signin`) before running.
- Requires `jq` to be installed for JSON parsing.
- The script runs in a subshell for the `while read` loop, so the `total_keys_synced` counter may not reflect the actual count across all accounts (variable scope issue in Bash).
- Filenames are derived from item titles; items with identical titles across accounts may conflict if only one account is selected.
- No dry-run mode — the script writes keys immediately (though backups are created).
- Does not automatically add keys to the SSH agent; the user must run `ssh-add` manually.
