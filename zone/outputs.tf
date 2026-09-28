output "zone_id" {
  description = "Cloudflare zone ID."
  value       = local.zone_id
}

output "dns_record_ids" {
  description = "DNS record IDs keyed like var.dns_records."
  value       = { for k, r in cloudflare_dns_record.this : k => r.id }
}

output "custom_firewall_ruleset_id" {
  description = "ID of the http_request_firewall_custom entrypoint ruleset, or null."
  value       = one(cloudflare_ruleset.custom_firewall[*].id)
}

output "managed_waf_ruleset_id" {
  description = "ID of the http_request_firewall_managed entrypoint ruleset, or null."
  value       = one(cloudflare_ruleset.managed_waf[*].id)
}

output "cache_ruleset_id" {
  description = "ID of the http_request_cache_settings entrypoint ruleset, or null."
  value       = one(cloudflare_ruleset.cache[*].id)
}
