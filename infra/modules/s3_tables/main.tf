# ─── S3 Table Bucket (Iceberg nativo) ─────────────────────────────────────────
#
# S3 Tables é um tipo especial de bucket otimizado para formatos de tabela como
# Apache Iceberg. Oferece:
# - Compaction automático (sem Glue Jobs)
# - 3x melhor performance em queries
# - 10x mais transações por segundo
# - Integração nativa com Athena, Spark, Redshift
#
# Documentação: https://docs.aws.amazon.com/AmazonS3/latest/userguide/s3-tables.html

# ─── Table Bucket ─────────────────────────────────────────────────────────────

resource "aws_s3tables_table_bucket" "data_lake" {
  name = "${var.project_name}-data-lake"

  # Maintenance é automático no S3 Tables
  # maintenance_configuration {
  #   iceberg_unreferenced_file_removal {
  #     status = "enabled"
  #     settings {
  #       non_current_days = 7
  #       unreferenced_days = 3
  #     }
  #   }
  # }
}

# ─── Namespace (equivalente a database/schema) ───────────────────────────────

resource "aws_s3tables_namespace" "raw" {
  namespace        = "raw"
  table_bucket_arn = aws_s3tables_table_bucket.data_lake.arn
}

# ─── Tabela Iceberg para sensor readings ─────────────────────────────────────

resource "aws_s3tables_table" "sensor_readings" {
  name             = "sensor_readings"
  namespace        = aws_s3tables_namespace.raw.namespace
  table_bucket_arn = aws_s3tables_table_bucket.data_lake.arn
  format           = "ICEBERG"

  # O schema é gerenciado pelo PyIceberg na Lambda Hamm
  # S3 Tables cria a estrutura Iceberg automaticamente
}

# ─── Table Bucket Policy ─────────────────────────────────────────────────────
# Nota: As permissões são gerenciadas via IAM roles nos módulos iam
# A policy do bucket permite acesso para roles do projeto via condição de tag

resource "aws_s3tables_table_bucket_policy" "data_lake" {
  table_bucket_arn = aws_s3tables_table_bucket.data_lake.arn

  resource_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowProjectRolesAccess"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${var.aws_account_id}:root"
        }
        Action = [
          "s3tables:*"
        ]
        Resource = [
          aws_s3tables_table_bucket.data_lake.arn,
          "${aws_s3tables_table_bucket.data_lake.arn}/*"
        ]
        Condition = {
          StringEquals = {
            "aws:PrincipalTag/Project" = var.project_name
          }
        }
      },
      {
        Sid    = "AllowAthenaAccess"
        Effect = "Allow"
        Principal = {
          Service = "athena.amazonaws.com"
        }
        Action = [
          "s3tables:GetTable",
          "s3tables:GetTableMetadata",
          "s3tables:GetTableData"
        ]
        Resource = [
          aws_s3tables_table_bucket.data_lake.arn,
          "${aws_s3tables_table_bucket.data_lake.arn}/*"
        ]
        Condition = {
          StringEquals = {
            "aws:SourceAccount" = var.aws_account_id
          }
        }
      }
    ]
  })
}
