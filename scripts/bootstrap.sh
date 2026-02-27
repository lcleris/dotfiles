#!/usr/bin/env bash
# =============================================================================
# bootstrap.sh — Loan CLERIS | Dotfiles Setup
# Usage: curl -fsSL https://raw.githubusercontent.com/TheHikuro/dotfiles/main/scripts/bootstrap.sh | bash
# Options:
#   ANSIBLE_TAGS="nvim,nushell" ./bootstrap.sh   → n'installer que certains rôles
#   CHECK=1 ./bootstrap.sh                        → dry-run, ne modifie rien
# =============================================================================

set -euo pipefail

# ─── Colors ──────────────────────────────────────────────────────────────────
RESET="\033[0m"
BOLD="\033[1m"
GREEN="\033[0;32m"
YELLOW="\033[0;33m"
RED="\033[0;31m"
BLUE="\033[0;34m"
CYAN="\033[0;36m"

# ─── Config ───────────────────────────────────────────────────────────────────
DOTFILES_REPO="https://github.com/TheHikuro/dotfiles.git"
DOTFILES_DIR="${HOME}/dotfiles"
LOG_FILE="${HOME}/.dotfiles_bootstrap.log"
ANSIBLE_TAGS="${ANSIBLE_TAGS:-"all"}"

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
REQUIRED_SECRETS=(
  "AKKA_LICENSE_KEY:Akka License Key (Lightbend)"
  #"GITHUB_TOKEN:GitHub Personal Access Token"  ←  add here for new secrets that should be stored in the Keychain and injected dans Ansible via lookup
)

collect_secrets() {
  step "Secrets — vérification du Keychain"

  local dry_run=${CHECK:-0}
  local all_present=true

  for entry in "${REQUIRED_SECRETS[@]}"; do
    local service="${entry%%:*}"
    local description="${entry#*:}"

    if security find-generic-password -a "$USER" -s "$service" -w &>/dev/null; then
      success "${service} → déjà dans le Keychain"
    else
      all_present=false
      if [[ "$dry_run" == "1" ]]; then
        warn "${service} → MANQUANT (sera demandé au vrai bootstrap)"
      else
        echo -e "\n  ${BOLD}${YELLOW}Secret manquant : ${service}${RESET}"
        echo -e "  ${description}"
        echo -ne "  ${CYAN}Valeur :${RESET} "
        # -s pour ne pas afficher la saisie
        read -rs secret_value
        echo ""

        if [[ -n "$secret_value" ]]; then
          security add-generic-password \
            -a "$USER" \
            -s "$service" \
            -w "$secret_value" \
            -U 2>/dev/null
          success "${service} → stocké dans le Keychain"
        else
          warn "${service} → ignoré (valeur vide)"
        fi
      fi
    fi
  done

  if [[ "$all_present" == "true" ]]; then
    success "Tous les secrets sont présents"
  fi
}
preflight() {
  step "Preflight checks"
  [[ "$(uname)" == "Darwin" ]] || error "Ce script est conçu pour macOS uniquement."
  success "macOS $(sw_vers -productVersion)"

  if ! xcode-select -p &>/dev/null; then
    log "Installation des Xcode Command Line Tools..."
    xcode-select --install
    until xcode-select -p &>/dev/null; do sleep 5; done
  fi
  success "Xcode Command Line Tools OK"
}

# ─── Homebrew ─────────────────────────────────────────────────────────────────
install_homebrew() {
  step "Homebrew"
  if command_exists brew; then
    warn "Homebrew déjà installé — mise à jour..."
    # GIT_TERMINAL_PROMPT=0 évite le blocage sur les credentials git
    # || true évite que l'erreur du tap déprécié cask-fonts ne stoppe le script
    GIT_TERMINAL_PROMPT=0 brew update --quiet 2>&1 | grep -v "cask-fonts" | grep -v "fatal:" || true

    # Supprimer le tap déprécié homebrew/cask-fonts s'il est encore présent
    if brew tap | grep -q "homebrew/cask-fonts"; then
      warn "Suppression du tap déprécié homebrew/cask-fonts..."
      brew untap homebrew/homebrew-cask-fonts 2>/dev/null || true
    fi
  else
    log "Installation de Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    if [[ -f "/opt/homebrew/bin/brew" ]]; then
      eval "$(/opt/homebrew/bin/brew shellenv)"
      echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >>"${HOME}/.zprofile"
    else
      eval "$(/usr/local/bin/brew shellenv)"
    fi
  fi
  success "Homebrew $(brew --version | head -1)"
}

# ─── Git ──────────────────────────────────────────────────────────────────────
install_git() {
  step "Git"
  command_exists git || brew install git
  success "Git $(git --version | awk '{print $3}')"
}

# ─── MISE ─────────────────────────────────────────────────────────────────────
install_mise() {
  step "MISE (version manager universel)"
  if command_exists mise; then
    warn "MISE déjà installé ($(mise --version)) — skip"
  else
    log "Installation de MISE..."
    brew install mise
    eval "$(mise activate bash)"
    grep -q "mise activate" "${HOME}/.zshrc" 2>/dev/null ||
      echo 'eval "$(mise activate zsh)"' >>"${HOME}/.zshrc"
  fi
  success "MISE $(mise --version)"
}

# ─── Ansible ──────────────────────────────────────────────────────────────────
install_ansible() {
  step "Ansible"
  if command_exists ansible; then
    warn "Ansible déjà installé — skip"
  else
    brew install ansible
    # Collection community.general pour git_config
    ansible-galaxy collection install community.general
  fi
  success "Ansible $(ansible --version | head -1 | awk '{print $NF}')"
}

