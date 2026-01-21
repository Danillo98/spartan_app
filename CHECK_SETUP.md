# 🚀 Guia de Correção e Validação

Realizamos ajustes críticos no banco de dados para corrigir os erros de "Tabela não encontrada" e "Coluna não existe". Siga esta ordem ESTRITA para aplicar as correções.

## 1. 🛠️ Corrigir Banco de Dados (Ordem Obrigatória)

No **Supabase SQL Editor**, execute os scripts na seguinte ordem:

### Passo A: Corrigir Estrutura e Erros
Abra e execute o arquivo: `supabase/migrations/FIX_NULL_CNPJ_ERRORS.sql`

**O que isso faz?**
- Corrige o nome da tabela que estava errado (`training_sheets` -> `workouts`).
- Adiciona a coluna `id_academia` que faltava em `financial_transactions`.
- Remove a obrigatoriedade do `cnpj_academia` antigo para evitar erros de inserção.

### Passo B: Melhorar Performance
Abra e execute o arquivo: `supabase/migrations/PERFORMANCE_INDEXES.sql`

**O que isso faz?**
- Cria índices para acelerar o carregamento de dados em todas as tabelas.
- *Nota: Só funcionará após executar o Passo A com sucesso.*

---

## 2. 🧪 O que testar agora?

Após rodar os scripts acima:

1.  **Personal Trainer - Nova Ficha**:
    - Vá em "Fichas" -> "Nova Ficha".
    - Verifique se a lista de alunos ("Selecione um aluno") agora carrega TODOS os alunos da academia.

2.  **Performance Geral**:
    - Navegue pelo app. O carregamento de listas e o salvamento devem estar mais rápidos.

3.  **Desktop - Password Reset**:
    - Tente redefinir a senha (Deep Link).
    - Verifique se o app abre na mesma janela (sem duplicar).

## 3. ⚠️ Solução de Problemas

- Se encontrar erro **"relation 'public.training_sheets' does not exist"**:
    - Você está rodando uma versão antiga do script. Certifique-se de copiar o conteúdo ATUAL de `FIX_NULL_CNPJ_ERRORS.sql`.

- Se encontrar erro **"column 'id_academia' does not exist"**:
    - Você tentou rodar o script de performance ANTES do script de correção. Execute o Passo A primeiro.
