# ---------------------------------------------------------------------------------------------------------------------
# ZONE
# ---------------------------------------------------------------------------------------------------------------------

variable "zone_name" {
  description = "Zone apex, e.g. judo.bank. The zone must already exist; this module looks it up, it never creates or deletes it."
  type        = string
}

# ---------------------------------------------------------------------------------------------------------------------
# FEATURE SWITCHES
# Each switch adds or removes a whole resource family. Turning one off on an adopted zone DESTROYS the resources in
# state (which, for most singletons, resets that setting to the Cloudflare default). Use `terragrunt state rm` first
# if you want Terraform to let go without touching the zone.
# ---------------------------------------------------------------------------------------------------------------------

variable "manage_zone_settings" {
  description = "Manage zone settings (SSL/TLS, caching level, security level, HTTP versions, ...)."
  type        = bool
  default     = true
}

variable "manage_dns_records" {
  description = "Manage the DNS records in var.dns_records."
  type        = bool
  default     = true
}

variable "manage_custom_firewall_rules" {
  description = "Manage the zone's custom WAF rules (http_request_firewall_custom phase)."
  type        = bool
  default     = true
}

variable "manage_managed_waf" {
  description = "Manage deployment of the Cloudflare Managed and OWASP rulesets (http_request_firewall_managed phase)."
  type        = bool
  default     = true
}

variable "manage_cache_rules" {
  description = "Manage cache rules (http_request_cache_settings phase)."
  type        = bool
  default     = true
}

variable "manage_bot_management" {
  description = "Manage Super Bot Fight Mode / AI bot settings."
  type        = bool
  default     = true
}

variable "manage_managed_transforms" {
  description = "Manage Cloudflare managed request/response header transforms."
  type        = bool
  default     = true
}

variable "manage_tiered_caching" {
  description = "Manage Argo tiered caching, smart tiered cache topology and cache reserve."
  type        = bool
  default     = true
}

variable "manage_url_normalization" {
  description = "Manage URL normalization settings."
  type        = bool
  default     = true
}

variable "manage_ssl" {
  description = "Manage Universal SSL and Total TLS enablement."
  type        = bool
  default     = true
}

variable "manage_leaked_credential_check" {
  description = "Manage the leaked credential check toggle."
  type        = bool
  default     = true
}

variable "manage_content_scanning" {
  description = "Manage the content (upload) scanning toggle. Off by default: provider 5.26 can't import it, so adopting a zone would re-create it."
  type        = bool
  default     = false
}

variable "manage_authenticated_origin_pulls" {
  description = "Manage the zone-level Authenticated Origin Pulls toggle."
  type        = bool
  default     = true
}

# ---------------------------------------------------------------------------------------------------------------------
# ZONE SETTINGS
# The shared baseline lives in locals.tf. These inputs cover settings where the adopted zones diverge; defaults are
# Cloudflare's own defaults.
# ---------------------------------------------------------------------------------------------------------------------

variable "websockets" {
  description = "Allow WebSocket connections through the proxy."
  type        = bool
  default     = true
}

variable "opportunistic_onion" {
  description = "Advertise an onion service to Tor clients."
  type        = bool
  default     = true
}

variable "pseudo_ipv4" {
  description = "Pseudo IPv4 for IPv6 visitors: off, add_header or overwrite_header."
  type        = string
  default     = "off"

  validation {
    condition     = contains(["off", "add_header", "overwrite_header"], var.pseudo_ipv4)
    error_message = "pseudo_ipv4 must be off, add_header or overwrite_header."
  }
}

variable "max_upload" {
  description = "Maximum request body size in MB (Business plan allows up to 200)."
  type        = number
  default     = 100
}

variable "challenge_ttl" {
  description = "Seconds a visitor who passes a challenge stays trusted."
  type        = number
  default     = 1800
}

variable "ciphers" {
  description = "Allowed edge TLS cipher suites. Empty list means Cloudflare's default set."
  type        = list(string)
  default     = []
}

variable "zone_settings_overrides" {
  description = "Escape hatch: map of setting_id => value merged over the baseline and the inputs above."
  type        = any
  default     = {}
}

# ---------------------------------------------------------------------------------------------------------------------
# DNS
# Partial (CNAME) zones only hold the proxied records; authoritative DNS lives elsewhere.
# ---------------------------------------------------------------------------------------------------------------------

variable "dns_records" {
  description = "Records keyed by a stable label. Use the full FQDN for name."
  type = map(object({
    name    = string
    type    = string
    content = string
    proxied = optional(bool, true)
    ttl     = optional(number, 1)
    comment = optional(string)
  }))
  default = {}
}

