---
description: Secrets hygiene for ignore files and pre-commit secret scanning
paths:
  - "**/.gitignore"
  - "**/.dockerignore"
  - "**/.gcloudignore"
  - "**/.helmignore"
---

# Secrets hygiene

When editing an ignore file, ensure the secrets block below is present (merge into existing entries, don't replace). The same block belongs in both `.gitignore` and `.dockerignore` — Docker build contexts ship with published images and leak the same way commits do.

## Secrets block

```gitignore
# --- Secrets / credentials (never commit) ---
.env
.env.*
!.env.example
!.env.sample
!.env.template
.secrets
*.secrets
secrets.*
!secrets.example.*

# Keys & certs
*.pem
*.key
*.p12
*.pfx
*.jks
*.keystore
id_rsa
id_ed25519
id_ecdsa
*_rsa
*_ed25519

# Cloud / service credentials
credentials.json
client_secret*.json
service-account*.json
*serviceAccountKey*.json
.aws/credentials
gcloud-key.json

# Tool-level credential files
.netrc
.npmrc
.pypirc
.htpasswd
```

## Pre-commit hook (gitleaks)

If the repo has no secret scanner, propose adding gitleaks. Free, MIT, runs in milliseconds, catches secrets pasted into *tracked* files (`.gitignore` only blocks dedicated credential files).

```yaml
# .pre-commit-config.yaml
repos:
  - repo: https://github.com/gitleaks/gitleaks
    rev: ""
    hooks:
      - id: gitleaks
```

Install: `pip install pre-commit && pre-commit autoupdate && pre-commit install`. The `autoupdate` step fills `rev` with the latest stable tag.
