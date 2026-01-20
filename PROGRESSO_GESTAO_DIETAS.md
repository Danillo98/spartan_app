# 🥗 SISTEMA DE GESTÃO DE DIETAS - PROGRESSO

**Data:** 2026-01-17 16:57  
**Status:** Em Desenvolvimento  
**Objetivo:** Sistema completo, limpo e intuitivo

---

## ✅ ARQUIVOS CRIADOS

### **1. `lib/services/diet_service.dart`** ✅
- CRUD completo de dietas
- CRUD de dias e refeições
- Multi-tenancy (segurança)
- Filtros por nutricionista/aluno

### **2. `lib/screens/nutritionist/diets_list_screen.dart`** ✅
**Features implementadas:**
- ✅ Lista de dietas com cards bonitos
- ✅ Estatísticas (total, ativas, pausadas, concluídas)
- ✅ Busca por nome ou aluno
- ✅ Filtros por status (todas, ativas, pausadas, concluídas)
- ✅ Pull to refresh
- ✅ FAB para criar nova dieta
- ✅ Navegação para detalhes
- ✅ Confirmação de exclusão
- ✅ Empty state quando não há dietas

### **3. `lib/widgets/diet_card.dart`** ✅
**Features implementadas:**
- ✅ Design limpo e moderno
- ✅ Badge de status (ativa, pausada, concluída)
- ✅ Informações principais (nome, aluno, calorias, objetivo)
- ✅ Datas de início e fim
- ✅ Botão de exclusão
- ✅ Tap para ver detalhes

---

## 🔜 PRÓXIMOS ARQUIVOS A CRIAR

### **4. `lib/screens/nutritionist/create_diet_screen.dart`**
**Objetivo:** Criar nova dieta de forma simples e rápida

**Features necessárias:**
- Formulário em etapas (Stepper ou PageView)
- **Etapa 1:** Informações básicas
  - Nome da dieta
  - Descrição
  - Selecionar aluno (dropdown)
  - Objetivo (dropdown: perda de peso, ganho de massa, manutenção, etc)
  - Calorias totais
  - Data início/fim
  
- **Etapa 2:** Dias da semana (opcional - pode pular)
  - Adicionar dias (Segunda, Terça, etc)
  - Calorias por dia
  
- **Etapa 3:** Refeições (opcional - pode adicionar depois)
  - Adicionar refeições rápidas
  
- **Etapa 4:** Revisão e salvar

**Design:**
- Stepper horizontal no topo
- Botões "Voltar" e "Próximo"
- Validação em tempo real
- Loading ao salvar

---

### **5. `lib/screens/nutritionist/diet_details_screen.dart`**
**Objetivo:** Ver e editar dieta completa

**Features necessárias:**
- Header com informações principais
- Tabs para cada dia da semana
- Lista de refeições por dia
- Botões de ação:
  - Editar informações
  - Adicionar dia
  - Adicionar refeição
  - Pausar/Ativar dieta
  - Compartilhar com aluno
  - Excluir dieta

**Design:**
- AppBar com gradiente
- TabBar para dias
- Cards expansíveis para refeições
- FAB para ações rápidas

---

### **6. `lib/widgets/meal_card.dart`**
**Objetivo:** Card de refeição reutilizável

**Features necessárias:**
- Nome da refeição
- Horário
- Alimentos
- Macros (calorias, proteína, carbo, gordura)
- Instruções
- Botões de editar/excluir

---

### **7. `lib/screens/nutritionist/add_meal_screen.dart`**
**Objetivo:** Adicionar/editar refeição

**Features necessárias:**
- Formulário simples
- Campos:
  - Nome da refeição
  - Horário
  - Alimentos (textarea)
  - Calorias
  - Proteína (g)
  - Carboidratos (g)
  - Gorduras (g)
  - Instruções (textarea)
- Botão salvar

---

## 🎯 PRIORIDADE DE IMPLEMENTAÇÃO

1. **ALTA:** `create_diet_screen.dart` - Criar dietas
2. **ALTA:** `diet_details_screen.dart` - Ver/editar dietas
3. **MÉDIA:** `meal_card.dart` - Widget de refeição
4. **MÉDIA:** `add_meal_screen.dart` - Adicionar refeições
5. **BAIXA:** Melhorias e refinamentos

---

## 💡 DECISÕES DE DESIGN

### **Princípios:**
1. **Simplicidade:** Menos cliques, mais produtividade
2. **Clareza:** Informações importantes sempre visíveis
3. **Rapidez:** Formulários curtos e objetivos
4. **Flexibilidade:** Pode criar dieta básica e adicionar detalhes depois

### **Fluxo Simplificado:**
```
Criar Dieta Rápida:
1. Nome + Aluno + Objetivo + Calorias → SALVAR
   (Pode adicionar dias e refeições depois)

Criar Dieta Completa:
1. Informações básicas
2. Adicionar dias
3. Adicionar refeições
4. Revisar e salvar
```

### **Cores (Nutricionista):**
```dart
Primary: Color(0xFF2A9D8F)  // Verde água
Light: Color(0xFFE8F5F3)    // Verde claro
Dark: Color(0xFF1F7A6E)     // Verde escuro
Accent: Color(0xFF4CAF50)   // Verde vibrante
```

---

## 📱 INTEGRAÇÃO COM DASHBOARD

Adicionar no `nutritionist_dashboard.dart`:

```dart
// Botão/Card para acessar dietas
InkWell(
  onTap: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const DietsListScreen(),
      ),
    );
  },
  child: // Card de Dietas
)
```

---

## 🧪 TESTES NECESSÁRIOS

1. ✅ Criar dieta básica (só informações principais)
2. ✅ Criar dieta completa (com dias e refeições)
3. ✅ Editar dieta existente
4. ✅ Adicionar dia a dieta
5. ✅ Adicionar refeição a dia
6. ✅ Editar refeição
7. ✅ Excluir refeição
8. ✅ Excluir dieta
9. ✅ Buscar dietas
10. ✅ Filtrar por status

---

## 📊 ESTRUTURA DO BANCO (LEMBRETE)

```
diets
├── id
├── name
├── description
├── student_id (FK)
├── nutritionist_id (FK)
├── created_by_admin_id (FK)
├── goal
├── total_calories
├── start_date
├── end_date
└── status

diet_days
├── id
├── diet_id (FK)
├── day_name
├── day_number
└── total_calories

meals
├── id
├── diet_day_id (FK)
├── meal_time
├── meal_name
├── foods
├── calories
├── protein
├── carbs
├── fats
└── instructions
```

---

## 🚀 PRÓXIMO PASSO

Vou criar agora:
1. **`create_diet_screen.dart`** - Formulário de criação
2. **`diet_details_screen.dart`** - Detalhes e edição

Esses são os arquivos mais importantes para ter o sistema funcionando!

---

**Status:** 3/7 arquivos criados (43%)  
**Próximo:** Criar telas de criação e detalhes
