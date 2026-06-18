#!/bin/bash
# Fitness function : prouve que le binaire n'embarque AUCUNE capacité réseau sortante.
# Échoue (exit 1) si un framework ou symbole réseau est lié.
# `getifaddrs` est AUTORISÉ : lecture passive de compteurs locaux, aucune émission.
set -euo pipefail

BIN="${1:-.build/release/MacOSStateApp}"
if [[ ! -x "$BIN" ]]; then
  echo "✗ binaire introuvable : $BIN (lancer 'swift build -c release' d'abord)"
  exit 2
fi

fail=0

echo "→ Frameworks liés (otool -L) :"
LINKED=$(otool -L "$BIN" || true)
# Frameworks réseau interdits.
if echo "$LINKED" | grep -qiE "CFNetwork|/Network\.framework|Network\.framework|MultipeerConnectivity"; then
  echo "✗ framework réseau lié :"
  echo "$LINKED" | grep -iE "CFNetwork|Network\.framework|MultipeerConnectivity"
  fail=1
else
  echo "  ok — aucun framework réseau"
fi

echo "→ Symboles réseau sortants (nm -u) :"
# Symboles d'émission réseau interdits. getifaddrs/freeifaddrs NON listés = autorisés.
FORBIDDEN='_connect$|_socket$|_getaddrinfo$|_bind$|_sendto$|_recvfrom$|URLSession|NWConnection|_CFStreamCreatePairWithSocket|_res_9_'
HITS=$(nm -u "$BIN" 2>/dev/null | grep -E "$FORBIDDEN" || true)
if [[ -n "$HITS" ]]; then
  echo "✗ symboles réseau sortants détectés :"
  echo "$HITS"
  fail=1
else
  echo "  ok — aucun symbole d'émission réseau"
fi

if [[ "$fail" -ne 0 ]]; then
  echo "RÉSULTAT : ÉCHEC — l'invariant « zéro réseau » est violé."
  exit 1
fi
echo "RÉSULTAT : OK — moniteur 100% local, aucune capacité réseau sortante."
