locals {
  zone_id = data.cloudflare_zone.this.zone_id

  onoff = { true = "on", false = "off" }

  # Zone settings shared by every adopted zone (allangray.com.au and judo.bank matched on all of these, 2026-09-28).
  # Deliberately absent: read-only settings (advanced_ddos, proxy_read_timeout, ...), development_mode (a temporary
  # toggle Terraform shouldn't fight), and deprecated ones (minify, mirage, mobile_redirect, tls_1_2_only, waf).
  zone_settings_baseline = {
    "0rtt"                    = "on"
    always_online             = "on"
    always_use_https          = "on"
    automatic_https_rewrites  = "on"
    brotli                    = "off"
    browser_cache_ttl         = 14400
    browser_check             = "on"
    cache_level               = "aggressive"
    cname_flattening          = "flatten_at_root"
    early_hints               = "on"
    ech                       = "on"
    edge_cache_ttl            = 7200
    email_obfuscation         = "on"
    filter_logs_to_cloudflare = "off"
    hotlink_protection        = "on"
    http2                     = "on"
    http3                     = "on"
    ip_geolocation            = "on"
    ipv6                      = "on"
    log_to_cloudflare         = "on"
    min_tls_version           = "1.2"
    opportunistic_encryption  = "on"
    orange_to_orange          = "off"
    polish                    = "lossless"
    pq_keyex                  = "on"
    privacy_pass              = "on"
    replace_insecure_js       = "on"
    rocket_loader             = "off"
    security_header = {
      strict_transport_security = {
        enabled            = false
        max_age            = 0
        include_subdomains = false
        preload            = false
        nosniff            = false
      }
    }
    security_level      = "medium"
    server_side_exclude = "on"
    ssl                 = "full"
    tls_1_3             = "zrt"
    tls_client_auth     = "off"
    visitor_ip          = "on"
    webp                = "on"
  }

  zone_settings = merge(
    local.zone_settings_baseline,
    {
      websockets          = local.onoff[var.websockets]
      opportunistic_onion = local.onoff[var.opportunistic_onion]
      pseudo_ipv4         = var.pseudo_ipv4
      max_upload          = var.max_upload
      challenge_ttl       = var.challenge_ttl
      ciphers             = var.ciphers
    },
    var.zone_settings_overrides,
  )

  # Bot management baseline (Super Bot Fight Mode on Business), shared by every adopted zone.
  # cf_robots_variant and bot_preference_sync_enabled stay null unless set: provider 5.26 doesn't read them back on
  # import, so managing them turns adoption into a write.
  bot_management = merge(
    {
      ai_bots_migration_opt_out       = false
      ai_bots_protection              = "block"
      aisearch                        = "disabled"
      ai_training                     = "disallow"
      ai_user                         = "disabled"
      cf_robots_variant               = null
      content_bots_protection         = "disabled"
      crawler_protection              = "enabled"
      enable_js                       = true
      optimize_wordpress              = true
      sbfm_definitely_automated       = "managed_challenge"
      sbfm_likely_automated           = "managed_challenge"
      sbfm_static_resource_protection = true
      sbfm_verified_bots              = "allow"
      suppress_session_score          = false
    },
    {
      bot_preference_sync_enabled = var.bot_preference_sync_enabled
      is_robots_txt_managed       = var.is_robots_txt_managed
    },
    var.bot_management_overrides,
  )

  refs = merge(
    {
      icinga_allowlist          = "icinga_allowlist"
      block_xmlrpc              = "block_xmlrpc"
      block_ai_bots             = "[CF AI Audit]"
      waf_cloudflare_managed    = "waf_cloudflare_managed"
      waf_owasp                 = "waf_owasp"
      cache_bypass_health_check = "cache_bypass_health_check"
      cache_bypass_admin        = "cache_bypass_admin"
      cache_everything          = "cache_everything"
    },
    var.rule_refs,
  )

  # Cloudflare-owned managed ruleset IDs; identical in every account.
  cloudflare_managed_ruleset_id = "efb7b8c949ac4650a09736fc376e9aee"
  owasp_ruleset_id              = "4814384a9e5d4991b9815dcfc25d2f1f"
  owasp_anomaly_score_rule_id   = "6179ae15870a4bb7b2d480d4843b323c" # 949110 Inbound Anomaly Score Exceeded

  # Skip everything (managed WAF, rate limiting, SBFM and the legacy products) for trusted sources.
  skip_all_parameters = {
    phases   = ["http_ratelimit", "http_request_firewall_managed", "http_request_sbfm"]
    products = ["zoneLockdown", "uaBlock", "bic", "hot", "securityLevel", "rateLimit", "waf"]
    ruleset  = "current"
  }
}
