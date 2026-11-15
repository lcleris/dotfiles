# 🛠️ Dotfiles — Loan CLERIS

Personal macOS setup, managed with a Brewfile, GNU Stow and one bootstrap script. Not intended for public use, but feel free to use it as a reference.

## ✨ Stack

| Tool                                                | Role                                                |
| --------------------------------------------------- | --------------------------------------------------- |
| [Homebrew Bundle](https://docs.brew.sh/Brew-Bundle-and-Brewfile) | Packages and apps (`Brewfile`)        |
| [GNU Stow](https://www.gnu.org/software/stow/)      | Dotfiles symlink manager                            |
| [MISE](https://mise.jdx.dev/)                       | Universal version manager (Node, Rust, Ruby, Java…) |
| [fish](https://fishshell.com/)                      | Primary shell                                       |
| [NuShell](https://www.nushell.sh/)                  | Fallback shell (kept configured, not the default)   |
| [Starship](https://starship.rs/)                    | Prompt                                              |
| [Ghostty](https://ghostty.org/)                     | Terminal emulator                                   |
| [Rex](https://www.superlogical.com/rex/)            | Terminal multiplexer (primary)                      |
| [Oh My Pi (omp)](https://github.com/can1357/oh-my-pi)  | AI coding agent CLI                                 |
| [Herdr](https://herdr.dev/)                          | Agent multiplexer / persistent runtime for coding agents |
| [Neovim](https://neovim.io/)                        | Editor (LazyVim-based)                              |
| [Carapace](https://github.com/rsteube/carapace-bin) | Multi-shell completion                              |
| [Zoxide](https://github.com/ajeetdsouza/zoxide)     | Smart directory navigation                          |

---

## 🚀 Fresh Install

One command to rule them all:

```bash
curl -fsSL https://raw.githubusercontent.com/TheHikuro/dotfiles/main/scripts/bootstrap.sh | bash
```

The script runs in order: Xcode CLI Tools → **collect secrets** → Homebrew → clone repo → `brew bundle` → login shell → stow symlinks → CLIProxyAPI → NuShell entry points → `mise install`.

### Run some steps only

Each step is idempotent and can run on its own. Pass the step names as arguments:

```bash
bash ./scripts/bootstrap.sh link cliproxyapi   # re-apply symlinks
curl -fsSL https://raw.githubusercontent.com/TheHikuro/dotfiles/main/scripts/bootstrap.sh | bash -s -- packages
```

Steps: `preflight` · `secrets` · `homebrew` · `clone` · `packages` · `shells` · `link` · `cliproxyapi` · `nushell` · `tools`

### MISE tasks (repo already cloned)

```bash
mise run install   # full bootstrap
mise run stow      # re-apply the stow symlinks and the CLIProxyAPI config
mise run brew      # install what the Brewfile lists and is missing
mise run check     # list Brewfile entries that are not installed
mise tasks         # list all available tasks
```

---

## 🔐 Secrets & Environment Variables

Secrets are stored in the **macOS Keychain** — never in plaintext, never committed to git.

### How it works

Each shell reads the values from the Keychain at startup. The files are tracked in this repo and contain **no actual values** — only the list of service names to look up.

fish (`.config/fish/conf.d/10-secrets.fish`) — loops over the list:

```fish
for __secret in JIRA_API_TOKEN ANTHROPIC_API_KEY SOPS_AGE_KEY
    set -l __value (__keychain_get $__secret)
    test -n "$__value"; and set -gx $__secret $__value
end
```

NuShell (`.config/nushell/secrets.nu`) — one block per secret:

```nushell
let akka_key = (keychain-get "AKKA_LICENSE_KEY")
if ($akka_key | is-not-empty) {
  $env.AKKA_LICENSE_KEY = $akka_key
}
```

Both are loaded in a context that also applies to **non-interactive shells** (`conf.d/` for fish, `env.nu` rather than `config.nu` for NuShell), so environment variables are available to all child processes, including backend servers.

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
for __secret in JIRA_API_TOKEN ANTHROPIC_API_KEY SOPS_AGE_KEY MY_NEW_SECRET
```

**2b. (optional) Mirror it in `.config/nushell/secrets.nu`** so the fallback shell sees it too:

```nushell
let my_secret = (keychain-get "MY_NEW_SECRET")
if ($my_secret | is-not-empty) {
  $env.MY_NEW_SECRET = $my_secret
}
```

### Manual Keychain management

```bash
# Store a secret
security add-generic-password -a "$USER" -s "MY_SECRET" -w "the_value"

# Read a secret
security find-generic-password -a "$USER" -s "MY_SECRET" -w

# Delete a secret
security delete-generic-password -a "$USER" -s "MY_SECRET"
```

> **Never commit secrets.** `.gitignore` also blocks `.mise.local.toml` which can hold local env overrides that don't belong in the Keychain.

---

## 🔗 Symlinks — GNU Stow

All config symlinks are managed by **GNU Stow** — no manual `ln -s` needed.

Stow maps `dotfiles/.config/` directly to `~/.config/`:

```
dotfiles/.config/nushell/  →  ~/.config/nushell
dotfiles/.config/fish/     →  ~/.config/fish
dotfiles/.config/nvim/     →  ~/.config/nvim
dotfiles/.config/mise/     →  ~/.config/mise
dotfiles/.config/starship/ →  ~/.config/starship
dotfiles/.config/rex/      →  ~/.config/rex
dotfiles/.config/herdr/    →  ~/.config/herdr (config.toml uniquement, voir ci-dessous)
```

A few packages live under `dotfiles/.config/` for organization but are stowed to their **real** (non-XDG) config location instead of `~/.config/`, so they're excluded from the mapping above via `stow --ignore`:

```
dotfiles/.config/omp/agent/config.yml     →  ~/.omp/agent/config.yml
dotfiles/.config/cli-proxy-api/config.yaml →  ~/.cli-proxy-api/config.yaml
dotfiles/.claude/                          →  ~/.claude/
```

Only the tracked files/dirs get symlinked — untracked runtime state next to them (`~/.omp/agent/agent.db`, `~/.omp/agent/sessions/`, etc.) is left as real files on disk, never pulled into git. Same idea for **herdr**: `~/.config/herdr` is kept as a real directory (created by `bootstrap.sh link` before stowing) so only `config.toml` becomes a symlink and herdr's logs (`herdr.log`, `herdr-client.log`, `herdr-server.log`) stay out of the repo.

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
pnpm = "latest"
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

Unlike NuShell, fish reads `~/.config/fish` directly — no entry-point stubs in `~/Library/Application Support/`, and no pre-generated init files in `~/.cache` (`<tool> | source` works at runtime).

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

Secrets live in `conf.d/`, which fish sources in **non-interactive shells too** — so child processes (backend servers, etc.) inherit `JIRA_API_TOKEN` & co. Same guarantee the NuShell setup got by putting them in `env.nu` rather than `config.nu`.

Differences worth knowing, coming from NuShell:

- `l` / `ll` now call **eza**. In NuShell they used the `ls` builtin; fish's `ls` is BSD `/bin/ls`, which rejects `--all`.
- Git shortcuts are **abbreviations**, not aliases — they expand in the command line, so history stores the real command and you can append flags.
- `cx` resolves `cd` to zoxide at call time (fish resolves functions late). Use `builtin cd` inside it for the strict NuShell behaviour.
- fzf key bindings (`Ctrl-R` / `Ctrl-T` / `Alt-C`) come for free; there's no NuShell equivalent.
- You lose structured pipelines (`ls | where size > 10mb`, `open x.json | get y`). fish is string-only — `shrink-img` and `gbr` were rewritten around `string`, `stat` and `math` because of it.

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

## 🐚 Fallback shell: NuShell

NuShell is **still installed and fully configured** — it is simply no longer the login shell. Nothing was deleted: `.config/nushell/` is untouched and `bootstrap.sh nushell` still writes its entry points.

Config files (all symlinked via Stow):

- `~/.config/nushell/config.nu`
- `~/.config/nushell/env.nu`
- `~/.config/nushell/secrets.nu`
- `~/.config/starship/starship.toml`

NuShell on macOS loads its entry points from `~/Library/Application Support/nushell/` — `bootstrap.sh nushell` writes them, and they source the real configs from dotfiles.

Run `nu` for a one-off session. To make it the login shell again:

```bash
chsh -s /opt/homebrew/bin/nu
```

`bootstrap.sh shells` sets fish again on its next run, so change `fish_bin` in that step too.

---

## 🖥️ Terminal: Ghostty

- Theme: `Solarized Dark - Patched`
- Font: `PlemolJP Console NF`
- Opacity: `0.9`
- Config: `~/.config/ghostty/config`, symlinked by stow like the rest of `~/.config`.

---

## 🤖 Oh My Pi (omp) + Herdr

- **omp** — AI coding agent CLI. Config: `~/.omp/agent/config.yml` (symlinked from `dotfiles/.config/omp/agent/config.yml`; `agent.db`, `sessions/`, `.env`, and other runtime state stay real, untracked files next to it).
  - Default model role: `anthropic/claude-sonnet-5:high` (`modelRoles.default` in `config.yml`).
  - `ANTHROPIC_API_KEY` is sourced from the Keychain by `secrets.nu` at shell startup (see [Secrets & Environment Variables](#-secrets--environment-variables)) — no manual `/login` or plaintext key on disk.
- **[Herdr](https://herdr.dev/)** — agent multiplexer: a background server that keeps coding-agent terminals (Claude Code, Codex, opencode…) alive across laptop sleep, network drops and restarts, with per-pane status (working / blocked / idle) and cross-agent coordination via CLI + socket API.
  - Installed via Homebrew (`herdr` in the `Brewfile`).
  - Config: `~/.config/herdr/config.toml` (symlinked from `dotfiles/.config/herdr/config.toml`, theme `catppuccin`). Everything else stays commented at defaults — `herdr --default-config` regenerates a fresh reference.
  - `~/.config/herdr/` stays a **real** directory so herdr's logs live next to the symlinked config without landing in git.
  - Run it as a background service with `brew services start herdr`, or one-shot with `herdr server`. `herdr --skill` prints agent instructions for driving herdr from inside a pane.

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
