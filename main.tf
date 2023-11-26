provider "aws" {
  region = "us-east-1"
}

//dynamodb
resource "aws_dynamodb_table" "table" {
  name           = "CUSTOMERS"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "id"
  range_key      = "name"
  attribute {
    name = "id"
    type = "S"
  }
  attribute {
    name = "name"
    type = "S"
  }
  global_secondary_index {
    name               = "name"
    hash_key           = "name"
    projection_type    = "ALL"
  }
}
//S3
resource "aws_s3_bucket" "bucket" {
    bucket = "appur16cs"
    tags = {
    Name = "appur16cs"
    }
}

resource "aws_s3_bucket_public_access_block" "access" {
  bucket = aws_s3_bucket.bucket.bucket
  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

//api role
resource "aws_iam_role" "apirole" {
  name = "apirole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action = "sts:AssumeRole",
      Effect = "Allow",
      Principal = {
        Service = "apigateway.amazonaws.com"
      }
    }]
  })
}
resource "aws_iam_policy" "apipolicy" {
  name = "apipolicy"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action = "dynamodb:*",
      Effect = "Allow",
      Resource = "*"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "apiattachment" {
  policy_arn = aws_iam_policy.apipolicy.arn
  role = aws_iam_role.apirole.name
}

//s3 Role
resource "aws_iam_role" "s3_role" {
  name = "s3_role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action = "sts:AssumeRole",
      Effect = "Allow",
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_policy" "s3_policy" {
  name = "s3_policy"
  policy = jsonencode({
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "s3:GetObject"
            ],
            "Resource": "arn:aws:s3:::*"
        },
        {
        Action   = "logs:CreateLogGroup",
        Effect   = "Allow",
        Resource = "*"
        },
        {
        Action   = "logs:CreateLogStream",
        Effect   = "Allow",
        Resource = "*"
      },
      {
        Action   = "logs:PutLogEvents",
        Effect   = "Allow",
        Resource = "*"
      }

    ]
})
}

resource "aws_iam_role_policy_attachment" "s3_attachment" {
  policy_arn = aws_iam_policy.s3_policy.arn
  role = aws_iam_role.s3_role.name
}

//API creation
resource "aws_api_gateway_rest_api" "customers" {
  name = "customer"
  endpoint_configuration {
    types = ["REGIONAL"]
  }
}
resource "aws_api_gateway_resource" "customers" {
  rest_api_id = aws_api_gateway_rest_api.customers.id
  parent_id   = aws_api_gateway_rest_api.customers.root_resource_id
  path_part   = "customers"
}

resource "aws_api_gateway_method" "POST" {
  rest_api_id   = aws_api_gateway_rest_api.customers.id
  resource_id   = aws_api_gateway_resource.customers.id
  http_method   = "POST"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "Request" {
  rest_api_id = aws_api_gateway_rest_api.customers.id
  resource_id = aws_api_gateway_resource.customers.id
  http_method = aws_api_gateway_method.POST.http_method
  integration_http_method = "POST"
  type = "AWS"
  uri  = "arn:aws:apigateway:us-east-1:dynamodb:action/PutItem"
  credentials = aws_iam_role.apirole.arn
   request_templates = {
    "application/json" = jsonencode({
    "TableName": "CUSTOMERS",
    "Item": {
      "id": {
          "S": "$input.path('$.id')"
      },
      "name":{
          "S": "$input.path('$.name')"
          }
    }
    })
  }
}

resource "aws_api_gateway_method_response" "response" {
  rest_api_id = aws_api_gateway_rest_api.customers.id
  resource_id = aws_api_gateway_resource.customers.id
  http_method = aws_api_gateway_method.POST.http_method

  response_models = {
    "application/json" = "Empty"
  }

  status_code = "200"
}
resource "aws_api_gateway_integration_response" "example_integration_response" {
  rest_api_id = aws_api_gateway_rest_api.customers.id
  resource_id = aws_api_gateway_resource.customers.id
  http_method = aws_api_gateway_method.POST.http_method
  status_code = aws_api_gateway_method_response.response.status_code

  response_templates = {
    "application/json" = ""
  }
}

resource "aws_api_gateway_deployment" "prod" {
  depends_on = [aws_api_gateway_integration.Request]

  rest_api_id = aws_api_gateway_rest_api.customers.id
  stage_name  = "prod"
}

output "api_url" {
  value = aws_api_gateway_deployment.prod.invoke_url
}

//Lambda Function
resource "aws_lambda_function" "test_lambda" {
  function_name = "lambda_function"
  handler = "lambda_function.lambda_handler"
  runtime = "python3.8"
  role = aws_iam_role.s3_role.arn
  filename = "C:/Users/DELL/OneDrive/Desktop/mydbfunc/mydbfunc/lambda_function.zip"
  source_code_hash = filebase64("C:/Users/DELL/OneDrive/Desktop/mydbfunc/mydbfunc/lambda_function.zip")
}
resource "aws_lambda_permission" "allow_bucket" {
  statement_id  = "AllowExecutionFromS3Bucket"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.test_lambda.arn
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.bucket.arn
}

resource "aws_s3_bucket_notification" "bucket_notification" {
  bucket = aws_s3_bucket.bucket.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.test_lambda.arn
    events = ["s3:ObjectCreated:*"]
  }

  depends_on = [aws_lambda_permission.allow_bucket]
}