# ---------------------------------------------------------------------------------------------------------------------
# ADOPT AN EXISTING ZONE
# With adopt_existing = true every enabled resource gets an import block whose ID is looked up live, so the first
# plan on an existing zone reads "N to import" instead of "N to add". Once imported the blocks are no-ops; leave the
# flag on or turn it off, either way is safe. Import blocks only work when this module is the root module, which is
# always the case under Terragrunt.
# ---------------------------------------------------------------------------------------------------------------------

variable "adopt_existing" {
  description = "Import the zone's existing Cloudflare objects into state instead of creating them."
  type        = bool
  default     = false
}

data "cloudflare_rulesets" "adopt" {
  count   = var.adopt_existing ? 1 : 0
  zone_id = local.zone_id
}

data "cloudflare_dns_records" "adopt" {
  count   = var.adopt_existing && var.manage_dns_records && length(var.dns_records) > 0 ? 1 : 0
  zone_id = local.zone_id
}

data "cloudflare_healthchecks" "adopt" {
  count   = var.adopt_existing && length(var.healthchecks) > 0 ? 1 : 0
  zone_id = local.zone_id
}

data "cloudflare_certificate_packs" "adopt" {
  count   = var.adopt_existing && length(var.advanced_certificates) > 0 ? 1 : 0
  zone_id = local.zone_id
}

locals {
  adopt_ruleset_ids = var.adopt_existing ? {
    for r in data.cloudflare_rulesets.adopt[0].rulesets : r.phase => r.id if r.kind == "zone"
  } : {}

  adopt_dns_ids = length(data.cloudflare_dns_records.adopt) > 0 ? {
    for k, v in var.dns_records : k => one([
      for r in data.cloudflare_dns_records.adopt[0].result : r.id if r.name == v.name && r.type == v.type
    ])
  } : {}

  adopt_healthcheck_ids = length(data.cloudflare_healthchecks.adopt) > 0 ? {
    for k, v in var.healthchecks : k => one([for h in data.cloudflare_healthchecks.adopt[0].result : h.id if h.name == k])
  } : {}

  adopt_certificate_ids = length(data.cloudflare_certificate_packs.adopt) > 0 ? {
    for k, v in var.advanced_certificates : k => one([
      for c in data.cloudflare_certificate_packs.adopt[0].result : c.id
      if c.type == "advanced" && toset(c.hosts) == toset(v.hosts)
    ])
  } : {}

  adopt_singletons = var.adopt_existing ? toset(compact([
    var.manage_bot_management ? "bot_management" : "",
    var.manage_managed_transforms ? "managed_transforms" : "",
    var.manage_tiered_caching ? "tiered_caching" : "",
    var.manage_url_normalization ? "url_normalization" : "",
    var.manage_ssl ? "ssl" : "",
    var.manage_leaked_credential_check ? "leaked_credential_check" : "",
    var.manage_authenticated_origin_pulls ? "authenticated_origin_pulls" : "",
  ])) : toset([])
}

import {
  for_each = { for k, v in local.zone_settings : k => v if var.adopt_existing && var.manage_zone_settings }
  to       = cloudflare_zone_setting.this[each.key]
  id       = "${local.zone_id}/${each.key}"
}

import {
  for_each = local.adopt_dns_ids
  to       = cloudflare_dns_record.this[each.key]
  id       = "${local.zone_id}/${each.value}"
}

import {
  for_each = local.adopt_healthcheck_ids
  to       = cloudflare_healthcheck.this[each.key]
  id       = "${local.zone_id}/${each.value}"
}

import {
  for_each = local.adopt_certificate_ids
  to       = cloudflare_certificate_pack.this[each.key]
  id       = "${local.zone_id}/${each.value}"
}

import {
  for_each = var.manage_custom_firewall_rules && length(local.custom_firewall_rules) > 0 && contains(keys(local.adopt_ruleset_ids), "http_request_firewall_custom") ? toset(["this"]) : toset([])
  to       = cloudflare_ruleset.custom_firewall[0]
  id       = "zones/${local.zone_id}/${local.adopt_ruleset_ids["http_request_firewall_custom"]}"
}

import {
  for_each = var.manage_managed_waf && length(local.managed_waf_rules) > 0 && contains(keys(local.adopt_ruleset_ids), "http_request_firewall_managed") ? toset(["this"]) : toset([])
  to       = cloudflare_ruleset.managed_waf[0]
  id       = "zones/${local.zone_id}/${local.adopt_ruleset_ids["http_request_firewall_managed"]}"
}

import {
  for_each = var.manage_cache_rules && length(local.cache_rules) > 0 && contains(keys(local.adopt_ruleset_ids), "http_request_cache_settings") ? toset(["this"]) : toset([])
  to       = cloudflare_ruleset.cache[0]
  id       = "zones/${local.zone_id}/${local.adopt_ruleset_ids["http_request_cache_settings"]}"
}

import {
  for_each = contains(local.adopt_singletons, "bot_management") ? toset(["this"]) : toset([])
  to       = cloudflare_bot_management.this[0]
  id       = local.zone_id
}

import {
  for_each = contains(local.adopt_singletons, "managed_transforms") ? toset(["this"]) : toset([])
  to       = cloudflare_managed_transforms.this[0]
  id       = local.zone_id
}

import {
  for_each = contains(local.adopt_singletons, "tiered_caching") ? toset(["this"]) : toset([])
  to       = cloudflare_argo_tiered_caching.this[0]
  id       = local.zone_id
}

import {
  for_each = contains(local.adopt_singletons, "tiered_caching") ? toset(["this"]) : toset([])
  to       = cloudflare_tiered_cache.this[0]
  id       = local.zone_id
}

import {
  for_each = contains(local.adopt_singletons, "tiered_caching") ? toset(["this"]) : toset([])
  to       = cloudflare_zone_cache_reserve.this[0]
  id       = local.zone_id
}

import {
  for_each = contains(local.adopt_singletons, "url_normalization") ? toset(["this"]) : toset([])
  to       = cloudflare_url_normalization_settings.this[0]
  id       = local.zone_id
}

import {
  for_each = contains(local.adopt_singletons, "ssl") ? toset(["this"]) : toset([])
  to       = cloudflare_universal_ssl_setting.this[0]
  id       = local.zone_id
}

import {
  for_each = contains(local.adopt_singletons, "ssl") ? toset(["this"]) : toset([])
  to       = cloudflare_total_tls.this[0]
  id       = local.zone_id
}

import {
  for_each = contains(local.adopt_singletons, "leaked_credential_check") ? toset(["this"]) : toset([])
  to       = cloudflare_leaked_credential_check.this[0]
  id       = local.zone_id
}


import {
  for_each = contains(local.adopt_singletons, "authenticated_origin_pulls") ? toset(["this"]) : toset([])
  to       = cloudflare_authenticated_origin_pulls_settings.this[0]
  id       = local.zone_id
}
