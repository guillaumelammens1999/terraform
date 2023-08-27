output "endpoint_DB" {
  value = split(":", aws_db_instance.default.endpoint)[0]
}