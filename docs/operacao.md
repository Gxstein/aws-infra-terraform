# Operação (runbook)

Todos os comandos rodam a partir da pasta `terraform/`.

## Ver o que está no ar

```bash
terraform output
curl "$(terraform output -raw api_url)/health"
```

## Abrir um shell na EC2 (sem SSH)

```bash
$(terraform output -raw ssm_session_command)

# dentro da instância
sudo docker ps
sudo docker logs --tail 50 api
cat /etc/api-image-tag          # versão que está rodando
```

## Deploy manual de uma versão

O pipeline faz isso sozinho. Para fazer na mão:

```bash
aws ssm send-command \
  --instance-ids "$(terraform output -raw instance_id)" \
  --document-name AWS-RunShellScript \
  --parameters "commands=['/usr/local/bin/deploy-app.sh abc1234']"
```

## Rollback

Cada build envia a imagem com a tag do SHA curto do commit. Para voltar, rode o deploy acima com a tag da versão anterior. As tags disponíveis aparecem com:

```bash
aws ecr describe-images \
  --repository-name "$(terraform output -raw ecr_repository_name)" \
  --query 'reverse(sort_by(imageDetails,&imagePushedAt))[].imageTags' --output table
```

## Logs

```bash
# logs da API
aws logs tail /aws-infra-dev/app --follow

# tráfego bloqueado pela VPC
aws logs tail /aws-infra-dev/vpc-flow-logs --since 1h
```

## Alarmes

| Alarme | Dispara quando | O que fazer |
|---|---|---|
| `ec2-cpu-high` | CPU da EC2 acima de 80% por 10 min | Ver `docker stats`; considerar instância maior ou ALB + Auto Scaling |
| `ec2-system-check-failed` | Falha no hardware da AWS | A recuperação é automática; conferir se a API voltou |
| `rds-cpu-high` | CPU do banco acima de 80% por 10 min | Procurar queries lentas; considerar instância maior |
| `rds-free-storage-low` | Menos de 2 GB livres | O armazenamento cresce sozinho até 50 GB; revisar `max_allocated_storage` |
| Budget 80% / previsão 100% | Custo do mês alto | Destruir o que não está em uso |

## Trocar a senha do banco

```bash
terraform apply -replace=random_password.db
# depois, refazer o deploy para a API ler a senha nova
```

## Destruir tudo

```bash
terraform destroy
```

O bucket do state (`bootstrap/`) tem `prevent_destroy` e continua existindo. Para apagar também, remova esse bloco, esvazie o bucket e rode `terraform destroy` dentro de `bootstrap/`.

## Problemas comuns

| Sintoma | Causa provável | Solução |
|---|---|---|
| `/health` responde `database: down` | RDS ainda subindo ou senha trocada | Esperar alguns minutos ou refazer o deploy |
| Deploy falha com `pull access denied` | Primeira imagem ainda não foi enviada | Rodar o workflow `app` |
| `start-session` falha | Falta o plugin do Session Manager | Instalar o *session-manager-plugin* da AWS |
| Plan no GitHub falha com `AccessDenied` | Variável `AWS_ROLE_ARN` ou `TF_STATE_BUCKET` errada | Conferir com `terraform output` |
