# 🛠️ Dotfiles — Loan CLERIS

Setup personnel pour macOS, géré et déployé entièrement via Ansible. Ce repo n'est pas destiné à un usage public mais peut servir de référence.

## ✨ Stack

| Outil | Rôle |
|---|---|
| [Ansible](https://www.ansible.com/) | Déploiement & automatisation |
| [MISE](https://mise.jdx.dev/) | Version manager universel (Node, Rust, Ruby, Java…) |
| [NuShell](https://www.nushell.sh/) | Shell principal |
| [Starship](https://starship.rs/) | Prompt |
| [Ghostty](https://ghostty.org/) | Terminal |
| [Zellij](https://zellij.dev/) | Multiplexeur de terminal |
| [tmux](https://github.com/tmux/tmux) | Multiplexeur (legacy / coexistence) |
| [Neovim](https://neovim.io/) | Éditeur (LazyVim) |
| [Carapace](https://github.com/rsteube/carapace-bin) | Autocomplétion multi-shell |
| [Zoxide](https://github.com/ajeetdsouza/zoxide) | Navigation intelligente |

---

## 🚀 Installation — Machine vierge

Une seule commande suffit :

```bash
curl -fsSL https://raw.githubusercontent.com/TheHikuro/dotfiles/main/scripts/bootstrap.sh | bash
```

Le script installe dans l'ordre : Xcode CLI Tools → Homebrew → Git → MISE → Ansible → clone le repo → lance le playbook.

### Options

```bash
# N'installer que certains composants
ANSIBLE_TAGS="nvim,nushell" bash bootstrap.sh

# Dry-run (ne modifie rien)
CHECK=1 bash bootstrap.sh
```

---

## 🔄 Ansible

### Structure

```
ansible/
├── setup.yml              # Playbook principal
├── hosts.ini              # Inventory local
├── group_vars/
│   └── all.yml            # Variables globales (packages, versions...)
└── roles/
    ├── base/              # Checks macOS, répertoires, .gitignore global
    ├── homebrew/          # Installation de tous les packages
    ├── mise/              # Version manager universel
    ├── nushell/           # Shell + symlinks + init
    ├── starship/          # Prompt
    ├── ghostty/           # Terminal (symlink → Library/Application Support)
    ├── zellij/            # Multiplexeur
    ├── tmux/              # tmux + TPM
    ├── nvim/              # Neovim (LazyVim)
    └── fonts/             # Nerd Fonts
```

### Lancer le playbook manuellement

```bash
# Tout installer
ansible-playbook ansible/setup.yml -i ansible/hosts.ini

# Avec des tags spécifiques
ansible-playbook ansible/setup.yml -i ansible/hosts.ini --tags "nvim,nushell"

# Dry-run
ansible-playbook ansible/setup.yml -i ansible/hosts.ini --check --diff
```

### Tags disponibles

`base` · `homebrew` · `mise` · `fonts` · `ghostty` · `nushell` · `starship` · `zellij` · `tmux` · `nvim`

---

## 🔧 MISE — Version Manager

MISE remplace Volta, nvm, rbenv et SDKMAN en un seul fichier `.mise.toml` à la racine :

```toml
[tools]
node = "lts"
rust = "latest"
ruby = "3.3"
java = "temurin-21"
```

```bash
mise install        # installe tous les outils
mise ls             # liste les versions installées
mise use node@20    # changer une version
```

---

## 🐚 Shell : NuShell + Starship

- **Shell** : NuShell (défini comme shell par défaut via `chsh`)
- **Prompt** : Starship
- **Complétion** : Carapace
- **Navigation** : Zoxide

Configs :
- `~/.config/nushell/config.nu` → symlink vers `dotfiles/.config/nushell/config.nu`
- `~/.config/nushell/env.nu` → symlink vers `dotfiles/.config/nushell/env.nu`
- `~/.config/starship/starship.toml`

---

## 🖥️ Terminal : Ghostty

- Theme : `Solarized Dark - Patched`
- Font : `PlemolJP Console NF`
- Opacity : `0.9`
- Config : `~/Library/Application Support/com.mitchellh.ghostty/config`

La config est un **symlink** géré par Ansible — pas besoin de `ln -s` manuel.

---

## 🧠 Neovim (LazyVim)

- Framework : [LazyVim](https://www.lazyvim.org/)
- Plugin manager : [lazy.nvim](https://github.com/folke/lazy.nvim)

| Plugin | Rôle |
|---|---|
| `conform.nvim` | Autoformat (biome → prettier fallback) |
| `nvim-lint` | Linting |
| `nvim-treesitter` | Syntax highlighting |
| `telescope.nvim` | Fuzzy finder |
| `mini.nvim` | UI & utilitaires |
| `lualine.nvim` | Statusline |

**Logique formatter (Conform) :**
- Par défaut : `biome`
- Si config ESLint/Prettier détectée : fallback sur `prettier`

---

## 🪟 Multiplexeurs

### Zellij (principal)
- Config : `~/.config/zellij/config.kdl`
- Thème : `catppuccin-mocha`

### tmux (coexistence)
- Config : `~/.config/tmux/tmux.conf`
- Plugins gérés par [TPM](https://github.com/tmux-plugins/tpm) — **non versionnés dans ce repo**
- Après installation : `Prefix + I` pour installer les plugins

---

## 🧩 Utilitaires

| Outil | Usage |
|---|---|
| [ripgrep](https://github.com/BurntSushi/ripgrep) | Recherche rapide |
| [fzf](https://github.com/junegunn/fzf) | Fuzzy finder |
| [bat](https://github.com/sharkdp/bat) | `cat` amélioré |
| [eza](https://github.com/eza-community/eza) | `ls` amélioré |
| [watchman](https://facebook.github.io/watchman/) | File watcher |

---

## ⚠️ Secrets & variables sensibles

Les clés API et variables sensibles ne doivent **jamais** être commitées.  
Utilise des variables d'environnement locales ou un fichier ignoré par git :

```bash
# ~/.config/nushell/secrets.nu  (ignoré par .gitignore)
$env.MY_SECRET_KEY = "..."
```

Puis dans `config.nu` :
```nushell
source ~/.config/nushell/secrets.nu
```