# ---------------------------------------------------------------------------------------------------------------------
# CUSTOM FIREWALL RULES
# Rule order: firewall_rules_head, Icinga allowlist, ip_allowlists, Block XML-RPC, AI bot block, firewall_rules_tail.
# Head/tail take raw cloudflare_ruleset rule objects (action, expression, description, action_parameters, logging,
# ref ...) for anything client-specific.
# ---------------------------------------------------------------------------------------------------------------------

variable "firewall_rules_head" {
  description = "Raw custom rules evaluated before the generated allowlists."
  type        = any
  default     = []
}

variable "firewall_rules_tail" {
  description = "Raw custom rules evaluated after every generated rule."
  type        = any
  default     = []
}

variable "icinga_allowlist" {
  description = "Let the Veeps Icinga monitoring hosts skip WAF, rate limiting and bot fight mode."
  type        = bool
  default     = true
}

variable "icinga_allowlist_ips" {
  description = "Icinga monitoring source addresses (bare IPs or CIDRs)."
  type        = list(string)
  default     = ["45.63.24.180", "2001:19f0:5801:11db:5400:5ff:fe4a:2c13"]
}

variable "icinga_allowlist_extra_ips" {
  description = "Addresses appended to icinga_allowlist_ips for this zone."
  type        = list(string)
  default     = []
}

variable "ip_allowlists" {
  description = "Further skip-everything allowlists, evaluated in order after the Icinga allowlist."
  type = list(object({
    description = string
    ips         = list(string)
    ref         = optional(string)
  }))
  default = []
}

variable "block_xmlrpc" {
  description = "Block /xmlrpc.php."
  type        = bool
  default     = true
}

variable "block_ai_bots_by_user_agent" {
  description = "Return 402 to AI crawlers matched by user agent (the rule Cloudflare's AI Crawl Control writes)."
  type        = bool
  default     = true
}

variable "ai_bot_user_agents" {
  description = "User agent substrings blocked by the AI bot rule."
  type        = list(string)
  default = [
    "archive.org_bot", "ChatGPT-User", "DuckAssistBot", "meta-externalfetcher", "MistralAI-User",
    "OAI-SearchBot", "Perplexity-User", "PerplexityBot", "ProRataInc",
  ]
}

variable "rule_refs" {
  description = <<-EOT
    Override the ref of a generated rule, keyed by: icinga_allowlist, block_xmlrpc, block_ai_bots,
    waf_cloudflare_managed, waf_owasp, cache_bypass_health_check, cache_bypass_admin, cache_everything.
    Adopted zones set these to the refs Cloudflare assigned, so import doesn't rewrite the rules.
  EOT
  type        = map(string)
  default     = {}
}

# ---------------------------------------------------------------------------------------------------------------------
# MANAGED WAF
# ---------------------------------------------------------------------------------------------------------------------

variable "waf_cloudflare_managed" {
  description = "Deploy the Cloudflare Managed Ruleset."
  type        = bool
  default     = true
}

variable "waf_cloudflare_managed_overrides" {
  description = "overrides block for the Cloudflare Managed Ruleset execute rule (action, enabled, rules, categories). null = none."
  type        = any
  default     = null
}

variable "waf_owasp" {
  description = "Deploy the Cloudflare OWASP Core Ruleset."
  type        = bool
  default     = true
}

variable "waf_owasp_disabled_categories" {
  description = "OWASP categories switched off. The default keeps paranoia level 1 only."
  type        = list(string)
  default     = ["paranoia-level-2", "paranoia-level-3", "paranoia-level-4"]
}

variable "waf_owasp_score_threshold" {
  description = "OWASP anomaly score threshold: 60 low, 40 medium, 25 high sensitivity."
  type        = number
  default     = 40
}

variable "waf_owasp_action" {
  description = "Action when the OWASP anomaly score is exceeded. null keeps the ruleset default (block)."
  type        = string
  default     = null
}

# ---------------------------------------------------------------------------------------------------------------------
# CACHE RULES
# ---------------------------------------------------------------------------------------------------------------------

variable "cache_bypass_health_check" {
  description = "Never cache the origin health check endpoint."
  type        = bool
  default     = true
}

variable "health_check_path" {
  description = "Origin health check path."
  type        = string
  default     = "/health_check.php"
}

variable "health_check_path_operator" {
  description = "How the health check cache bypass matches the path: eq or contains."
  type        = string
  default     = "eq"

  validation {
    condition     = contains(["eq", "contains"], var.health_check_path_operator)
    error_message = "health_check_path_operator must be eq or contains."
  }
}

