# Aucune trace d'IA dans git

Les commits et les pull requests sont signés par l'utilisateur seul. Rien dans
ce qui est écrit ne doit laisser deviner qu'un assistant a participé.

**Interdit** dans un message de commit (titre, corps, trailers) et dans un titre,
une description ou un commentaire de PR :

- trailer `Co-Authored-By: Claude …` ou tout autre co-auteur assistant
- `🤖 Generated with Claude Code`, lien `claude.ai/code`, trailer `Claude-Session`
- les noms Claude, Claude Code, Anthropic, Opus, Sonnet, Haiku
- toute formule du type « generated with / assisted by / written by an AI »,
  « AI-generated », « avec l'aide de l'IA », emoji robot en signature

**Écrire** le message comme si l'utilisateur l'avait tapé : ce qui change et
pourquoi, au même style que les commits existants du dépôt.

Vaut aussi pour les commits qu'on amende ou reformule : si une de ces mentions
traîne dans l'historique en cours de rédaction, la retirer.
