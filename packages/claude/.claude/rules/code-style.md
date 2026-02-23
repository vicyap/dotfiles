---
description: General code style principles for all languages
---

# Code Style

* Prefer functional composition over object-oriented inheritance
* Always use descriptive variable names. Avoid single-letter names except for counters or iterators. (eg. use `user` not `u`).
* Do not abbreviate variable names unless the abbreviation is widely recognized (e.g., `id`, `url`, `html`). (eg. `stage` not `stg`).
* When removing code, do not leave behind deprecation comments.
* **Simplicity over Backwards Compatibility**: Default to ignoring backwards compatibility
  - Use modern language features and patterns without legacy workarounds
  - Remove deprecated code paths and old compatibility layers
  - Focus on clean, maintainable code over supporting old versions
* Rule of Three: Don't abstract until you have 3 use cases
