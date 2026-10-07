#!/usr/bin/env bash
# Upload the RPCS3 title folder (dist/<TITLE_ID>) to the console's /data/homebrew over FTP.
# ShadowMount+ installs a new folder within ~15 s (restart its payload if its scanner hangs).
#   PS5_HOST=<console ip> (required), FTP_PORT (default 2121)
set -euo pipefail
root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
host=${PS5_HOST:?set PS5_HOST to the console's IP address}
port=${FTP_PORT:-2121}
title_id=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["titleId"])' "$root/title/sce_sys/param.json")
app="$root/dist/$title_id"
[[ -f $app/eboot.bin ]] || { echo "deploy.sh: no $app/eboot.bin; build rpcs3_ps5 first" >&2; exit 2; }
count=0 failed=0
cd "$root/dist"
while IFS= read -r -d '' file; do
    rel=${file#./}
    if curl -s --ftp-create-dirs -T "$file" "ftp://$host:$port/data/homebrew/$rel"; then
        count=$((count + 1))
    else
        echo "deploy.sh: failed: $rel" >&2
        failed=$((failed + 1))
    fi
done < <(find "./$title_id" -type f -print0)
echo "==> deployed $title_id to $host: $count files, $failed failed"
[[ $failed == 0 ]]
