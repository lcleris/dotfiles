#!/usr/bin/env bash
# =============================================================================
# bootstrap.sh — Loan CLERIS | Dotfiles Setup
# Usage: curl -fsSL https://raw.githubusercontent.com/lcleris/dotfiles/main/scripts/bootstrap.sh | bash
# Run only some steps:
#   bash scripts/bootstrap.sh link cliproxyapi
#   curl -fsSL …/bootstrap.sh | bash -s -- packages
# Steps, in order: preflight secrets homebrew clone packages shells link cliproxyapi nushell tools
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
DOTFILES_REPO="git@github.com:lcleris/dotfiles.git"
DOTFILES_DIR="${DOTFILES_DIR:-${HOME}/dotfiles}"
LOG_FILE="${HOME}/.dotfiles_bootstrap.log"
ALL_STEPS=(preflight secrets homebrew clone packages shells link cliproxyapi nushell tools)

# ─── Helpers ──────────────────────────────────────────────────────────────────
log() { echo -e "${BOLD}${BLUE}[bootstrap]${RESET} $*" | tee -a "$LOG_FILE"; }
success() { echo -e "${BOLD}${GREEN}  ✓ $*${RESET}" | tee -a "$LOG_FILE"; }
warn() { echo -e "${BOLD}${YELLOW}  ⚠ $*${RESET}" | tee -a "$LOG_FILE"; }
error() {
  echo -e "${BOLD}${RED}  ✗ $*${RESET}" | tee -a "$LOG_FILE"
  exit 1
}
step() { echo -e "\n${BOLD}${CYAN}━━━ $* ━━━${RESET}" | tee -a "$LOG_FILE"; }
command_exists() { command -v "$1" &>/dev/null; }

# ─── Secrets ──────────────────────────────────────────────────────────────────
# Format: "KEYCHAIN_SERVICE_NAME:Description shown to the user"
REQUIRED_SECRETS=(
  "JIRA_API_TOKEN:Atlassian API token for loan.cleris@vertuoza.com (vertuoza.atlassian.net)"
  "ANTHROPIC_API_KEY:Anthropic API key for omp (pay-per-token, bypasses the Claude subscription OAuth login)"
  "SOPS_AGE_KEY:Age private key for sops (decrypts project .env.encrypted files)"
  "CLIPROXY_API_KEY:Key clients send to CLIProxyAPI (access.api-keys in .config/cli-proxy-api/config.yaml)"
  "CLIPROXY_MANAGEMENT_KEY:CLIProxyAPI management API key (management.secret-key, used by the T3 Code usage view)"
)

step_secrets() {
  step "Secrets — Keychain check"

  for entry in "${REQUIRED_SECRETS[@]}"; do
    local service="${entry%%:*}"
    local description="${entry#*:}"

    if security find-generic-password -a "$USER" -s "$service" -w &>/dev/null; then
      success "${service} → already in Keychain"
      continue
    fi

    echo -e "\n  ${BOLD}${YELLOW}Missing secret: ${service}${RESET}"
    echo -e "  ${description}"
    echo -ne "  ${CYAN}Value:${RESET} "
    # stdin is the script itself under `curl | bash`, so read from the terminal.
    read -rs secret_value </dev/tty
    echo ""

    if [[ -n "$secret_value" ]]; then
      security add-generic-password -a "$USER" -s "$service" -w "$secret_value" -U 2>/dev/null
      success "${service} → stored in Keychain"
    else
      warn "${service} → skipped (empty value)"
    fi
  done
}

# ─── Preflight ────────────────────────────────────────────────────────────────
step_preflight() {
  step "Preflight checks"
  [[ "$(uname)" == "Darwin" ]] || error "This script is designed for macOS only."
  success "macOS $(sw_vers -productVersion)"

  if ! xcode-select -p &>/dev/null; then
    log "Installing Xcode Command Line Tools..."
    xcode-select --install
    until xcode-select -p &>/dev/null; do sleep 5; done
  fi
  success "Xcode Command Line Tools OK"
}

