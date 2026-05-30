# ─── Andy Lambda Role ────────────────────────────────────────────────────────

resource "aws_iam_role" "andy_lambda" {
  name = "${var.project_name}-andy-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "andy_basic_execution" {
  role       = aws_iam_role.andy_lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "andy_sns_publish" {
  name = "andy-sns-publish"
  role = aws_iam_role.andy_lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = "sns:Publish"
        Resource = var.sns_topic_arn
      }
    ]
  })
}

# ─── Hamm Lambda Role ────────────────────────────────────────────────────────

resource "aws_iam_role" "hamm_lambda" {
  name = "${var.project_name}-hamm-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  # Tag usada para autorização na policy do S3 Tables bucket
  tags = {
    Project = var.project_name
  }
}

resource "aws_iam_role_policy_attachment" "hamm_basic_execution" {
  role       = aws_iam_role.hamm_lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "hamm_sqs_consume" {
  name = "hamm-sqs-consume"
  role = aws_iam_role.hamm_lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:DeleteMessageBatch",
          "sqs:GetQueueAttributes",
          "sqs:GetQueueUrl"
        ]
        Resource = var.sqs_queue_arn
      }
    ]
  })
}

# ─── Hamm S3 Tables permissions (Iceberg) ────────────────────────────────────

resource "aws_iam_role_policy" "hamm_s3_tables" {
  name = "hamm-s3-tables-write"
  role = aws_iam_role.hamm_lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "S3TablesAccess"
        Effect = "Allow"
        Action = [
          "s3tables:GetTable",
          "s3tables:GetTableMetadata",
          "s3tables:GetTableData",
          "s3tables:PutTableData",
          "s3tables:UpdateTableMetadata",
          "s3tables:CreateTable",
          "s3tables:GetNamespace",
          "s3tables:GetTableBucket"
        ]
        Resource = [
          var.s3_tables_bucket_arn,
          "${var.s3_tables_bucket_arn}/*"
        ]
      },
      {
        Sid    = "S3TablesUnderlyingStorage"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = [
          # S3 Tables usa um bucket gerenciado internamente
          "arn:aws:s3:::*--table--*",
          "arn:aws:s3:::*--table--*/*"
        ]
      }
    ]
  })
}

# ─── Athena Role (para uso via console/SDK) ───────────────────────────────────

resource "aws_iam_role" "athena" {
  name = "${var.project_name}-athena-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "athena.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  # Tag usada para autorização na policy do S3 Tables bucket
  tags = {
    Project = var.project_name
  }
}

resource "aws_iam_role_policy" "athena_access" {
  name = "athena-access"
  role = aws_iam_role.athena.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "S3TablesRead"
        Effect = "Allow"
        Action = [
          "s3tables:GetTable",
          "s3tables:GetTableMetadata",
          "s3tables:GetTableData",
          "s3tables:GetNamespace",
          "s3tables:GetTableBucket",
          "s3tables:ListTables",
          "s3tables:ListNamespaces"
        ]
        Resource = [
          var.s3_tables_bucket_arn,
          "${var.s3_tables_bucket_arn}/*"
        ]
      },
      {
        Sid    = "S3TablesUnderlyingStorageRead"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          "arn:aws:s3:::*--table--*",
          "arn:aws:s3:::*--table--*/*"
        ]
      },
      {
        Sid    = "AthenaResultsBucket"
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          var.athena_bucket,
          "${var.athena_bucket}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "glue:GetDatabase",
          "glue:GetTable",
          "glue:GetPartitions",
          "glue:GetTables"
        ]
        Resource = "*"
      }
    ]
  })
}
