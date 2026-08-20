# Exemplo — ecr

Cria os cinco repositórios do ToggleMaster sob o namespace `togglemaster`, com tags imutáveis, scan no push e lifecycle policy.

## Uso

```bash
cp terraform.tfvars.example terraform.tfvars
terraform init
terraform plan
terraform apply
```

## Publicando uma imagem

```bash
REGISTRY=$(terraform output -raw registry_url)
REPO=$(terraform output -json repository_urls | jq -r '."auth-service"')
TAG="v1.0.0-$(git rev-parse --short HEAD)"

aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin "$REGISTRY"
docker build -t "$REPO:$TAG" .
docker push "$REPO:$TAG"
```

## Lendo do Parameter Store na esteira

Com `create_ssm_parameters = true`, a pipeline resolve o destino sem tocar no tfstate:

```bash
REPO=$(aws ssm get-parameter --name /ecr/auth-service/repository-url --query Parameter.Value --output text)
```

## Limpeza

```bash
terraform destroy
```

> Repositórios com imagens não são destruídos. Esvazie-os antes, ou aplique com `force_delete = true` — o que só faz sentido em ambiente descartável.
