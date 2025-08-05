#!/bin/bash

OLD_EXE="$1"
NEW_EXE="$2"

echo "Attente fermeture de l'ancien exe..."
sleep 2

rm "$OLD_EXE"
mv "$NEW_EXE" "$OLD_EXE"
chmod +x "$OLD_EXE"
"$OLD_EXE" &

exit 0
