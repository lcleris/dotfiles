
# Dotfiles MacBook Setup

Ce dépôt contient la configuration personnelle pour mon environnement macOS : fish, tmux, wezterm, nvim, starship...

## ✅ Prérequis

Avant de lancer la configuration automatisée :

- Xcode Command Line Tools :
  ```bash
  xcode-select --install
  ```

- Ansible :
  ```bash
  brew install ansible
  ```

- Homebrew doit être présent (Ansible vérifiera et l'installera si besoin).

## 🛠 Installation étape par étape

```bash
git clone git@github.com:Loan/dotfiles.git ~/dotfiles
cd ~/dotfiles/ansible
ansible-playbook macbook-setup.yml
```

## ⚡️ Post-install manuel recommandé

Certaines actions ne sont pas encore automatisées (peuvent l'être avec des rôles Ansible plus tard) :

- Lancer tmux puis installer les plugins :
  ```bash
  # Dans tmux
  prefix + I
  ```

- Si tu utilises `tmux-update` (fonction fish perso), n'oublie pas de la lancer :
  ```bash
  tmux-update
  ```

- Si tu utilises `oh-my-fish` :
  ```bash
  curl -L https://get.oh-my.fish | fish
  ```

⚠️ Pour l'instant, l'installation d'oh-my-fish et des plugins fish n'est **pas** gérée par Ansible.

## ✨ Améliorations possibles

À terme, le playbook peut évoluer vers une structure plus robuste avec des **rôles Ansible**, par exemple :

- `roles/fish` : gérer installation fish, oh-my-fish, plugins, fonctions…
- `roles/tmux` : gérer tmux, plugins TPM, configuration…
- `roles/fonts` : gérer installation des polices…

Cela permettra un setup encore plus modulaire et maintenable.

## 🎯 Remarque

Ce setup est conçu pour une utilisation **perso**. Certaines options (ex : Volta) sont exclues volontairement.

