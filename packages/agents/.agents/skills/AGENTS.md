# Shared skill sources

`software-design` is an installed copy from
`vicyap/skills`, pinned in `../shared-skills.commit`. Edit it upstream.
Refresh dotfiles and Temi together with
`scripts/refresh-shared-skills.sh /path/to/temi FULL_UPSTREAM_COMMIT` from dotfiles.
Omit the commit to reinstall the recorded version. The command compares both
installed copies with that commit. The explicit entry in dotfiles'
`agent-skills.txt` installs this copy for Claude Code and Codex on every pull.

`ask-clarifying-questions` is maintained in `usetemi/skills` and listed in
`agent-skills.txt`. Keep it out of this local source directory and the shared
refresh script. Skill ownership and removal are handled by `sync_agent_skills`.
