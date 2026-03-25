data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

data "archive_file" "indexer_zip" {
  type        = "zip"
  source_file = "${path.module}/../lambda/index_players.py"
  output_path = "${path.module}/index_players.zip"
}

data "archive_file" "search_zip" {
  type        = "zip"
  source_file = "${path.module}/../lambda/search_players.py"
  output_path = "${path.module}/search_players.zip"
}

data "archive_file" "upload_image_zip" {
  type        = "zip"
  source_file = "${path.module}/../lambda/upload_player_image.py"
  output_path = "${path.module}/upload_player_image.zip"
}

data "archive_file" "fetch_image_zip" {
  type        = "zip"
  source_file = "${path.module}/../lambda/fetch_player_image.py"
  output_path = "${path.module}/fetch_player_image.zip"
}

data "aws_iam_policy_document" "lambda_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

#
# IAM: indexer Lambda
#
resource "aws_iam_role" "indexer" {
  name               = "${var.project_name}-indexer-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json
}

resource "aws_iam_role_policy_attachment" "indexer_basic" {
  role       = aws_iam_role.indexer.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

data "aws_iam_policy_document" "indexer_policy" {
  statement {
    sid = "DynamoDBAccess"

    actions = [
      "dynamodb:Scan",
      "dynamodb:UpdateItem"
    ]

    resources = [
      "arn:aws:dynamodb:${data.aws_region.current.id}:${data.aws_caller_identity.current.account_id}:table/${var.table_name}"
    ]
  }

  statement {
    sid = "S3ReadImages"

    actions = [
      "s3:GetObject"
    ]

    resources = [
      "arn:aws:s3:::${var.bucket_name}/*"
    ]
  }

  statement {
    sid = "RekognitionIndex"

    actions = [
      "rekognition:CreateCollection",
      "rekognition:IndexFaces"
    ]

    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "indexer_inline" {
  name   = "${var.project_name}-indexer-policy"
  role   = aws_iam_role.indexer.id
  policy = data.aws_iam_policy_document.indexer_policy.json
}

#
# IAM: search Lambda
#
resource "aws_iam_role" "search" {
  name               = "${var.project_name}-search-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json
}

resource "aws_iam_role_policy_attachment" "search_basic" {
  role       = aws_iam_role.search.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

data "aws_iam_policy_document" "search_policy" {
  statement {
    sid = "S3ReadImages"

    actions = [
      "s3:GetObject"
    ]

    resources = [
      "arn:aws:s3:::${var.bucket_name}/*"
    ]
  }

  statement {
    sid = "RekognitionSearch"

    actions = [
      "rekognition:SearchFacesByImage"
    ]

    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "search_inline" {
  name   = "${var.project_name}-search-policy"
  role   = aws_iam_role.search.id
  policy = data.aws_iam_policy_document.search_policy.json
}

#
# IAM: upload image Lambda
#
resource "aws_iam_role" "upload_image" {
  name               = "${var.project_name}-upload-image-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json
}

resource "aws_iam_role_policy_attachment" "upload_image_basic" {
  role       = aws_iam_role.upload_image.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

data "aws_iam_policy_document" "upload_image_policy" {
  statement {
    sid = "DynamoDBPlayerReadWrite"

    actions = [
      "dynamodb:GetItem",
      "dynamodb:UpdateItem"
    ]

    resources = [
      "arn:aws:dynamodb:${data.aws_region.current.id}:${data.aws_caller_identity.current.account_id}:table/${var.table_name}"
    ]
  }

  statement {
    sid = "S3PutPlayerImage"

    actions = [
      "s3:PutObject"
    ]

    resources = [
      "arn:aws:s3:::${var.bucket_name}/*"
    ]
  }
}

resource "aws_iam_role_policy" "upload_image_inline" {
  name   = "${var.project_name}-upload-image-policy"
  role   = aws_iam_role.upload_image.id
  policy = data.aws_iam_policy_document.upload_image_policy.json
}

#
# IAM: fetch player image Lambda
#
resource "aws_iam_role" "fetch_image" {
  name               = "${var.project_name}-fetch-image-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json
}

resource "aws_iam_role_policy_attachment" "fetch_image_basic" {
  role       = aws_iam_role.fetch_image.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

data "aws_iam_policy_document" "fetch_image_policy" {
  statement {
    sid = "DynamoDBPlayerRead"

    actions = [
      "dynamodb:GetItem"
    ]

    resources = [
      "arn:aws:dynamodb:${data.aws_region.current.id}:${data.aws_caller_identity.current.account_id}:table/${var.table_name}"
    ]
  }

  statement {
    sid = "S3GetPlayerImage"

    actions = [
      "s3:GetObject"
    ]

    resources = [
      "arn:aws:s3:::${var.bucket_name}/*"
    ]
  }
}

resource "aws_iam_role_policy" "fetch_image_inline" {
  name   = "${var.project_name}-fetch-image-policy"
  role   = aws_iam_role.fetch_image.id
  policy = data.aws_iam_policy_document.fetch_image_policy.json
}

#
# Lambdas
#
resource "aws_lambda_function" "indexer" {
  function_name    = "${var.project_name}-indexer"
  role             = aws_iam_role.indexer.arn
  filename         = data.archive_file.indexer_zip.output_path
  source_code_hash = data.archive_file.indexer_zip.output_base64sha256

  runtime = "python3.12"
  handler = "index_players.lambda_handler"

  timeout     = var.index_lambda_timeout
  memory_size = 512

  environment {
    variables = {
      TABLE_NAME  = var.table_name
      BUCKET_NAME = var.bucket_name
    }
  }

  depends_on = [
    aws_iam_role_policy_attachment.indexer_basic,
    aws_iam_role_policy.indexer_inline
  ]
}

resource "aws_lambda_function" "search" {
  function_name    = "${var.project_name}-search"
  role             = aws_iam_role.search.arn
  filename         = data.archive_file.search_zip.output_path
  source_code_hash = data.archive_file.search_zip.output_base64sha256

  runtime = "python3.12"
  handler = "search_players.lambda_handler"

  timeout     = var.search_lambda_timeout
  memory_size = 256

  environment {
    variables = {
      BUCKET_NAME = var.bucket_name
    }
  }

  depends_on = [
    aws_iam_role_policy_attachment.search_basic,
    aws_iam_role_policy.search_inline
  ]
}

resource "aws_lambda_function" "upload_image" {
  function_name    = "${var.project_name}-upload-image"
  role             = aws_iam_role.upload_image.arn
  filename         = data.archive_file.upload_image_zip.output_path
  source_code_hash = data.archive_file.upload_image_zip.output_base64sha256

  runtime = "python3.12"
  handler = "upload_player_image.lambda_handler"

  timeout     = var.search_lambda_timeout
  memory_size = 256

  environment {
    variables = {
      TABLE_NAME  = var.table_name
      BUCKET_NAME = var.bucket_name
    }
  }

  depends_on = [
    aws_iam_role_policy_attachment.upload_image_basic,
    aws_iam_role_policy.upload_image_inline
  ]
}

resource "aws_lambda_function" "fetch_image" {
  function_name    = "${var.project_name}-fetch-image"
  role             = aws_iam_role.fetch_image.arn
  filename         = data.archive_file.fetch_image_zip.output_path
  source_code_hash = data.archive_file.fetch_image_zip.output_base64sha256

  runtime = "python3.12"
  handler = "fetch_player_image.lambda_handler"

  timeout     = var.search_lambda_timeout
  memory_size = 256

  environment {
    variables = {
      TABLE_NAME  = var.table_name
      BUCKET_NAME = var.bucket_name
    }
  }

  depends_on = [
    aws_iam_role_policy_attachment.fetch_image_basic,
    aws_iam_role_policy.fetch_image_inline
  ]
}

#
# API Gateway HTTP API
#
resource "aws_apigatewayv2_api" "http" {
  name          = "${var.project_name}-http"
  protocol_type = "HTTP"

  cors_configuration {
    allow_origins = var.allowed_origins
    allow_methods = ["POST", "OPTIONS"]
    allow_headers = ["content-type"]
    max_age       = 300
  }
}

resource "aws_apigatewayv2_integration" "search" {
  api_id                 = aws_apigatewayv2_api.http.id
  integration_type       = "AWS_PROXY"
  integration_method     = "POST"
  integration_uri        = aws_lambda_function.search.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_integration" "indexer" {
  api_id                 = aws_apigatewayv2_api.http.id
  integration_type       = "AWS_PROXY"
  integration_method     = "POST"
  integration_uri        = aws_lambda_function.indexer.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_integration" "upload_image" {
  api_id                 = aws_apigatewayv2_api.http.id
  integration_type       = "AWS_PROXY"
  integration_method     = "POST"
  integration_uri        = aws_lambda_function.upload_image.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_integration" "fetch_image" {
  api_id                 = aws_apigatewayv2_api.http.id
  integration_type       = "AWS_PROXY"
  integration_method     = "POST"
  integration_uri        = aws_lambda_function.fetch_image.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "search_post" {
  api_id    = aws_apigatewayv2_api.http.id
  route_key = "POST /search"
  target    = "integrations/${aws_apigatewayv2_integration.search.id}"
}

resource "aws_apigatewayv2_route" "index_post" {
  api_id    = aws_apigatewayv2_api.http.id
  route_key = "POST /index"
  target    = "integrations/${aws_apigatewayv2_integration.indexer.id}"
}

resource "aws_apigatewayv2_route" "upload_image_post" {
  api_id    = aws_apigatewayv2_api.http.id
  route_key = "POST /upload-image"
  target    = "integrations/${aws_apigatewayv2_integration.upload_image.id}"
}

resource "aws_apigatewayv2_route" "fetch_image_post" {
  api_id    = aws_apigatewayv2_api.http.id
  route_key = "POST /player-image"
  target    = "integrations/${aws_apigatewayv2_integration.fetch_image.id}"
}

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.http.id
  name        = "$default"
  auto_deploy = true
}

#
# Allow API Gateway to invoke Lambdas
#
resource "aws_lambda_permission" "apigw_search" {
  statement_id  = "AllowAPIGatewayInvokeSearch"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.search.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.http.execution_arn}/*/*"
}

resource "aws_lambda_permission" "apigw_indexer" {
  statement_id  = "AllowAPIGatewayInvokeIndexer"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.indexer.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.http.execution_arn}/*/*"
}

resource "aws_lambda_permission" "apigw_upload_image" {
  statement_id  = "AllowAPIGatewayInvokeUploadImage"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.upload_image.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.http.execution_arn}/*/*"
}

resource "aws_lambda_permission" "apigw_fetch_image" {
  statement_id  = "AllowAPIGatewayInvokeFetchImage"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.fetch_image.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.http.execution_arn}/*/*"
}

#
# Invoke the indexer once after deploy / when its code or key settings change
#
resource "terraform_data" "run_index_after_apply" {
  count = var.invoke_index_on_apply ? 1 : 0

  triggers_replace = {
    code_hash   = data.archive_file.indexer_zip.output_base64sha256
    table_name  = var.table_name
    bucket_name = var.bucket_name
  }

  provisioner "local-exec" {
    command = <<-EOT
      aws lambda invoke \
        --function-name ${aws_lambda_function.indexer.function_name} \
        --cli-binary-format raw-in-base64-out \
        --payload '{}' \
        ${path.module}/indexer-response.json >/dev/null
    EOT
  }

  depends_on = [
    aws_lambda_function.indexer
  ]
}