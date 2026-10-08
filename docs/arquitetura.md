# Arquitetura

## Rede

| Item | Valor | Motivo |
|---|---|---|
| VPC | `10.0.0.0/16` | 65 mil endereços, espaço de sobra para crescer |
| Sub-redes públicas | `10.0.0.0/24`, `10.0.1.0/24` | Uma por AZ; rota `0.0.0.0/0` para o Internet Gateway |
| Sub-redes privadas | `10.0.10.0/24`, `10.0.11.0/24` | Uma por AZ; só a rota local, sem acesso à internet |
| Zonas de disponibilidade | 2 (configurável com `az_count`) | O RDS exige sub-redes em pelo menos duas AZs |

Os blocos são calculados com `cidrsubnet(var.vpc_cidr, 8, i)`. Trocar o CIDR da VPC recalcula tudo sozinho.

O banco fica nas sub-redes privadas e não tem IP público. Mesmo que alguém abrisse o Security Group por engano, não existe rota da internet até ele.

O *security group default* da VPC é "travado" (sem regras) para que nenhum recurso o use sem querer.

## Fluxo de uma requisição

1. O cliente chama `http://<dns-publico-da-ec2>/tasks`.
2. O Internet Gateway entrega o pacote na sub-rede pública; o Security Group `app` aceita a porta 80.
3. O Docker encaminha a porta 80 do host para a porta 8000 do container (Uvicorn + FastAPI).
4. A API abre conexão TLS com o RDS na porta 5432; o Security Group `db` só aceita origem do SG `app`.
5. Os logs do container vão direto para o CloudWatch Logs (driver `awslogs`).

## Virtualização e containers

- A **EC2** é uma máquina virtual (hypervisor Nitro) com Amazon Linux 2023.
- A API roda num **container Docker**, que isola o processo e as dependências. A mesma imagem roda no `docker compose` local e na AWS.
- A imagem roda como usuário sem privilégios (`uid 10001`) e tem `HEALTHCHECK`.

## Como a EC2 recebe configuração e segredos

```
Terraform ──► SSM Parameter Store
               /aws-infra-dev/db/host      (String)
               /aws-infra-dev/db/name      (String)
               /aws-infra-dev/db/user      (String)
               /aws-infra-dev/db/password  (SecureString, KMS)

deploy-app.sh (na EC2) ──► lê os parâmetros com a role da instância
                       ──► grava /etc/api.env (permissão 600)
                       ──► docker run --env-file /etc/api.env
```

A senha não aparece no *user data*, na imagem Docker nem no código.

## Deploy

```
push no main (app/**)
   └─► GitHub Actions
         ├─ testes (pytest + PostgreSQL em container de serviço)
         ├─ OIDC ► assume a role aws-infra-dev-github-actions
         ├─ docker build ► push no ECR (:abc1234 e :latest)
         ├─ SSM Run Command ► /usr/local/bin/deploy-app.sh abc1234
         └─ smoke test em /health
```

Nenhuma porta de administração precisa estar aberta: o agente SSM da instância busca os comandos na AWS por HTTPS.

## Resiliência

- O alarme `StatusCheckFailed_System` dispara a ação `ec2:recover`: se o hardware físico falhar, a AWS move a instância para outro host mantendo ID, IP e disco.
- O container sobe com `--restart unless-stopped`, então volta sozinho após reboot ou falha do processo.
- O RDS tem backup automático diário e armazenamento que cresce sozinho de 20 até 50 GB.
- Limite consciente: há uma única EC2. O próximo passo é ALB + Auto Scaling Group em duas AZs.
