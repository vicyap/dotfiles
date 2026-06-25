#!/usr/bin/env bash
# Static checks + a temp-$HOME smoke test for the installer and CLI.
#
# Safe to run anywhere: the convergence smoke test uses a throwaway $HOME and
# never touches your real home directory. Mirrors the verification path used by
# the nixtest/darwintest VMs for the parts that don't need a full machine.
set -uo pipefail

REPO="$(cd -P "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO"
status=0
note() { printf '\n== %s ==\n' "$1"; }

shopt -s nullglob
# All bash scripts in the repo (bin/* are all #!/usr/bin/env bash, as is
# hooks/pre-commit). Keep this list exhaustive so no script escapes shellcheck.
shell_files=(install.sh bin/* hooks/pre-commit lib/*.sh scripts/*.sh)
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

note "temp-\$HOME symlink convergence"
(
    set -e
    tmp="$(mktemp -d)"
    trap 'rm -rf "$tmp"' EXIT
    export HOME="$tmp/home"
    export DOTFILES_DIR="$REPO"
    export DOTFILES_INTERACTIVE=never
    mkdir -p "$HOME"

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
) || status=1

echo
if [ "$status" -eq 0 ]; then
    echo "All checks passed."
else
    echo "Some checks FAILED."
fi
exit "$status"
