# Nushell Configuration Fix - Complete Guide

## Problem Summary
Nushell wasn't loading properly configured tools and environment variables:
- ❌ Zoxide (z command) not found
- ❌ $env.STARSHIP_CONFIG not recognized
- ❌ Configuration files weren't being sourced properly
- ❌ Starship prompt not loading
- ❌ Carapace completions not working

## Root Cause
The main Nushell configuration files in `~/Library/Application Support/nushell/` were not sourcing the dotfiles configuration, and some required tools were missing.

## Solution Overview
1. **Fixed Configuration File Sourcing**: Updated main Nushell config files to source dotfiles
2. **Installed Missing Dependencies**: Installed zoxide and carapace
3. **Generated Initialization Files**: Created proper init files for all tools
4. **Set Nushell as Default Shell**: Made Nushell the default shell for proper PATH resolution

## Step-by-Step Fix Process

### Step 1: Fix Main Nushell Configuration Files

**Update `/Users/[username]/Library/Application Support/nushell/env.nu`:**
```nu
# Source dotfiles env.nu
source ~/dotfiles/.config/nushell/env.nu
```

**Update `/Users/[username]/Library/Application Support/nushell/config.nu`:**
```nu
# Source dotfiles config.nu
source ~/dotfiles/.config/nushell/config.nu
```

### Step 2: Install Missing Dependencies

```bash
# Install zoxide (smart directory jumping)
/opt/homebrew/bin/brew install zoxide

# Install carapace (advanced completions)
/opt/homebrew/bin/brew install carapace
```

### Step 3: Generate Initialization Files

```bash
# Create starship init file
mkdir -p ~/.cache/starship
/opt/homebrew/bin/starship init nu > ~/.cache/starship/init.nu

# Create zoxide init file
/opt/homebrew/bin/zoxide init nushell > ~/.zoxide.nu

# Create carapace init file
mkdir -p ~/.cache/carapace
/opt/homebrew/bin/carapace _carapace nushell > ~/.cache/carapace/init.nu
```

### Step 4: Set Nushell as Default Shell

```bash
# Change default shell to Nushell
chsh -s /opt/homebrew/bin/nu
```

## Files Created/Modified

### Files Modified:
1. `~/Library/Application Support/nushell/env.nu` - Added dotfiles sourcing
2. `~/Library/Application Support/nushell/config.nu` - Added dotfiles sourcing

### Files Created:
1. `~/.cache/starship/init.nu` - Starship prompt initialization
2. `~/.zoxide.nu` - Zoxide initialization and z command
3. `~/.cache/carapace/init.nu` - Carapace completion initialization

### Existing Dotfiles (Already Configured):
- `~/dotfiles/.config/nushell/env.nu` - Environment variables and PATH
- `~/dotfiles/.config/nushell/config.nu` - Main configuration with sourcing at the end:
  ```nu
  source ~/.config/nushell/env.nu
  source ~/.zoxide.nu
  source ~/.cache/carapace/init.nu
  use ~/.cache/starship/init.nu
  ```

## Verification Commands

Test that everything is working:

```bash
# Test STARSHIP_CONFIG environment variable
nu --login --commands 'echo $env.STARSHIP_CONFIG'
# Should output: /Users/[username]/.config/starship/starship.toml

# Test z command (zoxide)
nu --login --commands 'help z'
# Should show: Alias for `__zoxide_z`

# Test starship availability
nu --login --commands 'which starship'
# Should show starship path

# Start Nushell with all configurations
nu --login
```

## Expected Results After Fix

✅ **$env.STARSHIP_CONFIG** is set to `/Users/[username]/.config/starship/starship.toml`  
✅ **z command** works (zoxide smart directory jumping)  
✅ **Starship prompt** is active and themed  
✅ **Enhanced tab completion** via Carapace  
✅ **All custom aliases** and configurations load  
✅ **No configuration errors** on startup  

## Key Environment Variables Set

- `$env.STARSHIP_CONFIG` - Path to starship configuration
- `$env.CARAPACE_BRIDGES` - Completion bridges for carapace
- `$env.GEM_HOME` - Ruby gems directory
- `$env.GEM_PATH` - Ruby gems path
- `$env.PATH` - Enhanced with homebrew, local bins, and gem binaries

## Available Commands After Fix

- `z <directory>` - Smart directory jumping with zoxide
- `zi` - Interactive directory selection
- `starship` - Prompt customization
- Enhanced tab completion for most commands
- All custom aliases from dotfiles config

## Directory Structure

```
~/Library/Application Support/nushell/
├── env.nu          # Sources ~/dotfiles/.config/nushell/env.nu
├── config.nu       # Sources ~/dotfiles/.config/nushell/config.nu
└── history.txt

~/.cache/
├── starship/
│   └── init.nu     # Starship initialization
└── carapace/
    └── init.nu     # Carapace completion initialization

~/.zoxide.nu        # Zoxide initialization

~/dotfiles/.config/nushell/
├── env.nu          # Main environment configuration
└── config.nu       # Main nushell configuration
```

## Troubleshooting

### Issue: `brew` command not found
**Solution**: Either use full path `/opt/homebrew/bin/brew` or set Nushell as default shell

### Issue: Configuration not loading
**Solution**: Ensure the main config files are sourcing dotfiles:
```nu
# Check if this line exists in ~/Library/Application Support/nushell/env.nu
source ~/dotfiles/.config/nushell/env.nu

# Check if this line exists in ~/Library/Application Support/nushell/config.nu
source ~/dotfiles/.config/nushell/config.nu
```

### Issue: z command not working
**Solution**: Ensure zoxide is installed and `~/.zoxide.nu` exists:
```bash
/opt/homebrew/bin/zoxide init nushell > ~/.zoxide.nu
```

### Issue: Starship not loading
**Solution**: Ensure starship init file exists:
```bash
mkdir -p ~/.cache/starship
/opt/homebrew/bin/starship init nu > ~/.cache/starship/init.nu
```

## Notes

- This configuration works with Nushell v0.105.1
- All tools are installed via Homebrew
- Configuration is modular and sources from dotfiles
- Setting Nushell as default shell resolves PATH issues
- The configuration supports both interactive and non-interactive use

## Commands for Quick Re-setup

If you need to recreate this setup on a new machine:

```bash
# 1. Install dependencies
/opt/homebrew/bin/brew install zoxide carapace

# 2. Generate init files
mkdir -p ~/.cache/starship ~/.cache/carapace
/opt/homebrew/bin/starship init nu > ~/.cache/starship/init.nu
/opt/homebrew/bin/zoxide init nushell > ~/.zoxide.nu
/opt/homebrew/bin/carapace _carapace nushell > ~/.cache/carapace/init.nu

# 3. Update main config files to source dotfiles
echo "source ~/dotfiles/.config/nushell/env.nu" >> ~/Library/Application\ Support/nushell/env.nu
echo "source ~/dotfiles/.config/nushell/config.nu" >> ~/Library/Application\ Support/nushell/config.nu

# 4. Set as default shell
chsh -s /opt/homebrew/bin/nu
```

---

*Last Updated: $(date)*  
*Configuration tested on macOS with Nushell v0.105.1*
