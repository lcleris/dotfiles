#!/bin/bash

# Nushell Complete Setup Script
# This script automates the complete Nushell configuration setup
# including all dependencies and proper configuration sourcing

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Helper functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if running on macOS
if [[ "$OSTYPE" != "darwin"* ]]; then
    log_error "This script is designed for macOS only"
    exit 1
fi

# Check if Homebrew is installed
if ! command -v brew &> /dev/null; then
    log_error "Homebrew is not installed. Please install Homebrew first."
    exit 1
fi

# Set dotfiles path
DOTFILES_PATH="${HOME}/dotfiles"
if [ ! -d "$DOTFILES_PATH" ]; then
    log_error "Dotfiles directory not found at $DOTFILES_PATH"
    exit 1
fi

log_info "Starting Nushell complete setup..."

# Step 1: Install Nushell and dependencies
log_info "Installing Nushell and dependencies via Homebrew..."
brew install nushell zoxide carapace starship

# Step 2: Create necessary directories
log_info "Creating necessary directories..."
mkdir -p "${HOME}/.cache/starship"
mkdir -p "${HOME}/.cache/carapace"
mkdir -p "${HOME}/Library/Application Support/nushell"

# Step 3: Remove existing symlink if it exists
log_info "Setting up configuration symlinks..."
if [ -L "${HOME}/.config/nushell" ]; then
    log_info "Removing existing nushell config symlink..."
    rm "${HOME}/.config/nushell"
fi

# Create symlink to dotfiles
ln -sf "${DOTFILES_PATH}/.config/nushell" "${HOME}/.config/nushell"
ln -sf "${DOTFILES_PATH}/.config/starship" "${HOME}/.config/starship"

# Step 4: Generate initialization files
log_info "Generating initialization files..."

# Generate starship init file
if [ ! -f "${HOME}/.cache/starship/init.nu" ]; then
    starship init nu > "${HOME}/.cache/starship/init.nu"
    log_success "Generated starship init file"
else
    log_warning "Starship init file already exists, skipping..."
fi

# Generate zoxide init file
if [ ! -f "${HOME}/.zoxide.nu" ]; then
    zoxide init nushell > "${HOME}/.zoxide.nu"
    log_success "Generated zoxide init file"
else
    log_warning "Zoxide init file already exists, skipping..."
fi

# Generate carapace init file
if [ ! -f "${HOME}/.cache/carapace/init.nu" ]; then
    carapace _carapace nushell > "${HOME}/.cache/carapace/init.nu"
    log_success "Generated carapace init file"
else
    log_warning "Carapace init file already exists, skipping..."
fi

# Step 5: Setup main Nushell configuration files
log_info "Setting up main Nushell configuration files..."

# Backup existing files if they exist
if [ -f "${HOME}/Library/Application Support/nushell/env.nu" ]; then
    cp "${HOME}/Library/Application Support/nushell/env.nu" "${HOME}/Library/Application Support/nushell/env.nu.backup"
    log_info "Backed up existing env.nu"
fi

if [ -f "${HOME}/Library/Application Support/nushell/config.nu" ]; then
    cp "${HOME}/Library/Application Support/nushell/config.nu" "${HOME}/Library/Application Support/nushell/config.nu.backup"
    log_info "Backed up existing config.nu"
fi

# Create main env.nu file
cat > "${HOME}/Library/Application Support/nushell/env.nu" << 'EOF'
# env.nu
#
# Installed by setup-nushell.sh
#
# This file is loaded before config.nu and login.nu
# Source dotfiles env.nu
source ~/dotfiles/.config/nushell/env.nu
EOF

# Create main config.nu file
cat > "${HOME}/Library/Application Support/nushell/config.nu" << 'EOF'
# config.nu
#
# Installed by setup-nushell.sh
#
# This file is loaded after env.nu and before login.nu
# Source dotfiles config.nu
source ~/dotfiles/.config/nushell/config.nu
EOF

log_success "Main configuration files created"

# Step 6: Set Nushell as default shell (optional)
CURRENT_SHELL=$(echo $SHELL)
if [ "$CURRENT_SHELL" != "/opt/homebrew/bin/nu" ]; then
    log_info "Current shell: $CURRENT_SHELL"
    echo -e "${YELLOW}Would you like to set Nushell as your default shell? (y/n)${NC}"
    read -r response
    if [[ "$response" =~ ^[Yy]$ ]]; then
        if chsh -s /opt/homebrew/bin/nu; then
            log_success "Nushell set as default shell"
        else
            log_error "Failed to set Nushell as default shell"
        fi
    else
        log_info "Skipping shell change"
    fi
else
    log_success "Nushell is already the default shell"
fi

# Step 7: Verification
log_info "Verifying setup..."

# Test if nu command works
if command -v nu &> /dev/null; then
    log_success "Nushell is available"
else
    log_error "Nushell is not available in PATH"
    exit 1
fi

# Test configuration loading
log_info "Testing configuration loading..."
if nu --login --commands 'echo $env.STARSHIP_CONFIG' &> /dev/null; then
    log_success "Configuration loads successfully"
else
    log_warning "Configuration might have issues"
fi

# Final summary
echo
log_success "Nushell setup completed successfully!"
echo
echo -e "${GREEN}Setup Summary:${NC}"
echo "✅ Nushell, zoxide, carapace, and starship installed"
echo "✅ Configuration files linked to dotfiles"
echo "✅ Initialization files generated"
echo "✅ Main Nushell config files configured"
echo "✅ Setup verified"
echo
echo -e "${BLUE}Next steps:${NC}"
echo "1. Start a new terminal session or run: nu --login"
echo "2. Test the z command: help z"
echo "3. Verify starship config: echo \$env.STARSHIP_CONFIG"
echo
echo -e "${YELLOW}Files created/modified:${NC}"
echo "• ~/.cache/starship/init.nu"
echo "• ~/.zoxide.nu"
echo "• ~/.cache/carapace/init.nu"
echo "• ~/Library/Application Support/nushell/env.nu"
echo "• ~/Library/Application Support/nushell/config.nu"
echo "• ~/.config/nushell -> ~/dotfiles/.config/nushell (symlink)"
echo "• ~/.config/starship -> ~/dotfiles/.config/starship (symlink)"
echo
echo -e "${GREEN}Happy Nushell-ing! 🐚${NC}"
