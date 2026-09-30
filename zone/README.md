# zone

Manages one Cloudflare zone's configuration: zone settings, proxied DNS records, custom WAF rules, managed WAF
deployment, cache rules, bot management, managed transforms, tiered caching, SSL toggles, advanced certificates and
health checks. Every resource family has a `manage_*` switch; the zone itself is looked up, never created or deleted.

Built from the Allan Gray (allangray.com.au) and Judo Bank (judo.bank) zones in September 2026. Where the two agreed,
the value became a module default; where they differed, it became an input.

## Usage (Terragrunt)

```hcl
terraform {
  source = "github.com/Veeps-Hosting/terraform-cloudflare//zone?ref=1.0"

  extra_arguments "cloudflare_token" {
    commands = concat(get_terraform_commands_that_need_vars(), ["state", "show"])
    env_vars = { CLOUDFLARE_API_TOKEN = get_env("CLOUDFLARE_API_TOKEN_<CLIENT>") }
  }
}

include "root" {
  path = find_in_parent_folders("root.hcl")
}

inputs = {
  zone_name      = "example.com"
  adopt_existing = true # first run on a zone that already exists
  dns_records = {
    www = { name = "www.example.com", type = "CNAME", content = "origin.example.net" }
  }
}
```

Live examples: tf-infra-live `main/datacentre-syd3/allan-gray/cloudflare_waf` and judocapital
`judo-website-cloudflare/main/judo.bank`.

The module declares `backend "s3" {}` and no provider block. The provider reads `CLOUDFLARE_API_TOKEN`, which the
leaf sets through `extra_arguments`, so the token never lands on disk.

## Adopting an existing zone

Set `adopt_existing = true`. The module then adds an import block for every enabled resource and looks up each
object's ID live. The first plan should read `N to import, 0 to add, 0 to change, 0 to destroy`. Anything else means
an input doesn't match the live zone: fix the input, don't apply. Once imported, the blocks do nothing.

Rulesets are authoritative for their phase. To keep an import from rewriting rules, pass the refs Cloudflare
assigned (`rule_refs`, and `ref` on raw rules). Pull them from `GET /zones/<id>/rulesets/<ruleset_id>`.

## Rule order (http_request_firewall_custom)

1. `firewall_rules_head` (raw rule objects, client-specific)
2. Icinga allowlist (`icinga_allowlist`, `icinga_allowlist_ips` + `icinga_allowlist_extra_ips`)
3. `ip_allowlists`, in order
4. Block `/xmlrpc.php` (`block_xmlrpc`)
5. AI crawler block by user agent (`block_ai_bots_by_user_agent`)
6. `firewall_rules_tail`

## Shared vs configurable

| Area | Shared default | Configurable per zone |
|---|---|---|
| Zone settings | 42 settings in `locals.tf` (SSL full, min TLS 1.2, TLS 1.3 zrt, cache level aggressive, security level medium, HSTS off, ...) | `websockets`, `opportunistic_onion`, `pseudo_ipv4`, `max_upload`, `challenge_ttl`, `ciphers`, plus `zone_settings_overrides` |
| Custom WAF | Icinga allowlist, XML-RPC block, AI crawler block | head/tail rules, extra allowlists, extra Icinga IPs |
| Managed WAF | Cloudflare Managed + OWASP (PL1 only) | `waf_cloudflare_managed_overrides`, `waf_owasp_score_threshold`, `waf_owasp_action` |
| Cache rules | Health check bypass, admin bypass | `health_check_path(_operator)`, `cache_bypass_admin_paths`, `cache_everything` |
| Bot management | SBFM managed_challenge, static resources exempt, AI bots blocked, optimize WordPress | `is_robots_txt_managed`, `bot_preference_sync_enabled`, `bot_management_overrides` |
| Transforms | none | `managed_request_headers_enabled`, `managed_response_headers_enabled` |
| Caching / SSL | Tiered cache, smart topology, cache reserve on; Universal SSL on; Total TLS off | one bool each |
| Certificates / health checks | none | `advanced_certificates`, `healthchecks` |

## Not managed

- The zone object, account-level IP lists (referenced by name from rules, e.g. `$wpadmin_whiteslist`), alerting,
  R2, members.
- Page Shield settings: no resource in provider 5.26.
- `development_mode`, read-only settings, and deprecated settings (`minify`, `mirage`, `mobile_redirect`,
  `tls_1_2_only`, `waf`).
- Content scanning by default (`manage_content_scanning = false`): 5.26 can't import it.
- `bot_preference_sync_enabled` and `cf_robots_variant` unless set: 5.26 doesn't read them back on import.

## IPv4-only tokens

The client tokens are IP-allowlisted to jenkci1's IPv4 address, and the provider prefers IPv6. Until the allowlists
include jenkci1's IPv6, run Terragrunt through `scripts/tg-cf` (a throwaway local CONNECT proxy that only dials IPv4):

```bash
~/cf-dev/terraform-cloudflare/scripts/tg-cf plan
```
