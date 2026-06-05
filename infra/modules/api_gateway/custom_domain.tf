# ─── Custom Domain Name (Situação A — DNS externo ao Route 53) ───────────────
#
# Fluxo de configuração após o terraform apply:
#
#  1. O ACM gera um registro CNAME para validar a propriedade do domínio.
#     O Terraform exibe esse valor no output `acm_validation_cname`.
#     → Crie esse CNAME no painel DNS do OVH e aguarde a validação (~5 min).
#
#  2. O API Gateway gera um endpoint regional próprio.
#     O Terraform exibe esse valor no output `custom_domain_target`.
#     → Crie um CNAME no OVH apontando o seu domínio para esse endpoint.
#
#  Resumo dos registros a criar no OVH:
#
#  Tipo  | Nome                              | Valor
#  ───── | ──────────────────────────────── | ──────────────────────────────────
#  CNAME | _acme-challenge.andy-api.aws     | <acm_validation_cname>
#  CNAME | andy-api.aws                     | <custom_domain_target>
#
# Este bloco só é criado quando var.custom_domain != "".
# Para desabilitar, deixe custom_domain vazio no terraform.tfvars.

locals {
  enable_custom_domain = var.custom_domain != ""
}

# ─── Certificado TLS (ACM) ────────────────────────────────────────────────────

resource "aws_acm_certificate" "andy_api" {
  count = local.enable_custom_domain ? 1 : 0

  domain_name       = var.custom_domain
  validation_method = "DNS"

  lifecycle {
    # Cria o novo certificado antes de destruir o antigo para evitar downtime
    create_before_destroy = true
  }
}

# Aguarda a validação DNS do certificado.
# O Terraform fica em espera até que o CNAME de validação seja criado no OVH
# e a AWS confirme a propriedade do domínio.
resource "aws_acm_certificate_validation" "andy_api" {
  count = local.enable_custom_domain ? 1 : 0

  certificate_arn = aws_acm_certificate.andy_api[0].arn

  # Não passamos validation_record_fqdns porque o DNS é externo (OVH).
  # O Terraform vai aguardar polling até o ACM reportar status ISSUED.
  timeouts {
    create = "10m"
  }
}

# ─── Custom Domain Name no API Gateway ───────────────────────────────────────

resource "aws_api_gateway_domain_name" "andy_api" {
  count = local.enable_custom_domain ? 1 : 0

  domain_name              = var.custom_domain
  regional_certificate_arn = aws_acm_certificate_validation.andy_api[0].certificate_arn

  endpoint_configuration {
    types = ["REGIONAL"]
  }
}

# ─── Mapeamento do custom domain para o stage v1 ─────────────────────────────

resource "aws_api_gateway_base_path_mapping" "andy_api" {
  count = local.enable_custom_domain ? 1 : 0

  api_id      = aws_api_gateway_rest_api.andy.id
  stage_name  = aws_api_gateway_stage.andy.stage_name
  domain_name = aws_api_gateway_domain_name.andy_api[0].domain_name

  # base_path vazio → o domínio raiz mapeia direto para o stage
  # ex: andy-api.aws.our-cluster.ovh/temperature (sem prefixo /v1/)
  base_path = ""
}
