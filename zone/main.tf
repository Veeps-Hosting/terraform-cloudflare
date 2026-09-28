data "cloudflare_zone" "this" {
  filter = {
    name = var.zone_name
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# ZONE SETTINGS
# ---------------------------------------------------------------------------------------------------------------------

resource "cloudflare_zone_setting" "this" {
  for_each = { for k, v in local.zone_settings : k => v if var.manage_zone_settings }

  zone_id    = local.zone_id
  setting_id = each.key
  value      = each.value
}

# ---------------------------------------------------------------------------------------------------------------------
# DNS
# ---------------------------------------------------------------------------------------------------------------------

resource "cloudflare_dns_record" "this" {
  for_each = var.manage_dns_records ? var.dns_records : {}

  zone_id = local.zone_id
  name    = each.value.name
  type    = each.value.type
  content = each.value.content
  proxied = each.value.proxied
  ttl     = each.value.ttl
  comment = each.value.comment
}

# ---------------------------------------------------------------------------------------------------------------------
# HEALTH CHECKS
# ---------------------------------------------------------------------------------------------------------------------

resource "cloudflare_healthcheck" "this" {
  for_each = var.healthchecks

  zone_id               = local.zone_id
  name                  = each.key
  address               = each.value.address
  description           = each.value.description
  type                  = each.value.type
  interval              = each.value.interval
  retries               = each.value.retries
  timeout               = each.value.timeout
  suspended             = each.value.suspended
  check_regions         = each.value.check_regions
  consecutive_fails     = each.value.consecutive_fails
  consecutive_successes = each.value.consecutive_successes

  http_config = {
    method           = each.value.method
    path             = each.value.path
    port             = each.value.port
    expected_codes   = each.value.expected_codes
    expected_body    = each.value.expected_body
    follow_redirects = each.value.follow_redirects
    allow_insecure   = each.value.allow_insecure
    header           = each.value.header
  }
}
