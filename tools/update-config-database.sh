#!/usr/bin/env bash
# Fetch RPCS3's per-game recommended settings (the database the Qt frontend downloads,
# https://api.rpcs3.net/config/?api=v1) into deps/config_database.json, for link-title.sh.
set -euo pipefail
root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
out="$root/deps/config_database.json"
curl -sSf --retry 3 "https://api.rpcs3.net/config/?api=v1" -o "$out.new"
python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); assert d.get("games"); print(len(d["games"]), "games")' "$out.new"
mv "$out.new" "$out"
