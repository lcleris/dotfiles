# ─── base PATH  ─────────────────────────────────────────────────────────────
$env.PATH = (
  $env.PATH
  | split row (char esep)
  | prepend "/opt/homebrew/bin"
  | prepend "/opt/homebrew/sbin"
  | prepend "/usr/local/bin"
  | prepend $"($env.HOME)/.local/bin"
  | prepend $"($env.HOME)/.mise/shims"  
  | uniq
  | str join (char esep)
)

# ─── ENV vars ─────────────────────────────────────────────────────────────────
$env.EDITOR          = "nvim"
$env.STARSHIP_CONFIG = $"($env.HOME)/.config/starship/starship.toml"
$env.GIT_OPTIONAL_LOCKS = "0"

# ─── Android SDK (if installed) ────────────────────────────────────────────────
if ($"($env.HOME)/Library/Android/sdk" | path exists) {
  $env.ANDROID_HOME = $"($env.HOME)/Library/Android/sdk"
  $env.PATH = (
    $env.PATH
    | split row (char esep)
    | append $"($env.ANDROID_HOME)/emulator"
    | append $"($env.ANDROID_HOME)/platform-tools"
    | uniq
    | str join (char esep)
  )
}

# ─── CARAPACE_BRIDGES (completions multi-shell) ───────────────────────────────
$env.CARAPACE_BRIDGES = 'zsh,fish,bash,inshellisense'

# ─── Conversions PATH ────────────────────────────────────────────────────────
$env.ENV_CONVERSIONS = {
  "PATH": {
    from_string: { |s| $s | split row (char esep) | path expand --no-symlink }
    to_string:   { |v| $v | path expand --no-symlink | str join (char esep) }
  }
  "Path": {
    from_string: { |s| $s | split row (char esep) | path expand --no-symlink }
    to_string:   { |v| $v | path expand --no-symlink | str join (char esep) }
  }
}

# ─── NuShell lib dirs ────────────────────────────────────────────────────────
$env.NU_LIB_DIRS = [
  ($nu.default-config-dir | path join 'scripts')
  ($nu.data-dir | path join 'completions')
  $nu.default-config-dir    
]
$env.NU_PLUGIN_DIRS = [
  ($nu.default-config-dir | path join 'plugins')
]

# ─── MISE activation ──────────────────────────────────────────────────────────
let mise_path = ($nu.default-config-dir | path join mise.nu)
^mise activate nu | save $mise_path --force

# ─── Init tools ───────────────────────────────────────────────────────────────
mkdir ~/.cache/starship
starship init nu | save --force ~/.cache/starship/init.nu

mkdir ~/.cache/carapace
carapace _carapace nushell | save --force ~/.cache/carapace/init.nu

zoxide init nushell | save --force ~/.zoxide.nu

# ─── Load carapace's completions ─────────────────────────────────────────
source $"($nu.cache-dir)/carapace.nu"
