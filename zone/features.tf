# Zone-level singletons. Each resource maps to one Cloudflare API setting on the zone.

resource "cloudflare_bot_management" "this" {
  count = var.manage_bot_management ? 1 : 0

  zone_id                         = local.zone_id
  ai_bots_migration_opt_out       = local.bot_management.ai_bots_migration_opt_out
  ai_bots_protection              = local.bot_management.ai_bots_protection
  aisearch                        = local.bot_management.aisearch
  ai_training                     = local.bot_management.ai_training
  ai_user                         = local.bot_management.ai_user
  bot_preference_sync_enabled     = local.bot_management.bot_preference_sync_enabled
  cf_robots_variant               = local.bot_management.cf_robots_variant
  content_bots_protection         = local.bot_management.content_bots_protection
  crawler_protection              = local.bot_management.crawler_protection
  enable_js                       = local.bot_management.enable_js
  is_robots_txt_managed           = local.bot_management.is_robots_txt_managed
  optimize_wordpress              = local.bot_management.optimize_wordpress
  sbfm_definitely_automated       = local.bot_management.sbfm_definitely_automated
  sbfm_likely_automated           = local.bot_management.sbfm_likely_automated
  sbfm_static_resource_protection = local.bot_management.sbfm_static_resource_protection
  sbfm_verified_bots              = local.bot_management.sbfm_verified_bots
  suppress_session_score          = local.bot_management.suppress_session_score
}

resource "cloudflare_managed_transforms" "this" {
  count = var.manage_managed_transforms ? 1 : 0

  zone_id = local.zone_id
  # Cloudflare only reports enabled transforms, so list just those; anything absent is off.
  managed_request_headers  = [for id in var.managed_request_headers_enabled : { id = id, enabled = true }]
  managed_response_headers = [for id in var.managed_response_headers_enabled : { id = id, enabled = true }]
}

resource "cloudflare_argo_tiered_caching" "this" {
  count = var.manage_tiered_caching ? 1 : 0

  zone_id = local.zone_id
  value   = local.onoff[var.tiered_caching]
}

resource "cloudflare_tiered_cache" "this" {
  count = var.manage_tiered_caching ? 1 : 0

  zone_id = local.zone_id
  value   = local.onoff[var.smart_tiered_cache]
}

resource "cloudflare_zone_cache_reserve" "this" {
  count = var.manage_tiered_caching ? 1 : 0

  zone_id = local.zone_id
  value   = local.onoff[var.cache_reserve]
}

resource "cloudflare_url_normalization_settings" "this" {
  count = var.manage_url_normalization ? 1 : 0

  zone_id = local.zone_id
  type    = var.url_normalization_type
  scope   = var.url_normalization_scope
}

resource "cloudflare_universal_ssl_setting" "this" {
  count = var.manage_ssl ? 1 : 0

  zone_id = local.zone_id
  enabled = var.universal_ssl
}

resource "cloudflare_total_tls" "this" {
  count = var.manage_ssl ? 1 : 0

  zone_id = local.zone_id
  enabled = var.total_tls
}

resource "cloudflare_certificate_pack" "this" {
  for_each = var.advanced_certificates

  zone_id               = local.zone_id
  type                  = "advanced"
  hosts                 = each.value.hosts
  certificate_authority = each.value.certificate_authority
  validation_method     = each.value.validation_method
  validity_days         = each.value.validity_days

  lifecycle {
    prevent_destroy = true
  }
}

resource "cloudflare_leaked_credential_check" "this" {
  count = var.manage_leaked_credential_check ? 1 : 0

  zone_id = local.zone_id
  enabled = var.leaked_credential_check
}

resource "cloudflare_content_scanning" "this" {
  count = var.manage_content_scanning ? 1 : 0

  zone_id = local.zone_id
  value   = var.content_scanning ? "enabled" : "disabled"
}

resource "cloudflare_authenticated_origin_pulls_settings" "this" {
  count = var.manage_authenticated_origin_pulls ? 1 : 0

  zone_id = local.zone_id
  enabled = var.authenticated_origin_pulls
}