variable "cache_bypass_admin_paths" {
  description = "Path substrings that bypass cache (CMS admin and login). Empty list drops the rule."
  type        = list(string)
  default     = ["/wp-admin", "/wp-login"]
}

variable "cache_everything" {
  description = "Cache every response that isn't bypassed above, HTML included."
  type        = bool
  default     = false
}

# ---------------------------------------------------------------------------------------------------------------------
# BOT MANAGEMENT
# ---------------------------------------------------------------------------------------------------------------------

variable "bot_preference_sync_enabled" {
  description = "Sync AI bot preferences with Cloudflare's recommended list. null leaves it unmanaged (import can't read it)."
  type        = bool
  default     = null
}

variable "is_robots_txt_managed" {
  description = "Let Cloudflare prepend AI crawler directives to robots.txt."
  type        = bool
  default     = false
}

variable "bot_management_overrides" {
  description = "Override any other bot management attribute in the baseline (see locals.tf)."
  type        = any
  default     = {}
}

# ---------------------------------------------------------------------------------------------------------------------
# MANAGED TRANSFORMS
# ---------------------------------------------------------------------------------------------------------------------

variable "managed_request_headers_enabled" {
  description = "Managed request header transforms to switch on, e.g. add_visitor_location_headers, remove_visitor_ip_headers."
  type        = list(string)
  default     = []
}

variable "managed_response_headers_enabled" {
  description = "Managed response header transforms to switch on, e.g. add_security_headers, remove_x-powered-by_header."
  type        = list(string)
  default     = []
}

# ---------------------------------------------------------------------------------------------------------------------
# CACHING / URL NORMALIZATION / SSL / MISC TOGGLES
# ---------------------------------------------------------------------------------------------------------------------

variable "tiered_caching" {
  description = "Argo tiered caching."
  type        = bool
  default     = true
}

variable "smart_tiered_cache" {
  description = "Smart tiered cache topology."
  type        = bool
  default     = true
}

variable "cache_reserve" {
  description = "Cache Reserve (R2-backed persistent cache; billed on usage)."
  type        = bool
  default     = true
}

variable "url_normalization_type" {
  description = "URL normalization type: cloudflare or rfc3986."
  type        = string
  default     = "cloudflare"
}

variable "url_normalization_scope" {
  description = "URL normalization scope: incoming, both or none."
  type        = string
  default     = "incoming"
}

variable "universal_ssl" {
  description = "Universal SSL certificates for the zone."
  type        = bool
  default     = true
}

variable "total_tls" {
  description = "Total TLS (issue certificates for every proxied hostname)."
  type        = bool
  default     = false
}

variable "advanced_certificates" {
  description = <<-EOT
    Advanced certificate packs keyed by a stable label. Every attribute forces replacement, so adopted packs must
    match the live pack exactly. prevent_destroy guards against a plan that would delete a live certificate.
  EOT
  type = map(object({
    hosts                 = list(string)
    certificate_authority = optional(string, "google")
    validation_method     = optional(string, "http")
    validity_days         = optional(number, 90)
  }))
  default = {}
}

variable "leaked_credential_check" {
  description = "Leaked credential detection."
  type        = bool
  default     = true
}

variable "content_scanning" {
  description = "Malicious upload content scanning."
  type        = bool
  default     = false
}

variable "authenticated_origin_pulls" {
  description = "Zone-level Authenticated Origin Pulls (Cloudflare presents a client cert to the origin)."
  type        = bool
  default     = false
}

# ---------------------------------------------------------------------------------------------------------------------
# HEALTH CHECKS
# ---------------------------------------------------------------------------------------------------------------------

variable "healthchecks" {
  description = "Standalone health checks keyed by name."
  type = map(object({
    address               = string
    description           = optional(string)
    type                  = optional(string, "HTTPS")
    interval              = optional(number, 60)
    retries               = optional(number, 2)
    timeout               = optional(number, 5)
    suspended             = optional(bool, false)
    check_regions         = optional(list(string), ["OC"])
    consecutive_fails     = optional(number, 1)
    consecutive_successes = optional(number, 1)
    method                = optional(string, "GET")
    path                  = optional(string, "/health_check.php")
    port                  = optional(number, 443)
    expected_codes        = optional(list(string), ["200"])
    expected_body         = optional(string, "")
    follow_redirects      = optional(bool, false)
    allow_insecure        = optional(bool, false)
    header                = optional(map(list(string)))
  }))
  default = {}
}
