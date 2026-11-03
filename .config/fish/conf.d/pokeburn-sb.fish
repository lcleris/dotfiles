# ─── pokeburn-sb.fish — completions `just sb` du sandbox pokeburn ────────────
#
# Le vrai fichier vit dans le checkout pokeburn et reste sourcé depuis conf.d,
# pas déposé dans completions/ : il complète `just`, et un `just.fish` à nous
# masquerait celui que just fournit (cf. l'en-tête du fichier source).
#
# Mais le checkout est sous ~/Desktop, que macOS protège par TCC : chaque app
# qui lance fish (Ghostty, Zed, Claude Code, un LaunchAgent…) doit obtenir sa
# propre autorisation « Dossier Bureau ». Sans elle — ou quand le process ne
# peut pas afficher la demande — le symlink direct faisait échouer fish au
# démarrage sur « source: Operation not permitted », à chaque shell.
#
# `test -r` ne suffit pas : TCC laisse passer le stat() et ne refuse que
# l'open(). On tente donc une vraie lecture d'un octet avant de sourcer. Pas
# d'autorisation = pas de completions, plutôt qu'une erreur à chaque lancement.

set -l pokeburn_completions $HOME/Desktop/projet-perso/pokeburn/completions/pokeburn.fish

if command head -c1 $pokeburn_completions >/dev/null 2>&1
    source $pokeburn_completions
end
