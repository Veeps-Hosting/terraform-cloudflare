# Zone entrypoint rulesets. Each one is authoritative for its phase: rules added in the dashboard get removed on the
# next apply, so put them in the leaf instead.
#
# rules go through jsondecode(jsonencode()) because generated and raw rules have different object shapes (e.g.
# overrides with and without action); the round trip turns the list into a tuple the provider converts per element.

locals {
  ip_expression = { for ip in distinct(concat(var.icinga_allowlist_ips, var.icinga_allowlist_extra_ips, flatten(var.ip_allowlists[*].ips))) :
    ip => strcontains(ip, "/") ? "(ip.src in {${ip}})" : "(ip.src eq ${ip})"
  }

  icinga_rule = var.icinga_allowlist ? [{
    description       = "Icinga External URL Whitelist"
    action            = "skip"
    action_parameters = local.skip_all_parameters
    expression        = join(" or ", [for ip in concat(var.icinga_allowlist_ips, var.icinga_allowlist_extra_ips) : local.ip_expression[ip]])
    logging           = { enabled = true }
    ref               = local.refs.icinga_allowlist
  }] : []

  allowlist_rules = [for a in var.ip_allowlists : {
    description       = a.description
    action            = "skip"
    action_parameters = local.skip_all_parameters
    expression        = join(" or ", [for ip in a.ips : local.ip_expression[ip]])
    logging           = { enabled = true }
    ref               = coalesce(a.ref, replace(lower(a.description), "/[^a-z0-9]+/", "_"))
  }]

  xmlrpc_rule = var.block_xmlrpc ? [{
    description = "Block XML-RPC"
    action      = "block"
    expression  = "(http.request.uri.path contains \"/xmlrpc.php\")"
    ref         = local.refs.block_xmlrpc
  }] : []

  ai_bots_rule = var.block_ai_bots_by_user_agent ? [{
    description = "AI Crawl Control - Block AI bots by User Agent"
    action      = "block"
    action_parameters = {
      response = {
        content      = jsonencode({ message = "Please contact the site owner for access." })
        content_type = "application/json"
        status_code  = 402
      }
    }
    expression = "(http.request.uri.path ne \"/robots.txt\") and (${join(" or ", [for ua in var.ai_bot_user_agents : "(http.user_agent contains \"${ua}\")"])})"
    ref        = local.refs.block_ai_bots
  }] : []

  custom_firewall_rules = concat(
    var.firewall_rules_head,
    local.icinga_rule,
    local.allowlist_rules,
    local.xmlrpc_rule,
    local.ai_bots_rule,
    var.firewall_rules_tail,
  )

  managed_waf_rules = concat(
    var.waf_cloudflare_managed ? [{
      action = "execute"
      action_parameters = {
        id        = local.cloudflare_managed_ruleset_id
        overrides = var.waf_cloudflare_managed_overrides
        version   = "latest"
      }
      expression = "true"
      ref        = local.refs.waf_cloudflare_managed
    }] : [],
    var.waf_owasp ? [{
      action = "execute"
      action_parameters = {
        id = local.owasp_ruleset_id
        overrides = {
          categories = [for c in var.waf_owasp_disabled_categories : { category = c, enabled = false }]
          rules = [{
            id              = local.owasp_anomaly_score_rule_id
            score_threshold = var.waf_owasp_score_threshold
            action          = var.waf_owasp_action
          }]
        }
        version = "latest"
      }
      expression = "true"
      ref        = local.refs.waf_owasp
    }] : [],
  )

  cache_rules = concat(
    var.cache_bypass_health_check ? [{
      description       = "Wordpress Health Check Cache Bypass"
      action            = "set_cache_settings"
      action_parameters = { cache = false }
      expression        = "(http.request.uri.path ${var.health_check_path_operator} \"${var.health_check_path}\")"
      ref               = local.refs.cache_bypass_health_check
    }] : [],
    length(var.cache_bypass_admin_paths) > 0 ? [{
      description       = "Wordpress Admin Cache-Bypass"
      action            = "set_cache_settings"
      action_parameters = { cache = false }
      expression        = join(" or ", [for p in var.cache_bypass_admin_paths : "(http.request.uri.path contains \"${p}\")"])
      ref               = local.refs.cache_bypass_admin
    }] : [],
    var.cache_everything ? [{
      description       = "Cache Everything"
      action            = "set_cache_settings"
      action_parameters = { cache = true }
      expression        = "true"
      ref               = local.refs.cache_everything
    }] : [],
  )
}

resource "cloudflare_ruleset" "custom_firewall" {
  count = var.manage_custom_firewall_rules && length(local.custom_firewall_rules) > 0 ? 1 : 0

  zone_id = local.zone_id
  name    = "default"
  kind    = "zone"
  phase   = "http_request_firewall_custom"
  rules   = jsondecode(jsonencode(local.custom_firewall_rules))
}

resource "cloudflare_ruleset" "managed_waf" {
  count = var.manage_managed_waf && length(local.managed_waf_rules) > 0 ? 1 : 0

  zone_id = local.zone_id
  name    = "default"
  kind    = "zone"
  phase   = "http_request_firewall_managed"
  rules   = jsondecode(jsonencode(local.managed_waf_rules))
}

resource "cloudflare_ruleset" "cache" {
  count = var.manage_cache_rules && length(local.cache_rules) > 0 ? 1 : 0

  zone_id = local.zone_id
  name    = "default"
  kind    = "zone"
  phase   = "http_request_cache_settings"
  rules   = jsondecode(jsonencode(local.cache_rules))
}
