#
# Pour ajouter un secret manuellement :
#   security add-generic-password -a $env.USER -s "MON_SECRET" -w "la_valeur"
#
# Pour voir les secrets stockés :
#   security find-generic-password -a $env.USER -s "MON_SECRET" -w
# ─────────────────────────────────────────────────────────────────────────────

def keychain-get [service: string] {
  try {
       security find-generic-password -a $env.user -s $service -w 
        | decode utf-8 
        | str trim
  } catch {
    ""
  }
}

# ─── Akka ────────────────────────────────────────────────────────────────────
let akka_key = (keychain-get "AKKA_LICENSE_KEY")
if ($akka_key | is-not-empty) {
  $env.AKKA_LICENSE_KEY = $akka_key
}

# ─── Ajouter d'autres secrets ici ─────────────────────────────────────────
# Exemple :
# let gh_token = (keychain-get "GITHUB_TOKEN")
# if ($gh_token | is-not-empty) {
#   $env.GITHUB_TOKEN = $gh_token
# }
