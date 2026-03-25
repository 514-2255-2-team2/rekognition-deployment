output "api_base_url" {
  value = aws_apigatewayv2_stage.default.invoke_url
}

output "search_url" {
  value = "${aws_apigatewayv2_stage.default.invoke_url}/search"
}

output "index_url" {
  value = "${aws_apigatewayv2_stage.default.invoke_url}/index"
}

output "index_lambda_name" {
  value = aws_lambda_function.indexer.function_name
}

output "search_lambda_name" {
  value = aws_lambda_function.search.function_name
}

output "upload_image_url" {
  value = "${aws_apigatewayv2_stage.default.invoke_url}/upload-image"
}

output "player_image_url" {
  value = "${aws_apigatewayv2_stage.default.invoke_url}/player-image"
}