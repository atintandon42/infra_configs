output "lambda_function_name" {
  value = aws_lambda_function.weather_lambda.function_name
}

output "s3_raw_bucket" {
  value = aws_s3_bucket.raw_data_bucket.bucket
}

output "s3_processed_bucket" {
  value = aws_s3_bucket.processed_data_bucket.bucket
}

output "secret_name" {
  value = aws_secretsmanager_secret.weather_api_secret.name
}
