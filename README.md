# 🛠️ Dotfiles — Loan CLERIS

It's a personal setup for MasOS, designed to be easily managed and deployed using Ansible. This repository is not meant for public use, but it can serve as a reference for anyone looking to set up a similar environment.

## ✨ Features

- 🔁 Managed with Ansible
- 🐚 NuShell + Starship prompt
- 🎨 Ghostty terminal with custom theme
- 🧠 Neovim (LazyVim-based)
- 🧱 Zellij terminal multiplexer
- 🚀 Developer tools (Rust, Node.js, Java, Ruby…)

---

## 📦 Prerequisites

- Homebrew (macOS)
- Git
- Ansible `>= 2.14`
- Fonts: [Nerd Fonts](https://www.nerdfonts.com/) (ex: `PlemolJP Console NF`)
- Starship prompt
- Node.js (via Volta or nvm)
- `zoxide`, `fzf`, `ripgrep`, etc.

---

## 🖥️ Terminal: Ghostty

- Theme: `Solarized Dark - Patched`
- Font: `PlemolJP Console NF`
- Opacity: `0.9`
- Config path: `~/Library/Application Support/com.mitchellh.ghostty/config`

```bash
ln -s ~/dotfiles/ghostty/config "~/Library/Application Support/com.mitchellh.ghostty/config"
```

---

## 🐚 Shell: Nushell + Starship

- Shell: [NuShell](https://www.nushell.sh/)
- Prompt: [Starship](https://starship.rs/)
- Autocompletion: [Carapace](https://github.com/rsteube/carapace-bin)
- Directory jumping: [Zoxide](https://github.com/ajeetdsouza/zoxide)

Config files:

- `~/.config/nushell/config.nu`
- `~/.config/nushell/env.nu`
- `~/.config/starship/starship.toml`

---

## 🧠 Neovim

- Framework: [LazyVim](https://www.lazyvim.org/)
- Plugin Manager: [lazy.nvim](https://github.com/folke/lazy.nvim)

### 📁 Plugins Used (selection)

| Plugin            | Purpose                          |
| ----------------- | -------------------------------- |
| `conform.nvim`    | Autoformat (biome, eslint, etc.) |
| `nvim-lint`       | Linting with fallback            |
| `mini.nvim`       | Core UI & utilities              |
| `nvim-treesitter` | Syntax highlighting              |
| `telescope.nvim`  | Fuzzy finder                     |
| `lualine.nvim`    | Statusline                       |

### 🧰 Formatter logic (Conform)

- Default: `biome`
- If ESLint or Prettier config detected, fallback to `eslint_d` + `prettier`

---

## 🪟 Multiplexer: Zellij

- Config: `~/.config/zellij/config.kdl`
- Theme: `catppuccin-mocha.kdl`
- Plugins: custom (see plugin section in KDL)

```bash
ln -s ~/dotfiles/.config/zellij ~/.config/zellij
```

---

## 🔄 Ansible Setup

```bash
ansible-playbook -i inventory.yml setup.yml --tags "nvim, nushell, zellij, fonts"
```

You can use tags to install parts of the config.

### Example tags:

- `nvim`
- `nushell`
- `zellij`
- `fonts`
- `ghostty` _(not symlinked automatically due to file-type constraints)_

---

## 🧩 Utilities Used

- [Zoxide](https://github.com/ajeetdsouza/zoxide)
- [Carapace](https://github.com/rsteube/carapace-bin)
- [Starship](https://starship.rs)
- [Watchman](https://facebook.github.io/watchman/)
- [fzf](https://github.com/junegunn/fzf)
- [ripgrep](https://github.com/BurntSushi/ripgrep)
- [Volta](https://volta.sh/) or `nvm`

---

## 🧪 Testing

Test playbooks locally with:

```bash
ansible-playbook setup.yml --check --diff
```
