Love this idea. You can solve it at two layers:

1. **Bullet-proof baseline (no plugin required): Git’s `includeIf` + hooks**
2. **Nice UX: a `gh` extension that auto-switches your GitHub CLI account *and* enforces the right Git identity per repo**

Below I give you both. If you only do (1), you’ll already fix the “wrong author on commit” + most compliance pain. (2) adds auto `gh auth switch` + one-command enforcement.

---

# 1) Rock-solid baseline: `includeIf` + policy hook

### A. Path-scoped identities with `includeIf`

Put this in `~/.gitconfig` (adjust paths):

```ini
# ~/.gitconfig
[user]
    name = Adrian (Personal)
    email = you+personal@example.com
    signingkey = ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAA...personal
[gpg]
    format = ssh
[commit]
    gpgsign = true

# Company repos live anywhere under ~/work/company/
[includeIf "gitdir:~/work/company/"]
    path = ~/.gitconfig-company
```

Then create `~/.gitconfig-company`:

```ini
# ~/.gitconfig-company
[user]
    name = Adrian Darian
    email = adrian.darian@yourcompany.com
    signingkey = ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAA...company
[gpg]
    format = ssh
[commit]
    gpgsign = true
[tag]
    gpgsign = true
```

Now any repo under `~/work/company/` automatically uses the **company** identity, everything else uses **personal**. No manual swapping, no mistakes.

> Windows: use `gitdir:C:/Users/you/work/company/` and put this in `%USERPROFILE%\.gitconfig`.

### B. Guardrail hook (blocks non-compliant commits)

Install a `pre-commit` hook in your company repos (or globally via a template dir) that enforces email domain + signing:

```bash
# .git/hooks/pre-commit (chmod +x)
#!/usr/bin/env bash
set -euo pipefail

email=$(git config user.email || true)
name=$(git config user.name || true)
sig=$(git config --get commit.gpgsign || echo "false")
remote=$(git config --get remote.origin.url || true)

req_domain="@yourcompany.com"

fail() { echo "❌ $1" >&2; exit 1; }

[[ -z "$email" ]] && fail "Git user.email not set."
[[ -z "$name"  ]] && fail "Git user.name not set."
[[ "$sig" != "true" ]] && fail "Commit signing must be enabled (commit.gpgsign=true)."

if [[ "$remote" == *"github.com/YourCompany/"* ]] || [[ "$PWD" == *"/work/company/"* ]]; then
  [[ "$email" == *"$req_domain" ]] || fail "Email '$email' is not a company address ($req_domain)."
fi

# Optionally verify SSH signing key is the company one:
# key=$(git config user.signingkey || true)
# [[ "$key" == *"AAAAC3NzaC1lZDI1NTE5AAAA...company"* ]] || fail "Wrong signing key."
```

This prevents “oops” commits from ever being created with the wrong identity.

---

# 2) GH CLI extension: **`gh-account-guard`**

This adds:

* Auto-`gh auth switch -u <username>` when you’re in a repo (so `gh pr/issue` use the right token/account).
* `gh account-guard fix` to enforce local git config (name/email/signing) for the current repo.
* Optional shell hook to run the guard on directory changes.

### A. Extension scaffold

Create a repo named `gh-account-guard` (that makes it installable via `gh extension install <you>/gh-account-guard`). Put this executable at the root, named exactly `gh-account-guard`:

