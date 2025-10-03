# /bin/bash

# Ort manuell setzen
ORT="Köln"  # oder "Düsseldorf"

# Aktuelles Datum holen
DATUM=$(date +"%Y-%m-%d %H:%M")

# Nachricht übergeben oder Standard verwenden
if [ -z "$1" ]; then
  MESSAGE="Änderung vom $ORT am $DATUM"
else
  MESSAGE="$1 – $ORT am $DATUM"
fi

# Git-Befehle ausführen
git add .
git commit -m "$MESSAGE"
git push
