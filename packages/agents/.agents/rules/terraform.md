---
paths:
  - "**/*.tf"
  - "**/*.tfvars"
  - "**/*.tftest.hcl"
  - "**/*.tofu"
---

## Terraform guidelines

Source: github.com/antonbabenko/terraform-skill

### Naming conventions

- Use `"this"` for singleton resources (only one of that type in the module). Use descriptive names when creating multiple resources of the same type.
- Variables: prefix with context (`vpc_cidr_block`, not `cidr`).
- Outputs: `{name}_{type}_{attribute}` pattern.

### Resource block ordering

Strict order:
1. `count` or `for_each` FIRST (blank line after)
2. Other arguments
3. `tags` as last real argument
4. `depends_on` after tags
5. `lifecycle` at the very end

### Variable block ordering

1. `description` (ALWAYS required)
2. `type`
3. `default`
4. `sensitive`
5. `nullable`
6. `validation`

### Count vs for_each

- `count = condition ? 1 : 0` for boolean create/don't-create toggles
- `for_each` when items may be reordered or removed (stable resource addresses)
- `for_each` when you need to reference resources by key

### Testing (version-aware)

| Terraform Version | Recommended Approach |
|---|---|
| Pre-1.6 | Terratest (Go-based) |
| 1.6+ | Native `terraform test` |
| 1.7+ | Native tests with mock providers (free, no real infra) |

**Do NOT default to Terratest** -- use native tests unless the project is pre-1.6 or has complex multi-cloud needs.

### Set-type blocks cannot be indexed with `[0]`

Many AWS resource blocks are **sets**, not lists (`rule` in S3 encryption config, `transition` in lifecycle config, IAM policy `statement`); `rule[0].x` fails with "Cannot index a set value". Use a `for` expression: `alltrue([for rule in aws_s3_bucket_server_side_encryption_configuration.this.rule : rule.bucket_key_enabled])`.

### `command = plan` vs `command = apply` in tests

Prefer `command = plan` (fast) for input-validation tests; asserting a computed attribute (bucket names from `bucket_prefix`, generated ARNs, etc.) requires `command = apply`.

### Deletion ordering with locals + try()

Force correct resource deletion order (e.g., VPC secondary CIDRs before VPC):

    locals {
      vpc_id = try(aws_vpc_ipv4_cidr_block_association.this[0].vpc_id, aws_vpc.this[0].id, "")
    }

This creates an implicit dependency so the CIDR association is destroyed before the VPC.

### Write-only arguments (Terraform 1.11+)

Use `password_wo` instead of `password` to avoid secrets in state:

    resource "aws_db_instance" "this" {
      password_wo         = var.db_password
      password_wo_version = 1  # increment to rotate
    }

### Module structure

    modules/
    ├── networking/      # Resource modules (single logical group)
    ├── compute/
    └── data/
    examples/            # Usage examples (also serve as integration test fixtures)
    ├── complete/
    └── minimal/
    environments/        # Environment-specific configs
    ├── prod/
    ├── staging/
    └── dev/
