#!/bin/bash
# Executado automaticamente pelo LocalStack após o boot.
# Cria os recursos AWS necessários para desenvolvimento local.

set -euo pipefail

REGION="us-east-1"
ENDPOINT="http://localhost:4566"
PROJECT="toy-data-project"
TOPIC_NAME="${PROJECT}-temperature"
QUEUE_NAME="${PROJECT}-temperature-queue"
DLQ_NAME="${PROJECT}-temperature-dlq"
BUCKET="${PROJECT}-data-lake"

echo ">>> Creating S3 bucket: ${BUCKET}"
awslocal s3 mb "s3://${BUCKET}" --region "${REGION}"

echo ">>> Creating SQS DLQ: ${DLQ_NAME}"
DLQ_URL=$(awslocal sqs create-queue \
  --queue-name "${DLQ_NAME}" \
  --attributes MessageRetentionPeriod=1209600 \
  --query QueueUrl --output text)

DLQ_ARN=$(awslocal sqs get-queue-attributes \
  --queue-url "${DLQ_URL}" \
  --attribute-names QueueArn \
  --query Attributes.QueueArn --output text)

echo ">>> Creating SQS Queue: ${QUEUE_NAME}"
QUEUE_URL=$(awslocal sqs create-queue \
  --queue-name "${QUEUE_NAME}" \
  --attributes \
    VisibilityTimeout=360 \
    MessageRetentionPeriod=345600 \
    RedrivePolicy="{\"deadLetterTargetArn\":\"${DLQ_ARN}\",\"maxReceiveCount\":\"3\"}" \
  --query QueueUrl --output text)

QUEUE_ARN=$(awslocal sqs get-queue-attributes \
  --queue-url "${QUEUE_URL}" \
  --attribute-names QueueArn \
  --query Attributes.QueueArn --output text)

echo ">>> Creating SNS Topic: ${TOPIC_NAME}"
TOPIC_ARN=$(awslocal sns create-topic \
  --name "${TOPIC_NAME}" \
  --query TopicArn --output text)

echo ">>> Subscribing SQS to SNS (raw delivery)"
awslocal sns subscribe \
  --topic-arn "${TOPIC_ARN}" \
  --protocol sqs \
  --notification-endpoint "${QUEUE_ARN}" \
  --attributes RawMessageDelivery=true

echo ""
echo "✓ LocalStack resources ready"
echo "  SNS Topic ARN : ${TOPIC_ARN}"
echo "  SQS Queue URL : ${QUEUE_URL}"
echo "  SQS DLQ URL   : ${DLQ_URL}"
echo "  S3 Bucket     : s3://${BUCKET}"
