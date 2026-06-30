#!/usr/bin/env bash
# =============================================================================
# git.sh — Loan CLERIS | Git SSH Signing Setup
# Usage: bash ~/dotfiles/scripts/git.sh
# =============================================================================

set -euo pipefail

# ─── Colors ───────────────────────────────────────────────────────────────────
RESET="\033[0m"
BOLD="\033[1m"
GREEN="\033[0;32m"
YELLOW="\033[0;33m"
RED="\033[0;31m"
BLUE="\033[0;34m"
CYAN="\033[0;36m"

# ─── Config ───────────────────────────────────────────────────────────────────
GIT_NAME="Loan CLERIS"
GIT_EMAIL="loan.cleris@gmail.com"
SSH_KEY="${HOME}/.ssh/id_ed25519"
SSH_CONFIG="${HOME}/.ssh/config"
ALLOWED_SIGNERS="${HOME}/.ssh/allowed_signers"

# ─── Helpers ──────────────────────────────────────────────────────────────────
log()     { echo -e "${BOLD}${BLUE}[git.sh]${RESET} $*"; }
success() { echo -e "${BOLD}${GREEN}  ✓ $*${RESET}"; }
warn()    { echo -e "${BOLD}${YELLOW}  ⚠ $*${RESET}"; }
error()   { echo -e "${BOLD}${RED}  ✗ $*${RESET}"; exit 1; }
step()    { echo -e "\n${BOLD}${CYAN}━━━ $* ━━━${RESET}"; }
command_exists() { command -v "$1" &>/dev/null; }

# ─── SSH Key ──────────────────────────────────────────────────────────────────
setup_ssh_key() {
  step "SSH Key"

  mkdir -p "${HOME}/.ssh"
  chmod 700 "${HOME}/.ssh"

  if [[ -f "${SSH_KEY}" ]]; then
    warn "Key already exists → ${SSH_KEY} (skipping generation)"
  else
    log "Generating new ed25519 SSH key..."
    ssh-keygen -t ed25519 -C "${GIT_EMAIL}" -f "${SSH_KEY}"
    success "Key generated → ${SSH_KEY}"
  fi

  # Add to ssh-agent with macOS Keychain
  eval "$(ssh-agent -s)" &>/dev/null
  ssh-add --apple-use-keychain "${SSH_KEY}" 2>/dev/null || \
    ssh-add "${SSH_KEY}"
  success "Key loaded in ssh-agent"
}

# ─── SSH Config ───────────────────────────────────────────────────────────────
setup_ssh_config() {
  step "SSH Config"

  local block="Host github.com
  AddKeysToAgent yes
  UseKeychain yes
  IdentityFile ${SSH_KEY}"

  if grep -q "Host github.com" "${SSH_CONFIG}" 2>/dev/null; then
    warn "github.com block already in ${SSH_CONFIG} (skipping)"
  else
    echo "" >> "${SSH_CONFIG}"
    echo "${block}" >> "${SSH_CONFIG}"
    chmod 600 "${SSH_CONFIG}"
    success "github.com block added to ${SSH_CONFIG}"
  fi
}

# ─── Git Config ───────────────────────────────────────────────────────────────
setup_git_config() {
  step "Git Config"

  git config --global user.name     "${GIT_NAME}"
  git config --global user.email    "${GIT_EMAIL}"
  git config --global gpg.format    ssh
  git config --global user.signingkey "${SSH_KEY}.pub"
  git config --global commit.gpgsign true
  git config --global tag.gpgsign   true
  git config --global gpg.ssh.allowedSignersFile "${ALLOWED_SIGNERS}"

  # Remove conflicting gpg.program if set
  git config --global --unset gpg.program 2>/dev/null || true

  success "Git configured for SSH signing"
}

# ─── Allowed Signers ──────────────────────────────────────────────────────────
setup_allowed_signers() {
  step "Allowed Signers"

  local pubkey
  pubkey=$(cat "${SSH_KEY}.pub")

  if grep -qF "${pubkey}" "${ALLOWED_SIGNERS}" 2>/dev/null; then
    warn "${ALLOWED_SIGNERS} already contains this key (skipping)"
  else
    echo "${GIT_EMAIL} ${pubkey}" >> "${ALLOWED_SIGNERS}"
    chmod 600 "${ALLOWED_SIGNERS}"
    success "Key added to ${ALLOWED_SIGNERS}"
  fi
}

# ─── GitHub Keys ──────────────────────────────────────────────────────────────
upload_github_keys() {
  step "GitHub Keys"

  if ! command_exists gh; then
    warn "gh CLI not found — skipping GitHub upload"
    warn "Run manually: gh ssh-key add ${SSH_KEY}.pub --type auth"
    warn "Run manually: gh ssh-key add ${SSH_KEY}.pub --type signing"
    return
  fi

  if ! gh auth status &>/dev/null; then
    warn "Not logged into GitHub CLI"
    log "Run: gh auth login"
    return
  fi

  # Ensure signing scope
  if ! gh auth status 2>&1 | grep -q "admin:ssh_signing_key"; then
    log "Refreshing gh auth with signing scope..."
    gh auth refresh -h github.com -s admin:ssh_signing_key
  fi

  local pubkey
  pubkey=$(cat "${SSH_KEY}.pub")

  # Auth key
  if gh ssh-key list 2>/dev/null | grep -qF "${pubkey%%=*}"; then
    warn "Auth key already on GitHub (skipping)"
  else
    gh ssh-key add "${SSH_KEY}.pub" --type auth --title "$(hostname)-auth" && \
      success "Auth key uploaded to GitHub"
  fi

  # Signing key
  if gh ssh-key list 2>/dev/null | grep -q "signing" | grep -qF "${pubkey%%=*}" 2>/dev/null; then
    warn "Signing key already on GitHub (skipping)"
  else
    gh ssh-key add "${SSH_KEY}.pub" --type signing --title "$(hostname)-signing" && \
      success "Signing key uploaded to GitHub"
  fi
}

# ─── Verify ───────────────────────────────────────────────────────────────────
verify() {
  step "Verification"

  local sig
  sig=$(echo "test" | ssh-keygen -Y sign -n git -f "${SSH_KEY}" 2>/dev/null | head -1)

  if [[ "${sig}" == "-----BEGIN SSH SIGNATURE-----" ]]; then
    success "SSH signing works"
  else
    warn "Could not verify signing — check your key passphrase"
  fi

  log "Git signing config:"
  git config --global --list | grep -E "(sign|gpg|user)" | \
    while IFS= read -r line; do echo -e "    ${CYAN}${line}${RESET}"; done
}

# ─── Main ─────────────────────────────────────────────────────────────────────
main() {
  echo -e "\n${BOLD}${CYAN}  Git SSH Signing Setup${RESET}\n"

  setup_ssh_key
  setup_ssh_config
  setup_git_config
  setup_allowed_signers
  upload_github_keys
  verify

  echo -e "\n${BOLD}${GREEN}━━━ Done ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
  echo -e "${GREEN}  Commits will show as Verified on GitHub.${RESET}"
  echo -e "${GREEN}  Public key: $(cat "${SSH_KEY}.pub")${RESET}\n"
}

main "$@"
