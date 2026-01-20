# PONTO DE RESTAURAÇÃO: DOG
Data: 2026-01-17
Status: CONFIRMAÇÃO E RESET DE SENHA (ADMIN) FUNCIONANDO.

## Estado Atual
- Fluxo de confirmação de email para Admin validado e funcional.
- Fluxo de "Esqueci a Senha" ajustado com RPC `check_email_exists` para validar existência e enviar email.
- Banco de dados estabilizado (tabelas separadas, logs reconstruídos).

## Objetivo
- Estender o fluxo de confirmação de email (via token/link) para Nutricionistas, Personals e Alunos.
- Garantir que a opção "Esqueci minha senha" funcione para todos os perfis na tela de login.
