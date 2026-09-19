# Shared skill sources

`software-design` and `ask-clarifying-questions` are maintained in
`usetemi/skills` and installed globally by the existing registry entry in
`install_agent_skills` for Claude Code and Codex. Keep them out of this
mirrored directory. `sync_dotfiles_agent_skills` clears stale mirror ownership
before the registry installation; later mirroring leaves registry versions
alone.
