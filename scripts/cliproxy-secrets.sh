#!/bin/sh
# Filtre git de .config/cli-proxy-api/config.yaml (déclaré dans .gitattributes).
# Le repo est public : les secrets ne doivent jamais entrer dans git.
#   clean  (git add)      : remplace les secrets par des placeholders
#   smudge (git checkout) : remet les vraies valeurs depuis le Keychain
# Activé par le rôle ansible `cliproxyapi` (git config filter.cliproxy-secrets.*).
set -eu

case "${1:-}" in
  clean)
    # ponytail: une seule clé API supposée ; plusieurs clés finiraient toutes sur le même placeholder
    sed -E \
      -e 's/^([[:space:]]*secret-key:[[:space:]]*).*/\1"__CLIPROXY_MANAGEMENT_KEY__"/' \
      -e '/^[[:space:]]*api-keys:/,/^[[:space:]]*[a-z-]+:/ s/^([[:space:]]*-[[:space:]]*).*/\1"__CLIPROXY_API_KEY__"/'
    ;;
  smudge)
    # Secret absent du Keychain → le placeholder reste, rien ne casse.
    k() { security find-generic-password -a "${USER:-$(id -un)}" -s "$1" -w 2>/dev/null || printf '__%s__' "$1"; }
    sed -e "s|__CLIPROXY_API_KEY__|$(k CLIPROXY_API_KEY)|" \
        -e "s|__CLIPROXY_MANAGEMENT_KEY__|$(k CLIPROXY_MANAGEMENT_KEY)|"
    ;;
  *)
    echo "usage: $0 clean|smudge" >&2
    exit 2
    ;;
esac
