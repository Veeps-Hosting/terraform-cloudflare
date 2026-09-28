# terraform-cloudflare

Reusable Terraform modules for Cloudflare, driven by Terragrunt from jenkci1.

| Module | Purpose |
|---|---|
| [`zone`](zone/) | One zone's settings, DNS, WAF, cache rules, bot management, SSL and health checks. |

| Script | Purpose |
|---|---|
| [`scripts/tg-cf`](scripts/tg-cf) | Runs `terragrunt` with HTTPS egress forced onto IPv4, for IP-allowlisted tokens. |

Requires OpenTofu >= 1.12.0 and provider `cloudflare/cloudflare ~> 5.26`. Pin a tag in leaves: `//zone?ref=1.0`.