```bash
#!/usr/bin/env bash
set -euo pipefail

CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}/gh/account-guard.yml"

usage() {
  cat <<'EOF'
gh account-guard <command>

Commands:
  init                 Create example config at ~/.config/gh/account-guard.yml
  status               Show which profile matches CWD and current gh/git identity
  fix                  Apply matching profile to current repo (git config, signing)
  switch               Run `gh auth switch` to the matching profile
  install-shell-hook   Prints a shell snippet for auto-enforcement on directory change
EOF
}

need_cmd() { command -v "$1" >/dev/null 2>&1 || { echo "Missing '$1'." >&2; exit 1; }; }

yaml_get() {
  # requires yq (mikefarah). Keep it simple and explicit.
  yq "$@"
}

match_profile() {
  local dir="${1:-$PWD}"
  local best=""
  local best_len=0

  # Iterate profiles and choose the longest matching glob
  local n
  n=$(yaml_get '.profiles | length' "$CONFIG" 2>/dev/null || echo 0)
  for ((i=0; i<n; i++)); do
    local pattern
    pattern=$(yaml_get ".profiles[$i].path" "$CONFIG")
    if [[ -n "$pattern" ]]; then
      # Expand ~
      pattern=${pattern/#\~/$HOME}
      if [[ "$dir" == $pattern* ]]; then
        local len=${#pattern}
        if (( len > best_len )); then
          best_len=$len
          best=$i
        fi
      fi
    fi
  done

  echo "${best:-}"
}

cmd_init() {
  mkdir -p "$(dirname "$CONFIG")"
  if [[ -e "$CONFIG" ]]; then
    echo "Config already exists at $CONFIG"
    exit 0
  fi
  cat > "$CONFIG" <<'YAML'
# Map local paths (prefix-glob) to profiles.
# Longest matching path wins.
profiles:
  - name: company
    path: ~/work/company/            # any repo under here
    gh_username: yourcompany-username
    git:
      name: "Adrian Darian"
      email: "adrian.darian@yourcompany.com"
      signingkey: "ssh-ed25519 AAAA...company"
      gpgsign: true
      gpgformat: ssh
    remote_match: "github.com/YourCompany/"
  - name: personal
    path: ~/
    gh_username: yourpersonal-username
    git:
      name: "Adrian (Personal)"
      email: "you+personal@example.com"
      signingkey: "ssh-ed25519 AAAA...personal"
      gpgsign: true
      gpgformat: ssh
YAML
  echo "Wrote $CONFIG"
}

cmd_status() {
  [[ -f "$CONFIG" ]] || { echo "No config at $CONFIG. Run: gh account-guard init"; exit 1; }
  idx=$(match_profile "$PWD")
  if [[ -z "$idx" ]]; then
    echo "No matching profile for $PWD"
    exit 1
  fi
  name=$(yaml_get ".profiles[$idx].name" "$CONFIG")
  gh_u=$(yaml_get ".profiles[$idx].gh_username" "$CONFIG")
  echo "Matched profile: $name (gh user: $gh_u)"
  echo "Current gh auth:"
  gh auth status || true
  echo
  echo "Current git identity:"
  echo "  user.name  = $(git config --get user.name || echo '<unset>')"
  echo "  user.email = $(git config --get user.email || echo '<unset>')"
  echo "  gpgsign    = $(git config --get commit.gpgsign || echo '<unset>')"
}

cmd_fix() {
  need_cmd yq
  [[ -d .git ]] || { echo "Not a git repo."; exit 1; }
  idx=$(match_profile "$PWD") || true
  [[ -n "$idx" ]] || { echo "No matching profile for $PWD"; exit 1; }

  name=$(yaml_get ".profiles[$idx].git.name" "$CONFIG")
  email=$(yaml_get ".profiles[$idx].git.email" "$CONFIG")
  skey=$(yaml_get ".profiles[$idx].git.signingkey" "$CONFIG")
  gpgf=$(yaml_get ".profiles[$idx].git.gpgformat" "$CONFIG")
  gpgs=$(yaml_get ".profiles[$idx].git.gpgsign" "$CONFIG")
  rmatch=$(yaml_get ".profiles[$idx].remote_match" "$CONFIG" 2>/dev/null || echo "")

  if [[ -n "$rmatch" ]]; then
    remote=$(git config --get remote.origin.url || echo "")
    if [[ -n "$remote" && "$remote" != *"$rmatch"* ]]; then
      echo "⚠️  Remote '$remote' does not match '$rmatch' for this profile."
    }
  fi

  git config --local user.name  "$name"
  git config --local user.email "$email"
  [[ -n "$skey" ]] && git config --local user.signingkey "$skey"
  [[ -n "$gpgf" ]] && git config --local gpg.format "$gpgf"
  [[ -n "$gpgs" ]] && git config --local commit.gpgsign "$gpgs"

  echo "✅ Set repo identity to: $name <$email>; signing=$(git config --get commit.gpgsign)"
}

cmd_switch() {
  need_cmd yq
  idx=$(match_profile "$PWD") || true
  [[ -n "$idx" ]] || { echo "No matching profile for $PWD"; exit 1; }
  gh_u=$(yaml_get ".profiles[$idx].gh_username" "$CONFIG")
  if [[ -z "$gh_u" || "$gh_u" == "null" ]]; then
    echo "No gh_username configured for this profile."
    exit 1
  fi
  gh auth switch -u "$gh_u"
}

cmd_install_shell_hook() {
  cat <<'SH'
# --- gh-account-guard shell hook ---
# Add to your shell rc (zshrc, bashrc) or as a Starship pre_cmd hook.
function __gh_account_guard_chpwd() {
  command -v gh >/dev/null || return
  # Only run inside a git repo
  git rev-parse --is-inside-work-tree >/dev/null 2>&1 || return
  # Enforce git identity & switch gh account
  gh account-guard fix >/dev/null 2>&1 || true
  gh account-guard switch >/dev/null 2>&1 || true
}
# zsh:
autoload -U add-zsh-hook 2>/dev/null && add-zsh-hook chpwd __gh_account_guard_chpwd
# bash:
PROMPT_COMMAND="__gh_account_guard_chpwd; $PROMPT_COMMAND"
# --- end gh-account-guard hook ---
SH
}

main() {
  sub="${1:-}"; shift || true
  case "$sub" in
    init) cmd_init "$@";;
    status) cmd_status "$@";;
    fix) cmd_fix "$@";;
    switch) cmd_switch "$@";;
    install-shell-hook) cmd_install_shell_hook "$@";;
    ""|-h|--help|help) usage;;
    *) echo "Unknown command: $sub" >&2; usage; exit 1;;
  esac
}
main "$@"
```

