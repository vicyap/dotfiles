#!/usr/bin/env bash
set -euo pipefail

dotfiles_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
temi_dir="${1:?Usage: refresh-shared-skills.sh TEMI_CHECKOUT [UPSTREAM_COMMIT]}"
pin="$dotfiles_dir/packages/agents/.agents/shared-skills.commit"
commit="${2:-$(cat "$pin")}"
[[ "$commit" =~ ^[0-9a-f]{40}$ ]] || {
    echo 'Use a full upstream commit SHA.' >&2
    exit 1
}
test -f "$temi_dir/.agents/skills/AGENTS.md"
test "$(readlink "$temi_dir/.claude/skills")" = ../.agents/skills
checkout="$(mktemp -d)"
trap 'rm -rf "$checkout"' EXIT
git clone --quiet https://github.com/vicyap/skills.git "$checkout"
git -C "$checkout" checkout --quiet --detach "$commit"
skill=software-design
test -f "$checkout/skills/$skill/SKILL.md"
for target in "$dotfiles_dir/packages/agents/.agents" "$temi_dir/.agents"; do
    mkdir -p "$target/skills/$skill"
    rsync -a --delete "$checkout/skills/$skill/" "$target/skills/$skill/"
    diff -r "$checkout/skills/$skill" "$target/skills/$skill"
    printf '%s\n' "$commit" >"$target/shared-skills.commit"
done
echo "Refreshed both consumers from vicyap/skills@$commit"
