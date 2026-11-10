#!/usr/bin/env bash
# Static checks + a temp-$HOME smoke test for the installer and CLI.
#
# Safe to run anywhere: the convergence smoke test uses a throwaway $HOME and
# never touches your real home directory.
set -uo pipefail

REPO="$(cd -P "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO"
status=0
note() { printf '\n== %s ==\n' "$1"; }

shopt -s nullglob
# All bash scripts in the repo (bin/* are all #!/usr/bin/env bash, as is
# hooks/pre-commit). Keep this list exhaustive so no script escapes shellcheck.
shell_files=(install.sh bin/* hooks/pre-commit lib/*.sh scripts/*.sh nix/darwin/*.sh)
shopt -u nullglob

note "bash -n (syntax)"
for f in "${shell_files[@]}"; do
    if bash -n "$f"; then echo "  ok $f"; else
        echo "  FAIL $f"
        status=1
    fi
done

note "shellcheck"
if command -v shellcheck >/dev/null 2>&1; then
    shellcheck -x "${shell_files[@]}" || status=1
else
    echo "  (shellcheck not installed; skipping)"
fi

note "git diff --check (whitespace / conflict markers)"
git diff --check || status=1

note "Keep Awake input and unavailable-service checks"
bash "$REPO/scripts/test-keep-awake.sh" || status=1

note "temp-\$HOME symlink convergence"
# Not `( ... ) || status=1`: bash ignores errexit inside a subshell that is part
# of an || list, which would let every unchecked failure below pass.
# shellcheck disable=SC2030,SC2031 # each test isolates its own HOME
(
    set -e
    tmp="$(mktemp -d)"
    trap 'rm -rf "$tmp"' EXIT
    export HOME="$tmp/home"
    export DOTFILES_DIR="$REPO"
    export DOTFILES_INTERACTIVE=never
    mkdir -p "$HOME"

    # shellcheck source=/dev/null
    source "$REPO/install.sh"
    # shellcheck source=/dev/null
    source "$REPO/lib/platform.sh"
    # shellcheck source=/dev/null
    source "$REPO/lib/symlink.sh"
    symlink_all_packages "$REPO/packages" >/dev/null

    # Convergence must create repo-backed symlinks under the throwaway HOME and
    # never write outside it.
    total=0
    repo_links=0
    while IFS= read -r link; do
        total=$((total + 1))
        case "$(readlink "$link")" in
            "$REPO"/*) repo_links=$((repo_links + 1)) ;;
        esac
    done < <(find "$HOME" -type l)

    echo "  created $total symlinks, $repo_links pointing into the repo"
    if [ "$repo_links" -lt 1 ]; then
        echo "  FAIL: no repo-backed symlinks created"
        exit 1
    fi

    symlink_all_packages "$REPO/packages" >"$tmp/second-run"
    if grep -vE 'already linked|^\[|^$' "$tmp/second-run"; then
        echo "  FAIL: second convergence was not a no-op"
        exit 1
    fi

    note "temp-\$HOME shared Codex instructions"
    export DOTFILES_FORCE=0
    link_codex_agents_md
    [[ "$(readlink "$HOME/.codex/AGENTS.md")" == "$HOME/.agents/AGENTS.md" ]]
    cmp "$HOME/.codex/AGENTS.md" "$REPO/packages/agents/.agents/AGENTS.md"

    rm "$HOME/.codex/AGENTS.md"
    printf 'existing generated instructions\n' >"$HOME/.codex/AGENTS.md"
    cp "$HOME/.codex/AGENTS.md" "$tmp/expected-backup"
    link_codex_agents_md
    cmp "$BACKUP_DIR/AGENTS.md" "$tmp/expected-backup"
    [[ "$(readlink "$HOME/.codex/AGENTS.md")" == "$HOME/.agents/AGENTS.md" ]]

    link_codex_agents_md
    cmp "$BACKUP_DIR/AGENTS.md" "$tmp/expected-backup"
    cmp "$HOME/.codex/AGENTS.md" "$REPO/packages/agents/.agents/AGENTS.md"
    [[ "$DOTFILES_FORCE" == 0 ]]
    printf 'keep unrelated conflict\n' >"$HOME/unrelated"
    create_symlink "$HOME/.agents/AGENTS.md" "$HOME/unrelated"
    [[ ! -L "$HOME/unrelated" ]]
    echo "  ok fresh link, replacement backup, repeated convergence, scoped force"
)
rc=$?
((rc == 0)) || status=1

note "temp-\$HOME stale link pruning"
# shellcheck disable=SC2030,SC2031 # each test isolates its own HOME
(
    set -e
    tmp="$(mktemp -d)"
    trap 'rm -rf "$tmp"' EXIT
    export HOME="$tmp/home"
    export DOTFILES_DIR="$tmp/repo"
    export DOTFILES_INTERACTIVE=never
    pk="$DOTFILES_DIR/packages"
    mkdir -p "$HOME" "$pk/keep" "$pk/gone" "$pk/tonix"
    touch "$pk/keep/.kept" "$pk/keep/.renamed" "$pk/gone/.gone" "$pk/tonix/.tonix"

    # shellcheck source=/dev/null
    source "$REPO/lib/symlink.sh"
    symlink_all_packages "$pk" >/dev/null

    rm "$pk/keep/.renamed"
    rm -r "$pk/gone"
    # shellcheck disable=SC2034 # read by is_nix_owned_package
    NIX_OWNED_PACKAGES=(tonix)
    # A real file at a recorded path must survive.
    rm "$HOME/.gone"
    echo mine >"$HOME/.gone"
    prune_stale_package_links "$pk" >/dev/null

    [[ -L "$HOME/.kept" ]]
    [[ ! -e "$HOME/.renamed" && ! -L "$HOME/.renamed" ]]
    [[ ! -L "$HOME/.tonix" ]]
    [[ "$(cat "$HOME/.gone")" == mine ]]
    manifests="$(package_manifest_dir)"
    [[ -f "$manifests/symlinks-keep.txt" ]]
    [[ ! -e "$manifests/symlinks-gone.txt" && ! -e "$manifests/symlinks-tonix.txt" ]]
    echo "  ok removed files, removed packages, and Nix-owned packages are pruned; real files kept"
)
rc=$?
((rc == 0)) || status=1

note "piped install.sh reaches main"
# `curl ... | bash` feeds the script on stdin; main must still run. HOME holds a
# non-git ~/.dotfiles so main stops at that check, before it installs anything.
(
    tmp="$(mktemp -d)"
    trap 'rm -rf "$tmp"' EXIT
    mkdir -p "$tmp/.dotfiles"
    out="$(env -u DOTFILES_DIR HOME="$tmp" PATH="$PATH" bash <"$REPO/install.sh" 2>&1)"
    if [[ "$out" == *"exists but is not a git repo"* ]]; then
        echo "  ok main ran"
    else
        echo "  FAIL: main did not run: $out"
        exit 1
    fi
)
rc=$?
((rc == 0)) || status=1

note "temp-\$HOME skill convergence (real skills CLI)"
uv run "$REPO/scripts/test-agent-skills.py" || status=1

echo
if [ "$status" -eq 0 ]; then
    echo "All checks passed."
else
    echo "Some checks FAILED."
fi
exit "$status"
