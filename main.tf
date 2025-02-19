provider "aws" {
  region = "us-east-1"
}

# S3 Buckets
resource "aws_s3_bucket" "raw_data_bucket" {
  bucket = "weather-raw-data"
}

resource "aws_s3_bucket" "processed_data_bucket" {
  bucket = "weather-processed-data"
}


# IAM Role for Lambda
resource "aws_iam_role" "lambda_role" {
  name = "weather_lambda_role"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow"
    }
  ]
}
EOF
}

# IAM Policy for Lambda
resource "aws_iam_policy" "lambda_policy" {
  name = "weather_lambda_policy"
  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:PutObject",
        "s3:GetObject"
      ],
      "Resource": [
        "${aws_s3_bucket.raw_data_bucket.arn}/*",
        "${aws_s3_bucket.processed_data_bucket.arn}/*"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "secretsmanager:GetSecretValue"
      ],
      "Resource": "${aws_secretsmanager_secret.weather_api_secret.arn}"
    },
    {
      "Effect": "Allow",
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Resource": "arn:aws:logs:*:*:*"
    }
  ]
}
EOF
}

# Attach policy to role
resource "aws_iam_role_policy_attachment" "lambda_policy_attachment" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.lambda_policy.arn
}

# Create Lambda Function
resource "aws_lambda_function" "weather_lambda" {
  function_name = "WeatherDataProcessor"
  role          = aws_iam_role.lambda_role.arn
  handler       = "lambda_function.lambda_handler"
  runtime       = "python3.9"

  filename         = "lambda_package.zip" 
  source_code_hash = filebase64sha256("lambda_package.zip")

  environment {
    variables = {
      RAW_BUCKET       = aws_s3_bucket.raw_data_bucket.bucket
      PROCESSED_BUCKET = aws_s3_bucket.processed_data_bucket.bucket
    }
  }
}

# EventBridge Rule to Trigger Lambda
resource "aws_cloudwatch_event_rule" "daily_trigger" {
  name                = "DailyWeatherTrigger"
  schedule_expression = "rate(1 day)"
}

resource "aws_cloudwatch_event_target" "lambda_target" {
  rule      = aws_cloudwatch_event_rule.daily_trigger.name
  arn       = aws_lambda_function.weather_lambda.arn
}

# Grant EventBridge permission to invoke Lambda
resource "aws_lambda_permission" "allow_eventbridge" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.weather_lambda.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.daily_trigger.arn
}