# ─── Clone dotfiles ───────────────────────────────────────────────────────────
clone_dotfiles() {
  step "Dotfiles"
  if [[ -d "${DOTFILES_DIR}/.git" ]]; then
    warn "Repo déjà cloné — synchronisation..."
    local current_branch
    current_branch=$(git -C "${DOTFILES_DIR}" rev-parse --abbrev-ref HEAD)
    log "Branche courante : ${current_branch}"

    # Vérifier si la branche a un upstream configuré
    if git -C "${DOTFILES_DIR}" rev-parse --abbrev-ref "@{upstream}" &>/dev/null; then
      GIT_TERMINAL_PROMPT=0 git -C "${DOTFILES_DIR}" pull --rebase --autostash
    else
      # Pas de tracking → fetch + set upstream sur origin/main ou origin/<branche>
      warn "Pas de tracking configuré pour '${current_branch}' — fetch depuis origin..."
      GIT_TERMINAL_PROMPT=0 git -C "${DOTFILES_DIR}" fetch origin
      if git -C "${DOTFILES_DIR}" ls-remote --heads origin "${current_branch}" | grep -q "${current_branch}"; then
        git -C "${DOTFILES_DIR}" branch --set-upstream-to="origin/${current_branch}" "${current_branch}"
        git -C "${DOTFILES_DIR}" pull --rebase --autostash
      else
        warn "La branche '${current_branch}' n'existe pas sur origin — on reste sur le commit local."
      fi
    fi
  else
    log "Clonage de ${DOTFILES_REPO}..."
    GIT_TERMINAL_PROMPT=0 git clone "${DOTFILES_REPO}" "${DOTFILES_DIR}"
  fi
  success "Dotfiles → ${DOTFILES_DIR}"
}

# ─── Run Ansible ──────────────────────────────────────────────────────────────
run_ansible() {
  step "Playbook Ansible"

  # Le playbook s'appelle setup.yml (pas macbook-setup.yml)
  local playbook="${DOTFILES_DIR}/ansible/setup.yml"
  local inventory="${DOTFILES_DIR}/ansible/hosts.ini"

  [[ -f "$playbook" ]] || error "Playbook introuvable : ${playbook}"

  local cmd=(ansible-playbook "$playbook" -i "$inventory" --diff)

  [[ "$ANSIBLE_TAGS" != "all" ]] && cmd+=(--tags "$ANSIBLE_TAGS") &&
    log "Tags : ${ANSIBLE_TAGS}"

  [[ "${CHECK:-0}" == "1" ]] && cmd+=(--check) && warn "Mode dry-run (CHECK=1)"

  "${cmd[@]}"
  success "Playbook OK"
}

# ─── Post-install ─────────────────────────────────────────────────────────────
post_install() {
  step "Post-installation"

  # MISE : installer tous les outils (node, rust, ruby, java...)
  if [[ -f "${DOTFILES_DIR}/.mise.toml" ]]; then
    log "Installation des outils via MISE..."
    mise install --yes
    success "Outils MISE installés"
  fi

  echo -e "\n${BOLD}${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
  echo -e "${BOLD}${GREEN}  ✓ Bootstrap terminé !${RESET}"
  echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
  echo -e "\n  ${BOLD}Dotfiles :${RESET} ${DOTFILES_DIR}"
  echo -e "  ${BOLD}Logs     :${RESET} ${LOG_FILE}"
  echo -e "\n  ${YELLOW}➜ Redémarre ton terminal :${RESET}"
  echo -e "    ${CYAN}exec nu${RESET}   (NuShell)"
  echo -e "    ${CYAN}exec zsh${RESET}  (fallback)\n"
}

# ─── Main ────────────────────────────────────────────────────────────────────
main() {
  echo -e "\n${BOLD}${CYAN}"
  echo "  ██╗      ██████╗  █████╗ ███╗   ██╗     ██████╗██╗     ███████╗██████╗ ██╗███████╗"
  echo "  ██║     ██╔═══██╗██╔══██╗████╗  ██║    ██╔════╝██║     ██╔════╝██╔══██╗██║██╔════╝"
  echo "  ██║     ██║   ██║███████║██╔██╗ ██║    ██║     ██║     █████╗  ██████╔╝██║███████╗"
  echo "  ██║     ██║   ██║██╔══██║██║╚██╗██║    ██║     ██║     ██╔══╝  ██╔══██╗██║╚════██║"
  echo "  ███████╗╚██████╔╝██║  ██║██║ ╚████║    ╚██████╗███████╗███████╗██║  ██║██║███████║"
  echo "  ╚══════╝ ╚═════╝ ╚═╝  ╚═╝╚═╝  ╚═══╝    ╚═════╝╚══════╝╚══════╝╚═╝  ╚═╝╚═╝╚══════╝"
  echo -e "${RESET}"
  echo -e "  ${BOLD}Dotfiles Bootstrap${RESET}"
  echo -e "  Log : ${LOG_FILE}\n"

  mkdir -p "$(dirname "$LOG_FILE")"
  echo "Bootstrap started at $(date)" >"$LOG_FILE"

  preflight
  collect_secrets
  install_homebrew
  install_git
  install_mise
  install_ansible
  clone_dotfiles
  run_ansible
  post_install
}

main "$@"
