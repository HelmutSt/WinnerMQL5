#!/bin/bash

DATUM=$(date +"%Y-%m-%d %H:%M")

# Nachricht vorbereiten
DEFAULT_MESSAGE="Änderung am $DATUM"

# Benutzer fragen
read -p "Commit-Nachricht verwenden: '$DEFAULT_MESSAGE'? [J/n] " antwort

if [[ "$antwort" =~ ^[Nn] ]]; then
  read -p "Bitte eigene Commit-Nachricht eingeben: " benutzer_msg
  MESSAGE="$benutzer_msg – am $DATUM"
else
  MESSAGE="$DEFAULT_MESSAGE"
fi

# Git-Befehle ausführen
git add .
git commit -m "$MESSAGE"
git push

# Git-Befehle ausführen
git add .
git commit -m "$MESSAGE"
git push
