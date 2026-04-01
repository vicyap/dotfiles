# Python Language

- **Never** use mutable objects (lists, dicts) as default argument values. Use `None` and create inside the function.
- Use `isinstance(obj, list)` not `type(obj) == list` for type checking.
- Compare to `None` with `is`/`is not`, never `==`/`!=`.
- Never use bare `except:` -- always catch specific exceptions.
- Use `from __future__ import annotations` for forward references in type hints (Python < 3.12).
- Predicate functions should return `bool` and be named with question-style verbs (`is_valid`, `has_access`, `can_edit`).