Make it executable:

```bash
chmod +x gh-account-guard
```

**Install locally to test:**

```bash
gh extension install .
```

### B. Config file (example)

`~/.config/gh/account-guard.yml` (created by `gh account-guard init`—edit it):

```yaml
profiles:
  - name: company
    path: ~/work/company/
    gh_username: yourcompany-username
    git:
      name: "Adrian Darian"
      email: "adrian.darian@yourcompany.com"
      signingkey: "ssh-ed25519 AAAA...company"
      gpgsign: true
      gpgformat: ssh
    remote_match: "github.com/YourCompany/"
  - name: personal
    path: ~/
    gh_username: yourpersonal-username
    git:
      name: "Adrian (Personal)"
      email: "you+personal@example.com"
      signingkey: "ssh-ed25519 AAAA...personal"
      gpgsign: true
      gpgformat: ssh
```

### C. Daily usage

* One-time: `gh account-guard init`
* Optional: add the shell hook to auto-enforce on `cd`:

  ```bash
  gh account-guard install-shell-hook >> ~/.zshrc   # or ~/.bashrc
  ```
* On demand in a repo:

  ```bash
  gh account-guard status
  gh account-guard fix
  gh account-guard switch
  ```

### D. Notes & edge cases

* **`gh auth switch`**: works with multiple `github.com` identities. Make sure both are logged in:
  `gh auth login -u yourcompany-username` and `gh auth login -u yourpersonal-username`.
* **Git is the source of truth for author/compliance.** The extension sets repo-local `user.*` + signing so `git commit` is correct even outside `gh`.
* **Remotes & submodules**: the hook checks `remote.origin.url`; if you mix remotes, keep them under the right path or add more profiles with `remote_match`.
* **Windows**: `yq` can be installed via `choco install yq`. Update `path:` globs to Windows paths.
* **Signing**: if you use OpenPGP instead of SSH signing, swap `gpg.format=ssh` + `user.signingkey` accordingly.

---

## Quick start if you want the minimum to stop mistakes today

1. Drop the `includeIf` blocks in `~/.gitconfig` + `~/.gitconfig-company`.
2. Add the `pre-commit` hook to your company repos (or set a global template directory: `git config --global init.templatedir ~/.git-template` and put hooks in `~/.git-template/hooks/`).
3. (Optional) Install the `gh-account-guard` extension for auto `gh auth switch` and one-shot `gh account-guard fix`.

If you want, tell me your actual paths, company domain, and preferred signing method (SSH vs GPG), and I’ll tailor the config and the hook exactly to your setup.
