# Infraestrutura AWS com Terraform

Ambiente na AWS criado como código (IaC) com Terraform: rede própria em duas zonas de
disponibilidade, API REST em Docker numa EC2, PostgreSQL no RDS em sub-rede privada,
IAM com menor privilégio, monitoramento com CloudWatch e CI/CD com GitHub Actions.

> Em construção.

## Roadmap

- [ ] Bucket S3 para o state remoto
- [ ] VPC com sub-redes públicas e privadas
- [ ] Security Groups
- [ ] API em container (FastAPI + PostgreSQL)
- [ ] ECR, RDS e EC2
- [ ] CloudWatch, SNS e AWS Budgets
- [ ] CI/CD com GitHub Actions (OIDC)
