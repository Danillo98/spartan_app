# PONTO DE RESTAURAÇÃO: MUSTANG
Data: 2026-01-17
Status: SISTEMA DE DIETAS FUNCIONAL PARA NUTRICIONISTAS

## Estado Atual
Este ponto marca a conclusão do sistema de criação de dietas para nutricionistas, incluindo a correção de permissões RLS e a adição de campos essenciais.

### Funcionalidades Implementadas
1.  **Listagem de Alunos para Nutricionistas:**
    - Criada RPC `get_students_for_staff` que permite nutricionistas e personals listarem alunos da mesma academia.
    - Implementado `UserService.getStudentsForStaff()` com normalização de campos (nome→name, telefone→phone).
    - Correção de nomes de colunas no SQL (nome, telefone em vez de name, phone).

2.  **Criação de Dietas:**
    - Adicionadas colunas `description` e `end_date` à tabela `diets`.
    - Corrigido `DietService.createDiet` para usar os campos corretos.
    - Tela de criação de dieta funcional com seleção de alunos.

3.  **Melhorias de UX:**
    - Removidos logs de debug desnecessários.
    - Interface preparada para modernização visual.

## Arquivos Chave
- `CRIAR_RPC_GET_STUDENTS.sql`: RPC para listar alunos da mesma academia.
- `ADICIONAR_COLUNAS_DIETS.sql`: Script para adicionar description e end_date.
- `lib/services/user_service.dart`: Método getStudentsForStaff.
- `lib/services/diet_service.dart`: Criação de dietas corrigida.
- `lib/screens/nutritionist/create_diet_screen.dart`: Tela de criação de dietas.

## Próximos Passos
1. Executar `ADICIONAR_COLUNAS_DIETS.sql` no Supabase.
2. Modernizar visualmente a tela de criação de dietas.
3. Testar fluxo completo de criação de dietas.

## Como Restaurar
Certifique-se de que os scripts SQL listados foram executados no banco de dados.
