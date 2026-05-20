# lambdas

Código das funções Lambda do toy-data-project.

Cada função vive em sua própria pasta e pode ser desenvolvida e testada
localmente de forma independente, sem precisar do Terraform ou da AWS.

## Estrutura

```
lambdas/
├── andy/
│   ├── handler.py          # Entry point da Lambda
│   ├── requirements.txt    # Dependências de produção
│   └── tests/
│       └── test_handler.py
└── hamm/
    ├── handler.py          # Entry point da Lambda
    ├── requirements.txt    # Dependências de produção
    └── tests/
        └── test_handler.py
```

## Rodando localmente

```bash
# Criar e ativar virtualenv (faça isso uma vez por função)
python -m venv lambdas/andy/.venv
source lambdas/andy/.venv/bin/activate
pip install -r lambdas/andy/requirements.txt

# Rodar os testes
pytest lambdas/andy/tests/

# Ou testar a função diretamente no Python REPL
python -c "
import json
from lambdas.andy.handler import lambda_handler

event = {
    'httpMethod': 'POST',
    'path': '/temperature',
    'body': json.dumps({
        'sensor_id': 'test',
        'temperature': 25.0,
        'humidity': 60.0,
        'heat_index': 28.0
    })
}
print(lambda_handler(event, None))
"
```

## Relação com o Terraform

O Terraform em `infra/` referencia esta pasta via `lambdas_source_dir`
e empacota cada função em um `.zip` automaticamente no `terraform apply`.
Não é necessário nenhum passo manual de build.
