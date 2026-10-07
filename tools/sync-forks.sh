#!/usr/bin/env bash
# Keep lavavex's forks of the dependencies current, and show what is new upstream.
#
# 1. Fast-forwards each fork's default branch from its upstream (gh repo sync), so the
#    forks hold everything upstream has, even if upstream later disappears.
# 2. For each dependency, lists the upstream commits after the revision pinned in
#    tools/fetch-deps.sh. Pins never move here: bump one by hand (fetch-deps.sh and
#    PINS.md), rebuild with tools/bootstrap.sh and test on the console.
# 3. Says how many RPCS3 master commits the ps5 branch lacks (rebase it to pick them up).
#
# Needs gh, signed in with access to lavavex's repos. A fork whose branch has diverged
# from upstream is reported, never force-updated.
set -euo pipefail
root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
owner=lavavex

pinned() { grep -E "^\s+\"$1\s" "$root/tools/fetch-deps.sh" | awk '{print $2}' | tr -d '"'; }

sync() {
    local repo=$1 branch=$2
    if out=$(gh repo sync "$owner/$repo" --branch "$branch" 2>&1); then
        echo "  synced $owner/$repo $branch"
    else
        echo "  NOT synced $owner/$repo $branch: $out"
    fi
}

for name in PS5_Vulkan PS5_Mesa PS5_PayloadSDK PS5_LLVM; do
    echo "== $name"
    branch=$(gh repo view "$owner/$name" --json defaultBranchRef -q .defaultBranchRef.name)
    sync "$name" "$branch"

    pin=$(pinned "$name")
    count=$(gh api "repos/$owner/$name/compare/$pin...$branch" -q .ahead_by)
    if [[ $count == 0 ]]; then
        echo "  pin ${pin:0:12} is current"
    else
        echo "  $count new upstream commit(s) after pin ${pin:0:12}:"
        gh api "repos/$owner/$name/compare/$pin...$branch" \
            -q '.commits[-15:][] | "    " + .sha[0:12] + " " + (.commit.message | split("\n")[0])'
        (( count > 15 )) && echo "    (newest 15 shown)"
    fi
done

echo "== rpcs3"
sync rpcs3 master
behind=$(gh api "repos/$owner/rpcs3/compare/ps5...master" -q .ahead_by)
echo "  branch ps5 lacks $behind commit(s) of RPCS3 master"
