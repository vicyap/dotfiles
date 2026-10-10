"""Kagi search settings as code.

`kagi.toml` is the full truth for personalized results, custom lenses, enabled
built-in lenses, and custom assistants. `read` fetches live state, `plan` diffs
it against the config, `apply` enforces the config, and `mine` proposes edits
from local browser history. See AGENTS.md for run commands and the state-dir
rule.
"""
