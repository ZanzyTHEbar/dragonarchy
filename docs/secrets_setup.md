# Multi-Host Secrets Management Guide

This guide details the process of setting up a new host to use the encrypted secrets managed in this repository. The system uses `sops` and `age` to allow multiple machines to securely access a central, encrypted secrets file.

## Core Concepts

- **One Encrypted File**: A single `secrets/secrets.yaml` file in the repository holds all secrets. It is safe to commit this file because its contents are encrypted.
- **Per-Host Keys**: Each host (e.g., a laptop, a server) has its own unique `age` key pair.
- **Private Keys Stay Local**: The private key is stored locally on each machine in `~/.config/sops/age/keys.txt`. It is crucial that this file is **never** shared or committed to Git.
- **Public Keys Are Shared**: The corresponding public keys are not secret. They are added to the `.sops.yaml` configuration file in the repository. This allows `sops` to encrypt the secrets in a way that any of the authorized hosts can decrypt them.

## Onboarding a New Host: Step-by-Step

Follow these steps on the **new machine** you want to add.

### Step 1: Install Prerequisites

First, you must install the necessary command-line tools. The secrets management script depends on `sops`, `age`, and `yq`.

On an Arch-based distribution, you can install them with:

```bash
sudo pacman -S --noconfirm sops age yq
```

### Step 2: Clone the Repository

If you haven't already, clone this `dotfiles` repository to your new host.

```bash
git clone <repository-url> ~/dotfiles
cd ~/dotfiles
```

### Step 3: Generate a New Key for the Host

Now, generate a unique `age` key pair for this new machine. The `secrets.sh` script provides a command for this.

```bash
./scripts/secrets.sh generate-key
```

This command will:

1. Create a `keys.txt` file at `~/.config/sops/age/keys.txt` containing the new private key.
2. Print the corresponding **public key** to the terminal. It will look something like this:
    `age1...`

**Copy this public key.** You will need it in the next step.

### Step 4: Add the New Public Key to SOPS Configuration

Now you need to authorize this new key by adding it to the central configuration. You can do this from any machine that already has access to the secrets and has the repository cloned.

1. Open the `.sops.yaml` file in the root of this repository.
2. Add the new public key you copied from the new host to the `keys` list. It's a good practice to use a YAML anchor and add a comment to identify which key belongs to which host.

**Example `.sops.yaml`:**

```yaml
keys:
  - &host_one_key age1xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
  - &host_two_key age1yyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyy #<-- Add new key here

creation_rules:
  - path_regex: .*\.yaml$
    key_groups:
      - age:
          - *host_one_key
          - *host_two_key #<-- And also add the anchor here
# ... (repeat for other rules)
```

Make sure you add the new key's anchor (`*host_two_key` in the example) to the `key_groups` section for each rule.

### Step 5: Rekey the Secrets

After adding the new key to `.sops.yaml`, you must re-encrypt the main secrets file. This ensures the new host can decrypt it.

Run the `rekey` command:

```bash
./scripts/secrets.sh rekey
```

This command re-encrypts `secrets/secrets.yaml` using _all_ the public keys listed in your updated `.sops.yaml`.

### Step 6: Commit and Push the Changes

Commit the changes to `.sops.yaml` and the re-encrypted `secrets/secrets.yaml` and push them to your remote repository.

```bash
git add .sops.yaml secrets/secrets.yaml
git commit -m "feat(sops): Add new host and rekey secrets"
git push
```

### Step 7: Install Secrets on the New Host

Your new host is now authorized. Go back to the new host's terminal.

1. Pull the latest changes from the repository:

    ```bash
    git pull
    ```

2. Run the main installation command:

    ```bash
    ./scripts/secrets.sh install
    ```

This will decrypt the secrets file in memory and perform the following actions:

- Install SSH private keys to `~/.ssh/`.
- Install API keys to `~/.config/api/`.
- Create an environment file at `~/.config/secrets/env`.
- Apply templating to your `~/.ssh/config` file.

### Step 8: Source the Environment File

For the environment variables to be available in your shell, you need to source the file created in the previous step. Add the following line to your shell's startup file (e.g., `~/.zshrc` or `~/.bashrc`).

```bash
# Source secrets if the file exists
if [ -f "$HOME/.config/secrets/env" ]; then
  source "$HOME/.config/secrets/env"
fi
```

Restart your shell or open a new terminal, and your secrets will be available as environment variables.

Your new host is now fully onboarded and has access to the repository's secrets.
