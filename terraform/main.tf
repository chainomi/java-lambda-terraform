data "aws_caller_identity" "current" {}

locals {
  region      = "us-west-1"
  environment = "dev"
  DNS = {
    domain          = "java-api.chainomi.link"
    hosted_zone_id  = "Z0834777220EWKD9EFTTL"
    certificate_arn = "arn:aws:acm:us-west-1:${data.aws_caller_identity.current.account_id}:certificate/b1c9bf2e-31c3-4cd9-83de-d09fae059f7a"
  }

  application_name = "hello-world-java"
  lambda = {
    payload_filename = "../app/target/hello-world-lambda-1.0.jar"
    runtime          = "java17"
  }
  functions = {
    hello-world-java = {
      handler = "example.HelloWorldHandler"
      path    = "/hello"
    }
    hello-universe-java = {
      handler = "example.HelloUniverseHandler"
      path    = "/universe"
    }
  }

  tags = {
    Terraform      = "true"
    TerraformStack = local.application_name
    Environment    = local.environment
  }

}



# Lambda function

resource "aws_lambda_function" "this" {
  for_each = local.functions

  function_name = "${local.environment}-${each.key}"
  role          = aws_iam_role.lambda_role.arn
  handler       = each.value.handler
  runtime       = local.lambda.runtime
  #   memory_size      = 512
  #   timeout          = 10
  filename         = local.lambda.payload_filename
  source_code_hash = base64sha256(filebase64(local.lambda.payload_filename))
}

# API gateway

resource "aws_apigatewayv2_api" "http_api" {
  name          = "${local.environment}-${local.application_name}-api"
  protocol_type = "HTTP"
}

resource "aws_apigatewayv2_integration" "lambda_integration" {
  for_each = local.functions

  api_id = aws_apigatewayv2_api.http_api.id

  integration_type   = "AWS_PROXY"
  integration_uri    = aws_lambda_function.this[each.key].invoke_arn
  integration_method = "POST"
  #   payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "this" {
  for_each = local.functions

  api_id    = aws_apigatewayv2_api.http_api.id
  route_key = "GET ${each.value.path}"
  target    = "integrations/${aws_apigatewayv2_integration.lambda_integration[each.key].id}"
}

resource "aws_lambda_permission" "apigw" {
  for_each = local.functions

  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.this[each.key].function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.http_api.execution_arn}/*/*"
}

resource "aws_apigatewayv2_stage" "this" {
  api_id      = aws_apigatewayv2_api.http_api.id
  name        = local.environment
  auto_deploy = true

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api_gw.arn

    format = jsonencode({
      requestId               = "$context.requestId"
      sourceIp                = "$context.identity.sourceIp"
      requestTime             = "$context.requestTime"
      protocol                = "$context.protocol"
      httpMethod              = "$context.httpMethod"
      resourcePath            = "$context.resourcePath"
      routeKey                = "$context.routeKey"
      status                  = "$context.status"
      responseLength          = "$context.responseLength"
      integrationErrorMessage = "$context.integrationErrorMessage"
      }
    )
  }
}


# cloudwatch log groups

## lambda
resource "aws_cloudwatch_log_group" "lambda" {
  for_each = local.functions

  name = "/aws/lambda/${aws_lambda_function.this[each.key].function_name}"

  retention_in_days = 30
}

## api gw

resource "aws_cloudwatch_log_group" "api_gw" {
  name = "/aws/api_gw/${aws_apigatewayv2_api.http_api.name}"

  retention_in_days = 30
}


# DNS 

## api gateway custom domain  and domain mapping
resource "aws_apigatewayv2_domain_name" "custom" {
  domain_name = local.DNS.domain

  domain_name_configuration {
    certificate_arn = local.DNS.certificate_arn
    endpoint_type   = "REGIONAL"
    security_policy = "TLS_1_2"
  }
}

resource "aws_apigatewayv2_api_mapping" "api_domain_mapping" {
  api_id      = aws_apigatewayv2_api.http_api.id
  domain_name = aws_apigatewayv2_domain_name.custom.domain_name
  stage       = aws_apigatewayv2_stage.this.id
}

## route 53 alias

resource "aws_route53_record" "api_gateway_alias" {
  zone_id = local.DNS.hosted_zone_id
  name    = local.DNS.domain
  type    = "A"

  alias {
    name                   = aws_apigatewayv2_domain_name.custom.domain_name_configuration[0].target_domain_name
    zone_id                = aws_apigatewayv2_domain_name.custom.domain_name_configuration[0].hosted_zone_id
    evaluate_target_health = false
  }
}