# ─── Homebrew ─────────────────────────────────────────────────────────────────
step_homebrew() {
  step "Homebrew"
  if command_exists brew; then
    warn "Homebrew already installed — updating..."
    GIT_TERMINAL_PROMPT=0 brew update --quiet
  else
    log "Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    if [[ -f "/opt/homebrew/bin/brew" ]]; then
      eval "$(/opt/homebrew/bin/brew shellenv)"
      # shellcheck disable=SC2016
      echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >>"${HOME}/.zprofile"
    else
      eval "$(/usr/local/bin/brew shellenv)"
    fi
  fi
  success "Homebrew $(brew --version | head -1)"
}

# ─── Clone dotfiles ───────────────────────────────────────────────────────────
step_clone() {
  step "Dotfiles"
  if [[ -d "${DOTFILES_DIR}/.git" ]]; then
    warn "Repo already cloned — syncing..."
    local current_branch
    current_branch=$(git -C "${DOTFILES_DIR}" rev-parse --abbrev-ref HEAD)
    log "Current branch: ${current_branch}"

    if git -C "${DOTFILES_DIR}" rev-parse --abbrev-ref "@{upstream}" &>/dev/null; then
      GIT_TERMINAL_PROMPT=0 git -C "${DOTFILES_DIR}" pull --rebase --autostash
    else
      warn "No upstream tracking for '${current_branch}' — fetching from origin..."
      GIT_TERMINAL_PROMPT=0 git -C "${DOTFILES_DIR}" fetch origin
      if git -C "${DOTFILES_DIR}" ls-remote --heads origin "${current_branch}" | grep -q "${current_branch}"; then
        git -C "${DOTFILES_DIR}" branch --set-upstream-to="origin/${current_branch}" "${current_branch}"
        git -C "${DOTFILES_DIR}" pull --rebase --autostash
      else
        warn "Branch '${current_branch}' does not exist on origin — staying on local commit."
      fi
    fi
  else
    log "Cloning ${DOTFILES_REPO}..."
    GIT_TERMINAL_PROMPT=0 git clone "${DOTFILES_REPO}" "${DOTFILES_DIR}"
  fi
  success "Dotfiles → ${DOTFILES_DIR}"
}

# ─── Packages ─────────────────────────────────────────────────────────────────
step_packages() {
  step "Homebrew packages (Brewfile)"
  brew bundle install --no-upgrade --file="${DOTFILES_DIR}/Brewfile"
  success "Brewfile installed"
}

# ─── Shells ───────────────────────────────────────────────────────────────────
# fish is the login shell; nushell stays installed as a fallback.
step_shells() {
  step "Shells"
  local fish_bin
  fish_bin="$(brew --prefix)/bin/fish"

  if ! grep -qxF "$fish_bin" /etc/shells; then
    log "Adding ${fish_bin} to /etc/shells (requires sudo)..."
    echo "$fish_bin" | sudo tee -a /etc/shells >/dev/null
    success "${fish_bin} added to /etc/shells"
  fi

  local current_shell
  current_shell=$(dscl . -read "/Users/${USER}" UserShell 2>/dev/null | awk '{print $2}')
  if [[ "$current_shell" != "$fish_bin" ]]; then
    log "Setting fish as default shell (requires sudo)..."
    sudo dscl . -create "/Users/${USER}" UserShell "$fish_bin"
    success "Default shell → ${fish_bin}"
  else
    success "Default shell already set to fish"
  fi
}

# ─── Symlinks ─────────────────────────────────────────────────────────────────
restow() { stow --restow --adopt "$@"; }
move_aside() { mv "$1" "$1.bak.$(date +%Y%m%d%H%M%S)"; }

