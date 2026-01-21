# 🛡️ PLANO DE TESTE DE SEGURANÇA (Isolamento de Academias)

Agora que a migração `id_academia` foi concluída, é crucial validar se o isolamento de dados está funcionando.

## 1. Cenário de Teste

Você precisa de:
- **Admin A** (Academia A)
- **Admin B** (Academia B) - *Crie uma nova conta se não tiver*

## 2. O que testar

### ✅ Teste 1: Isolamento de Alunos
1. Faça login como **Admin A**.
2. Crie um aluno "Aluno A".
3. Faça logout e login como **Admin B**.
4. Vá em "Alunos".
5. **Resultado Esperado:** Você **NÃO** deve ver o "Aluno A" na lista.

### ✅ Teste 2: Isolamento de Personals/Nutricionistas
1. Com **Admin A**, crie um Personal "Personal A".
2. Com **Admin B**, tente ver a lista de personals.
3. **Resultado Esperado:** "Personal A" não deve aparecer.

### ✅ Teste 3: Dietas e Treinos
1. Faça login com "Personal A" (da Academia A).
2. Crie um treino para "Aluno A".
3. Faça login com um Personal da Academia B (crie se necessário).
4. **Resultado Esperado:** O Personal B não deve ver o treino, nem o aluno A.

### ✅ Teste 4: Avisos
1. **Admin A** cria um aviso "Festa da Academia A".
2. **Admin B** e seus alunos logados.
3. **Resultado Esperado:** Eles NÃO devem ver o aviso da festa.

## 3. Em caso de falha

Se você ver dados cruzados:
1. Verifique se executou o script SQL `CRITICAL_CNPJ_TO_ID_ACADEMIA.sql`.
2. Verifique se o Admin B não foi criado "dentro" da Academia A por engano (mesmo `id_academia`).
3. Me chame imediatamente!
