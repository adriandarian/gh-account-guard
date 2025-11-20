#!/usr/bin/env bash
# Init command: Create example config template

cmd_init() {
  show_banner
  mkdir -p "$(dirname "$CONFIG")"
  if [[ -e "$CONFIG" ]]; then
    echo "Config already exists at $CONFIG"
    echo "Run 'gh account-guard setup' for interactive setup, or edit the file directly."
    exit 0
  fi
  cat > "$CONFIG" <<'YAML'
# Map local paths (prefix-glob) to profiles.
# Longest matching path wins.
# Run 'gh account-guard setup' for interactive configuration.
profiles:
  - name: company
    path: ~/work/company/            # Update with your company repos path
    gh_username: yourcompany-username # Update with your company GitHub username
    git:
      name: "Your Name"
      email: "you@company.com"        # Update with your company email
      signingkey: ""                  # Optional: SSH or GPG signing key
      gpgsign: false
      gpgformat: ssh
    remote_match: "github.com/YourCompany/"  # Optional: remote URL pattern
  - name: personal
    path: ~/                           # Default: matches everything else
    gh_username: yourpersonal-username # Update with your personal GitHub username
    git:
      name: "Your Name (Personal)"
      email: "you+personal@example.com"  # Update with your personal email
      signingkey: ""                      # Optional: SSH or GPG signing key
      gpgsign: false
      gpgformat: ssh
YAML
  echo "✅ Created example config at $CONFIG"
  echo ""
  echo "Edit the file directly, or run 'gh account-guard setup' for interactive setup."
}

