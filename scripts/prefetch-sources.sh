#!/usr/bin/env bash
# Pré-télécharge les SOURCES du build LFS-Nix depuis le cache NixOS (version 2).
#
# Ce sont des archives de code source (.tar.gz, patchs…), pas du code compilé :
# la compilation reste 100 % locale. Utile quand un serveur amont (404, connexion
# coupée…) ne fournit plus un fichier.
#
# Note : détecte aussi les sources déclarées en « structuredAttrs » (mailcap,
# patchs busybox…), que la v1 ne voyait pas.
#
# Usage :  bash prefetch-sources.sh      (depuis la racine du projet : bash scripts/prefetch-sources.sh)

cd "$(dirname "$(readlink -f "$0")")/.." || exit 1

echo "1/3  Évaluation du flake…"
drv=$(nix path-info --derivation .#vm) || { echo "Échec de l'évaluation du flake."; exit 1; }

echo "2/3  Recherche des sources (2 à 5 minutes)…"
list=$(mktemp)
# Une dérivation « à sortie fixe » (= une source) a un hash fixé dans sa sortie.
nix-store -qR "$drv" | grep '\.drv$' | xargs -P 8 -I{} sh -c '
  if nix derivation show "{}" 2>/dev/null | grep -Eq "\"hash\"[[:space:]]*:"; then
    nix-store -q --outputs "{}"
  fi
' > "$list"
echo "     $(wc -l < "$list") sources trouvées."

echo "3/3  Téléchargement depuis le cache (quelques minutes)…"
xargs -r -a "$list" nix-store -r --keep-going >/dev/null 2>/tmp/lfs-sources.err
echo "Terminé. Les sources absentes du cache seront téléchargées pendant le build"
echo "(détails des manquantes : /tmp/lfs-sources.err)."
rm -f "$list"
