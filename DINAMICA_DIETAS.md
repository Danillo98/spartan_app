# Dinâmica de Gerenciamento de Dietas

## Como Funciona a Estrutura de Dietas

### 1. **Dieta** (Nível Principal)
Uma dieta contém:
- Nome (ex: "Dieta para Ganho de Massa")
- Descrição
- Aluno atribuído
- Objetivo (Perda de Peso, Ganho de Massa, etc.)
- Calorias totais
- Datas de início e término

### 2. **Dias da Dieta** (Nível Intermediário)
Cada dieta pode ter vários DIAS. Por exemplo:
- **Dia 1** - Segunda-feira
- **Dia 2** - Terça-feira
- **Dia 3** - Quarta-feira
- etc.

Cada dia contém:
- Número do dia
- Nome do dia
- Total de calorias do dia

### 3. **Refeições** (Nível Detalhado)
Cada DIA pode ter várias REFEIÇÕES. Por exemplo, no Dia 1:
- **Café da Manhã** (07:00) - 500 kcal
- **Lanche da Manhã** (10:00) - 200 kcal
- **Almoço** (12:00) - 800 kcal
- **Lanche da Tarde** (16:00) - 300 kcal
- **Jantar** (19:00) - 600 kcal

Cada refeição contém:
- Nome da refeição
- Horário
- Alimentos
- Calorias
- Macros (Proteínas, Carboidratos, Gorduras)
- Instruções

## Fluxo de Criação Atual

### Passo 1: Criar a Dieta
Na tela de criação, você define as informações básicas da dieta.

### Passo 2: Adicionar Dias
Depois de criar a dieta, você precisa adicionar os dias:
- Clique no botão "Adicionar Dia" ou no botão flutuante "+"
- Informe o número do dia (1, 2, 3...)
- Informe o nome do dia (Segunda, Terça, Dia 1, etc.)

### Passo 3: Adicionar Refeições aos Dias
Depois de adicionar um dia, você pode adicionar refeições a ele:
- Expanda o dia na lista
- Clique em "Adicionar Refeição"
- Preencha os detalhes da refeição

## Sugestão de Melhoria

Você gostaria que eu criasse uma tela mais completa onde você possa:
1. Adicionar o dia
2. E já adicionar as refeições desse dia
Tudo em uma única tela?

Ou prefere manter separado mas melhorar a navegação?

## Exemplo de Uso

**Cenário:** Criar uma dieta de 7 dias para ganho de massa

1. Crie a dieta com nome "Dieta Hipertrofia João"
2. Adicione 7 dias (Dia 1 a Dia 7)
3. Para cada dia, adicione 5-6 refeições
4. O aluno verá a dieta completa com todos os dias e refeições

**Resultado:** Uma dieta estruturada e organizada por dias da semana!