step_link() {
  step "Symlinks (stow)"
  mkdir -p "$HOME/.config" "$HOME/.cache/starship" "$HOME/.cache/carapace" "$HOME/.local/bin" "$HOME/.claude" "$HOME/.omp"

  grep -qxF .DS_Store "$HOME/.gitignore_global" 2>/dev/null || echo .DS_Store >>"$HOME/.gitignore_global"
  git config --global core.excludesfile "$HOME/.gitignore_global"

  # Keeps autoMode out of the committed Claude settings.
  git -C "$DOTFILES_DIR" config filter.claude-settings.clean "jq 'del(.autoMode)'"
  git -C "$DOTFILES_DIR" config filter.claude-settings.smudge cat
  git -C "$DOTFILES_DIR" config filter.claude-settings.required true

  # Hand-made links from older setups block stow; stow's own come back on
  # restow. herdr's old folded link must go so the folder below stays real.
  for d in nushell fish nvim starship ghostty zed jiratui herdr; do
    if [[ -L "$HOME/.config/$d" ]]; then rm "$HOME/.config/$d"; fi
  done
  # ~/.claude/commands is one folded link into the repo, so a real folder
  # there is set aside, not merged.
  if [[ -d "$HOME/.claude/commands" && ! -L "$HOME/.claude/commands" ]]; then
    move_aside "$HOME/.claude/commands"
  fi
  # A plain file where the repo has a folder makes stow abort every link.
  local src dest
  while IFS= read -r src; do
    dest="$HOME/${src#"$DOTFILES_DIR"/}"
    if [[ -f "$dest" && ! -L "$dest" ]]; then move_aside "$dest"; fi
  done < <(find "$DOTFILES_DIR/.config" "$DOTFILES_DIR/.claude" -mindepth 1 -type d)

  # Real dir: herdr writes its logs next to config.toml, only that file is stowed.
  mkdir -p "$HOME/.config/herdr"

  # omp and cli-proxy-api go to their native config roots, not ~/.config.
  restow --dir="$DOTFILES_DIR" --target="$HOME/.config" --ignore='^(omp|cli-proxy-api)$' .config
  # .claude/skills holds this repo's own skills, kept out of the global ~/.claude/skills.
  restow --dir="$DOTFILES_DIR" --target="$HOME/.claude" --ignore='^skills$' .claude
  restow --dir="$DOTFILES_DIR/.config" --target="$HOME/.omp" omp
  success "Dotfiles linked"
}

# ─── CLIProxyAPI ──────────────────────────────────────────────────────────────
# Local proxy that spreads Claude Code over several Claude accounts. Its two
# secrets live in the Keychain and go through scripts/cliproxy-secrets.sh as a
# git filter, so the public repo only holds placeholders. OAuth tokens
# (~/.cli-proxy-api/claude-*.json) never enter the repo: on a new machine,
# log in again with `cliproxyapi -claude-login`.
step_cliproxyapi() {
  step "CLIProxyAPI"
  git -C "$DOTFILES_DIR" config filter.cliproxy-secrets.clean "$DOTFILES_DIR/scripts/cliproxy-secrets.sh clean"
  git -C "$DOTFILES_DIR" config filter.cliproxy-secrets.smudge "$DOTFILES_DIR/scripts/cliproxy-secrets.sh smudge"
  git -C "$DOTFILES_DIR" config filter.cliproxy-secrets.required true

  # A fresh clone is checked out before the filter exists, so it still holds
  # the placeholders. Checking the file out again runs the smudge.
  local config=.config/cli-proxy-api/config.yaml
  if grep -q '__CLIPROXY_' "$DOTFILES_DIR/$config"; then
    rm "$DOTFILES_DIR/$config"
    git -C "$DOTFILES_DIR" checkout -- "$config"
  fi

  # Real dir: it holds the OAuth tokens and the logs, only config.yaml is stowed.
  mkdir -p "$HOME/.cli-proxy-api"
  chmod 700 "$HOME/.cli-proxy-api"
  restow --dir="$DOTFILES_DIR/.config" --target="$HOME/.cli-proxy-api" cli-proxy-api

  # The brew service reads $(brew --prefix)/etc/cliproxyapi.conf and takes no -config flag.
  ln -sfn "$HOME/.cli-proxy-api/config.yaml" "$(brew --prefix)/etc/cliproxyapi.conf"
  brew services start cliproxyapi
  success "CLIProxyAPI running"
}

