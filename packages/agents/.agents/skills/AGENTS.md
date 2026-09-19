# Shared skill sources

`software-design` is an installed copy from
`vicyap/skills`, pinned in `../shared-skills.commit`. Edit it upstream.
Refresh dotfiles and Temi together with
`scripts/refresh-shared-skills.sh /path/to/temi FULL_UPSTREAM_COMMIT` from dotfiles.
Omit the commit to reinstall the recorded version. The command compares both
installed copies with that commit. Dotfiles' existing skill mirroring deploys
this copy. Claude's personal copy takes precedence; Codex may list both.

`ask-clarifying-questions` is maintained in `usetemi/skills` and installed
globally by the existing registry entry in `install_agent_skills` for Claude
Code and Codex. Keep it out of this mirrored directory and the shared refresh
script. Clear stale mirror ownership with `sync_dotfiles_agent_skills` before
installing the registry version; later mirroring leaves that version alone.
