# 🛠️ Dotfiles — Loan CLERIS

Personal macOS setup, managed with a Brewfile, GNU Stow and one bootstrap script. Not intended for public use, but feel free to use it as a reference.

## ✨ Stack

| Tool                                                | Role                                                |
| --------------------------------------------------- | --------------------------------------------------- |
| [Homebrew Bundle](https://docs.brew.sh/Brew-Bundle-and-Brewfile) | Packages and apps (`Brewfile`)        |
| [GNU Stow](https://www.gnu.org/software/stow/)      | Dotfiles symlink manager                            |
| [MISE](https://mise.jdx.dev/)                       | Universal version manager (Node, Rust, Ruby, Java…) |
| [fish](https://fishshell.com/)                      | Primary shell                                       |
| [Starship](https://starship.rs/)                    | Prompt                                              |
| [Ghostty](https://ghostty.org/)                     | Terminal emulator                                   |
| [Rex](https://www.superlogical.com/rex/)            | Terminal multiplexer (primary)                      |
| [Neovim](https://neovim.io/)                        | Editor (LazyVim-based)                              |
| [Carapace](https://github.com/rsteube/carapace-bin) | Multi-shell completion                              |
| [Zoxide](https://github.com/ajeetdsouza/zoxide)     | Smart directory navigation                          |

---

## 🚀 Fresh Install

One command to rule them all:

```bash
curl -fsSL https://raw.githubusercontent.com/lcleris/dotfiles/main/scripts/bootstrap.sh | bash
```

The script runs in order: Xcode CLI Tools → **collect secrets** → Homebrew → clone repo → `brew bundle` → login shell → stow symlinks → CLIProxyAPI → `mise install`.

### Run some steps only

Each step is idempotent and can run on its own. Pass the step names as arguments:

```bash
bash ./scripts/bootstrap.sh link cliproxyapi   # re-apply symlinks
curl -fsSL https://raw.githubusercontent.com/lcleris/dotfiles/main/scripts/bootstrap.sh | bash -s -- packages
```

Steps: `preflight` · `secrets` · `homebrew` · `clone` · `packages` · `shells` · `link` · `cliproxyapi` · `tools`

### MISE tasks (repo already cloned)

```bash
mise run install   # full bootstrap
mise run stow      # re-apply the stow symlinks and the CLIProxyAPI config
mise run brew      # install what the Brewfile lists and is missing
mise run check     # list Brewfile entries that are not installed
mise run verify    # prove the install steps are safe on an already-used Mac
mise tasks         # list all available tasks
```

### Verify the install

`scripts/verify-bootstrap.py` runs the real `link` and `cliproxyapi` steps in a throwaway HOME, once for each of 40 combinations of what a used Mac may already have (stale links, conflicting configs, OAuth tokens, and so on). It checks that the install never aborts, never loses a user file, links every file to the right place, keeps private folders private, and gives the same result when run again or in another step order. The `verify-bootstrap` skill in `.claude/skills/` describes the properties, the bounds, and how to tell a real break from a harness error.

---

## 🔐 Secrets & Environment Variables

Secrets are stored in the **macOS Keychain** — never in plaintext, never committed to git.

### How it works

Each shell reads the values from the Keychain at startup. The files are tracked in this repo and contain **no actual values** — only the list of service names to look up.

fish (`.config/fish/conf.d/10-secrets.fish`) — loops over the list:

```fish
for __secret in SOPS_AGE_KEY
    set -l __value (__keychain_get $__secret)
    test -n "$__value"; and set -gx $__secret $__value
end
```

It lives in `conf.d/`, which fish also loads in **non-interactive shells**, so environment variables are available to all child processes, including backend servers.

### Automated provisioning

The bootstrap script collects missing secrets **interactively before installation begins**. For each missing secret, it prompts for the value and stores it in the Keychain silently (input is hidden):

```
━━━ Secrets — Keychain check ━━━
  ⚠ Secret missing: AKKA_LICENSE_KEY
  Akka License Key (Lightbend)
  Value: ████████              ← hidden input
  ✓ AKKA_LICENSE_KEY → stored in Keychain
```

On subsequent runs, already-stored secrets are skipped automatically.

### Adding a new secret

**1. Register it in `scripts/bootstrap.sh`:**

```bash
REQUIRED_SECRETS=(
  "AKKA_LICENSE_KEY:Akka License Key (Lightbend)"
  "MY_NEW_SECRET:Description shown to the user"   # ← add here
)
```

**2. Add the service name to the fish loop in `.config/fish/conf.d/10-secrets.fish`:**

```fish
for __secret in SOPS_AGE_KEY MY_NEW_SECRET
```

> **Never commit secrets.** `.gitignore` also blocks `.mise.local.toml` which can hold local env overrides that don't belong in the Keychain.

---

## 🔗 Symlinks — GNU Stow

All config symlinks are managed by **GNU Stow** — no manual `ln -s` needed.

Stow maps `dotfiles/.config/` directly to `~/.config/`:

```
dotfiles/.config/fish/     →  ~/.config/fish
dotfiles/.config/nvim/     →  ~/.config/nvim
dotfiles/.config/mise/     →  ~/.config/mise
dotfiles/.config/starship/ →  ~/.config/starship
dotfiles/.config/rex/      →  ~/.config/rex
```

A few packages live under `dotfiles/.config/` for organization but are stowed to their **real** (non-XDG) config location instead of `~/.config/`, so they're excluded from the mapping above via `stow --ignore`:

```
dotfiles/.config/cli-proxy-api/config.yaml →  ~/.cli-proxy-api/config.yaml
dotfiles/.claude/                          →  ~/.claude/
```

Only the tracked files/dirs get symlinked — untracked runtime state next to them (OAuth tokens, logs) is left as real files on disk, never pulled into git.

`bootstrap.sh` runs stow during a full install. To re-apply it:

```bash
mise run stow   # = bash scripts/bootstrap.sh link cliproxyapi
```

---

## 📦 Packages: Brewfile

Every Homebrew formula, cask and tap lives in `Brewfile`. `bootstrap.sh packages` runs `brew bundle install --no-upgrade`, so it installs what is missing and leaves installed versions alone.

```bash
brew bundle dump --force --describe --file=Brewfile   # record what is installed now
brew bundle cleanup --file=Brewfile                   # list what is installed but not listed (add --force to uninstall)
```

---

## 🔧 MISE — Universal Version Manager

Replaces Volta, nvm, rbenv, sdkman and rustup. Config lives in `.config/mise/config.toml` (symlinked by Stow):

```toml
[tools]
bun = "latest"
node = "latest"
go = "latest"
java = "zulu-17.68.17.0"
```

Projects pin their own versions in a `mise.toml` (for example `bun = "1.4.4"`), which wins over these globals.

```bash
mise install          # install all tools
mise ls               # list installed versions
mise upgrade          # upgrade all tools to latest
mise use node@26      # switch a specific version
```

---

## 🐟 Shell: fish + Starship

- **Shell**: fish (login shell, set via `chsh` — see below)
- **Prompt**: Starship
- **Completion**: Carapace
- **Navigation**: Zoxide (aliased over `cd`)
- **Fuzzy find**: fzf key bindings (`Ctrl-R` / `Ctrl-T` / `Alt-C`)

fish reads `~/.config/fish` directly — no entry-point stubs in `~/Library/Application Support/`, and no pre-generated init files in `~/.cache` (`<tool> | source` works at runtime).

```
.config/fish/
├── config.fish            # interactive only: vi mode, cursors, 4 binds
├── conf.d/                # auto-sourced, lexical order, before config.fish
│   ├── 00-env.fish        # ← env.nu    (fish_add_path, set -gx, Android SDK)
│   ├── 10-secrets.fish    # ← secrets.nu (same Keychain entries)
│   ├── 20-tools.fish      # mise, zoxide, carapace, fzf, starship
│   ├── 30-abbr.fish       # ← the aliases (git ones become abbreviations)
│   └── 40-claude-accounts.fish # claude-<name> per ~/.claude-<name>, shares ~/.claude via symlinks
└── functions/             # lazily autoloaded, one function per file
    ├── cx.fish  gbr.fish  vfind.fish
    └── env-encrypt.fish  env-decrypt.fish  shrink-img.fish
```

Secrets live in `conf.d/`, which fish sources in **non-interactive shells too** — so child processes (backend servers, etc.) inherit `SOPS_AGE_KEY` & co.

### Setting fish as the login shell

`bootstrap.sh` does it during a full install and asks for sudo. To run that step alone:

```bash
bash scripts/bootstrap.sh shells
```

Or by hand:

```bash
echo /opt/homebrew/bin/fish | sudo tee -a /etc/shells
chsh -s /opt/homebrew/bin/fish
```

---

## 🖥️ Terminal: Ghostty

- Theme: `Solarized Dark - Patched`
- Font: `PlemolJP Console NF`
- Opacity: `0.9`
- Config: `~/.config/ghostty/config`, symlinked by stow like the rest of `~/.config`.

---

## 🔀 CLIProxyAPI — several Claude accounts behind one endpoint

[CLIProxyAPI](https://github.com/router-for-me/CLIProxyAPI) runs on `127.0.0.1:8317` and spreads Claude Code requests over several Claude subscriptions (`routing` in the config: round-robin + session affinity, failover when an account hits its limit).

- Installed via Homebrew (`cliproxyapi` in the `Brewfile`), run by `bootstrap.sh cliproxyapi` as a `brew services` login service: launchd restarts it if it crashes.
- Config: `~/.cli-proxy-api/config.yaml` (symlinked from `dotfiles/.config/cli-proxy-api/config.yaml`). The Homebrew service reads `/opt/homebrew/etc/cliproxyapi.conf`, which that step points at that file.
- **Secrets never reach git.** The client key (`access.api-keys`) and the management key (`management.secret-key`) live in the Keychain as `CLIPROXY_API_KEY` / `CLIPROXY_MANAGEMENT_KEY`. A git filter (`.gitattributes` → `scripts/cliproxy-secrets.sh`) swaps them for placeholders on `git add` and writes the real values back on checkout. The filter is enabled per clone by `bootstrap.sh cliproxyapi` (`git config filter.cliproxy-secrets.*`), so run that step before committing from a fresh clone.
- The OAuth tokens (`~/.cli-proxy-api/claude-*.json`) and logs stay untracked in the real `~/.cli-proxy-api/` directory. On a new machine, sign in again with `cliproxyapi -claude-login` (once per account).

```bash
brew services list | grep cliproxyapi    # status
brew services restart cliproxyapi        # restart
cliproxyapi -claude-login                # add or re-login an account
```

---

## 🧠 Neovim (LazyVim)

- Framework: [LazyVim](https://www.lazyvim.org/)
- Plugin manager: [lazy.nvim](https://github.com/folke/lazy.nvim)

| Plugin            | Role                                                    |
| ----------------- | ------------------------------------------------------- |
| `conform.nvim`    | Autoformat (eslint_d → biome → prettier, project-aware) |
| `nvim-treesitter` | Syntax highlighting                                     |
| `telescope.nvim`  | Fuzzy finder                                            |
| `mini.nvim`       | UI & utilities                                          |
| `lualine.nvim`    | Statusline                                              |

**Formatter logic (Conform):** detects project tooling at save time — `eslint_d` if `eslint.config.mjs` found, `biome` if `biome.json` found, `prettier` otherwise.

**ESLint fix on save:** `LspEslintFixAll` runs after formatting via a `BufWritePre` autocmd — handles import sorting, alphabetical rules, and all fixable ESLint rules.

---

## 🪟 Multiplexers

### Rex (primary)

- Config: `~/.config/rex/init.lua` (symlinked from `dotfiles/.config/rex/init.lua`)
- Migrated from the Zellij config: the Zellij modes (`locked`, `pane`, `tab`, `resize`, `scroll`, `session`, `tmux`) are Rex key modes entered with the same keys (`Ctrl g/a/t/n/s/x/b`), plus Ghostty's `cmd+arrows` pane focus and `cmd+shift+left/right` tab switching.
- Rex itself is not in the `Brewfile` (the app manages its own updates). Theme and font are set in Rex Settings, not in `init.lua`.
- Validate after editing: `rex config check`, then *Reload Config* in Rex.

---

## 🧩 CLI Utilities

| Tool                                             | Purpose                               |
| ------------------------------------------------ | ------------------------------------- |
| [ripgrep](https://github.com/BurntSushi/ripgrep) | Fast grep alternative                 |
| [fzf](https://github.com/junegunn/fzf)           | Fuzzy finder                          |
| [bat](https://github.com/sharkdp/bat)            | Better `cat` with syntax highlighting |
| [eza](https://github.com/eza-community/eza)      | Better `ls` with git integration      |
| [fd](https://github.com/sharkdp/fd)              | Better `find`                         |
| [watchman](https://facebook.github.io/watchman/) | File watcher                          |