# ─── Nushell ──────────────────────────────────────────────────────────────────
# nushell reads ~/Library/Application Support/nushell, not ~/.config/nushell,
# so these entry points source the real files from the repo. env.nu generates
# the starship, carapace, zoxide and mise init files itself.
# Writes $2 to $1, first copying a different existing $1 to $1.bak.<time>.
write_kept() {
  if [[ -f "$1" ]]; then
    [[ "$(cat "$1")" == "$2" ]] && return 0
    cp "$1" "$1.bak.$(date +%Y%m%d%H%M%S)"
  fi
  printf '%s\n' "$2" >"$1"
}

step_nushell() {
  step "Nushell entry points"
  local dir="$HOME/Library/Application Support/nushell"
  mkdir -p "$dir"
  write_kept "$dir/env.nu" "$(printf '# Managed by scripts/bootstrap.sh\nsource %s\nsource %s' \
    "$DOTFILES_DIR/.config/nushell/env.nu" "$DOTFILES_DIR/.config/nushell/secrets.nu")"
  write_kept "$dir/config.nu" "$(printf '# Managed by scripts/bootstrap.sh\nsource %s' \
    "$DOTFILES_DIR/.config/nushell/config.nu")"
  success "Nushell entry points → ${dir}"
}

# ─── Language tools ───────────────────────────────────────────────────────────
# Runs after `link`, so ~/.config/mise/config.toml is in place.
step_tools() {
  step "Language tools (mise)"
  (cd "$HOME" && mise install --yes)
  success "mise tools installed"
}

finish() {
  echo -e "\n${BOLD}${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
  echo -e "${BOLD}${GREEN}  ✓ Bootstrap complete!${RESET}"
  echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
  echo -e "\n  ${BOLD}Dotfiles:${RESET} ${DOTFILES_DIR}"
  echo -e "  ${BOLD}Logs:    ${RESET} ${LOG_FILE}"
  echo -e "\n  ${YELLOW}➜ Restart your terminal:${RESET} ${CYAN}exec fish${RESET}\n"
}

# ─── Main ─────────────────────────────────────────────────────────────────────
main() {
  local steps=("$@")
  [[ ${#steps[@]} -gt 0 ]] || steps=("${ALL_STEPS[@]}")
  for s in "${steps[@]}"; do
    declare -F "step_$s" >/dev/null || error "Unknown step '$s'. Steps: ${ALL_STEPS[*]}"
  done

  echo -e "\n${BOLD}${CYAN}"
  echo "  ██╗      ██████╗  █████╗ ███╗   ██╗     ██████╗██╗     ███████╗██████╗ ██╗███████╗"
  echo "  ██║     ██╔═══██╗██╔══██╗████╗  ██║    ██╔════╝██║     ██╔════╝██╔══██╗██║██╔════╝"
  echo "  ██║     ██║   ██║███████║██╔██╗ ██║    ██║     ██║     █████╗  ██████╔╝██║███████╗"
  echo "  ██║     ██║   ██║██╔══██║██║╚██╗██║    ██║     ██║     ██╔══╝  ██╔══██╗██║╚════██║"
  echo "  ███████╗╚██████╔╝██║  ██║██║ ╚████║    ╚██████╗███████╗███████╗██║  ██║██║███████║"
  echo "  ╚══════╝ ╚═════╝ ╚═╝  ╚═╝╚═╝  ╚═══╝    ╚═════╝╚══════╝╚══════╝╚═╝  ╚═╝╚═╝╚══════╝"
  echo -e "${RESET}"
  echo -e "  ${BOLD}Dotfiles Bootstrap${RESET}"
  echo -e "  Log: ${LOG_FILE}\n"

  echo "Bootstrap started at $(date): ${steps[*]}" >"$LOG_FILE"

  for s in "${steps[@]}"; do "step_$s"; done
  [[ $# -gt 0 ]] || finish
}

main "$@"
