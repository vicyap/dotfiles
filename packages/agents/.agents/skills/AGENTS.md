# Shared skill sources

`software-design` and `ask-clarifying-questions` are installed copies from
`vicyap/skills`, pinned in `../shared-skills.commit`. Edit them upstream.
Refresh dotfiles and Temi together with
`scripts/refresh-shared-skills.sh /path/to/temi FULL_UPSTREAM_COMMIT` from dotfiles.
Omit the commit to reinstall the recorded version. The command compares both
installed copies with that commit. Dotfiles' existing skill mirroring deploys
these copies. Claude's personal copy takes precedence; Codex may list both.
