# Segurança

## Controles aplicados

| Camada | Controle | Onde |
|---|---|---|
| Rede | Banco em sub-rede privada, sem rota para a internet | `network.tf` |
| Rede | Security Groups referenciando outros SGs, uma porta por regra | `security_groups.tf` |
| Rede | Saída da EC2 limitada a 443 (APIs da AWS) e 5432 (banco) | `security_groups.tf` |
| Rede | VPC Flow Logs do tráfego rejeitado | `monitoring.tf` |
| Acesso | Sem SSH: Session Manager, com cada sessão auditada no CloudTrail | `iam.tf`, `compute.tf` |
| Acesso | GitHub Actions via OIDC, restrito a este repositório | `github_oidc.tf` |
| Identidade | Políticas IAM com ARNs específicos | `iam.tf`, `github_oidc.tf` |
| Instância | IMDSv2 obrigatório, disco criptografado | `compute.tf` |
| Dados | RDS criptografado, TLS obrigatório, backups | `database.tf` |
| Segredos | Senha gerada pelo Terraform e salva como SecureString | `database.tf` |
| State | Bucket versionado, criptografado, privado e só HTTPS | `bootstrap/main.tf` |
| Imagem | Usuário não-root no container, *scan* no push do ECR | `app/Dockerfile`, `ecr.tf` |
| Código | Checkov a cada PR | `.github/workflows/terraform.yml` |

## Exceções aceitas no Checkov

Um laboratório precisa ser barato. Cada regra ignorada em `.checkov.yaml` tem um motivo:

| Regra | O que pede | Por que foi ignorada |
|---|---|---|
| CKV_AWS_158, CKV_AWS_136, CKV_AWS_337 | Chave KMS gerenciada pelo cliente (CMK) em logs, ECR e SSM | Cada CMK custa cerca de US$ 1/mês; as chaves gerenciadas pela AWS já criptografam |
| CKV_AWS_26 | SNS criptografado | Alarmes do CloudWatch não publicam em tópicos com a chave gerenciada `aws/sns` |
| CKV_AWS_338 | Logs guardados por 1 ano | 14 dias (app) e 7 dias (flow logs) bastam aqui |
| CKV_AWS_126, CKV_AWS_118, CKV_AWS_353 | Monitoramento detalhado e Performance Insights | Recursos pagos; as métricas padrão de 5 minutos atendem |
| CKV2_AWS_30 | Log de todas as queries do PostgreSQL | Muito volume para pouco ganho neste projeto |
| CKV_AWS_130, CKV_AWS_260 | Sem IP público e sem porta 80 aberta | A API é pública por definição; `allowed_http_cidrs` restringe por IP |
| CKV_AWS_51 | Tags imutáveis no ECR | A tag `latest` é sobrescrita; a tag com SHA nunca muda e serve de rollback |
| CKV2_AWS_34 | Todo parâmetro SSM criptografado | Só a senha é segredo; host, nome do banco e usuário não são |
| CKV_AWS_394 | Fixar IDs das AZs | As AZs vêm da região e são limitadas por `az_count` |
| CKV_AWS_18, CKV_AWS_144, CKV_AWS_145, CKV2_AWS_62 | Logs de acesso, replicação, KMS e eventos no bucket do state | Exagero para um arquivo de state de laboratório |

## O que mudaria em produção

- HTTPS com certificado do ACM num Application Load Balancer, sem porta 80 direta na instância
- CMKs no KMS com rotação anual
- RDS Multi-AZ, Performance Insights e retenção maior de backups
- Senha do banco gerenciada pelo Secrets Manager com rotação automática, ou autenticação IAM (já habilitada no RDS)
- Role de `terraform apply` separada da role de `plan`, aprovada por ambiente protegido no GitHub
