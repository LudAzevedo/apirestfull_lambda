output "api_endpoint" {
  value = aws_apigatewayv2_stage.default.invoke_url # Mostra o URL para invocar a API
}