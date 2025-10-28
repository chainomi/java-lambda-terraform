output "hello_world_api_internal_endpoint" {
  value = "${aws_apigatewayv2_api.http_api.api_endpoint}/${local.environment}/hello"
}

output "hello_universe_api_internal_endpoint" {
  value = "${aws_apigatewayv2_api.http_api.api_endpoint}/${local.environment}/universe"
}

output "hello_world_api_external_endpoint" {
  value = "https://${local.DNS.domain}/hello"
}

output "hello_universe_api_external_endpoint" {
  value = "https://${local.DNS.domain}/universe"
}

