# ─── 40-claude-accounts.fish — comptes Claude Code multiples ─────────────────
# Un compte = un dossier ~/.claude-<nom> ; `mkdir ~/.claude-<nom>` en crée un,
# pris en compte au prochain shell. Chaque compte a sa fonction claude-<nom>, qui
# lance claude avec CLAUDE_CONFIG_DIR sur ce dossier.
#
# Avant chaque lancement, tout ce que ~/.claude contient et qui manque dans le
# dossier du compte y est lié (agents, commands, hooks, settings…) : la config
# reste partagée. .claude.json n'est jamais lié, il porte l'identité du compte.

for dir in $HOME/.claude-*
    test -d $dir; or continue
    set -l name (string replace -- "$HOME/.claude-" '' $dir)

    function claude-$name --wraps claude --inherit-variable dir \
        --description "claude — compte $name"
        for src in $HOME/.claude/* $HOME/.claude/.*
            set -l entry (path basename $src)
            string match -q '.claude.json*' $entry; and continue
            test -e $dir/$entry; or test -L $dir/$entry; or ln -s $src $dir/$entry
        end
        # Compte proxy : passe par CLIProxyAPI, clé lue dans sa config (pas dans git).
        if test $dir = $HOME/.claude-proxy
            set -fx ANTHROPIC_BASE_URL http://127.0.0.1:8317
            set -fx ANTHROPIC_AUTH_TOKEN (awk '/api-keys:/{f=1;next} f&&/- /{gsub(/.*- "|".*/,"");print;exit}' $HOME/.cli-proxy-api/config.yaml)
        end
        CLAUDE_CONFIG_DIR=$dir claude $argv
    end
end
