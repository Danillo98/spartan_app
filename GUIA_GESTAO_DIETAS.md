# 🥗 SISTEMA DE GESTÃO DE DIETAS - GUIA DE IMPLEMENTAÇÃO

**Data:** 2026-01-17  
**Feature:** Gestão Completa de Dietas para Nutricionistas  
**Design:** Baseado em MyFitnessPal, Yazio e melhores apps do mercado

---

## 🎨 ESQUEMA DE CORES (NUTRICIONISTA)

```dart
// Cor Principal
const nutritionistPrimary = Color(0xFF2A9D8F); // Verde água/turquesa

// Cores Complementares
const nutritionistLight = Color(0xFFE8F5F3); // Verde claro
const nutritionistDark = Color(0xFF1F7A6E); // Verde escuro
const nutritionistAccent = Color(0xFF4CAF50); // Verde vibrante

// Gradiente
final nutritionistGradient = LinearGradient(
  colors: [Color(0xFF2A9D8F), Color(0xFF4CAF50)],
);
```

---

## 📁 ARQUIVOS CRIADOS

### **1. `lib/services/diet_service.dart`** ✅
Service completo com:
- ✅ Multi-tenancy (filtro por admin)
- ✅ CRUD de dietas
- ✅ CRUD de dias da dieta
- ✅ CRUD de refeições
- ✅ Busca por nutricionista/aluno

---

## 🚀 PRÓXIMOS ARQUIVOS A CRIAR

### **2. `lib/screens/nutritionist/diets_list_screen.dart`**
Tela principal de listagem de dietas

**Features:**
- Lista de todas as dietas criadas
- Filtros (por aluno, status, data)
- Busca
- Cards com preview da dieta
- FAB para criar nova dieta
- Estatísticas (total de dietas, ativas, concluídas)

**Design:**
- AppBar com gradiente verde
- Cards com sombra e bordas arredondadas
- Ícones de status (ativa, pausada, concluída)
- Animações suaves

---

### **3. `lib/screens/nutritionist/create_diet_screen.dart`**
Tela de criação de dieta completa

**Features:**
- **Passo 1:** Informações básicas
  - Nome da dieta
  - Descrição
  - Selecionar aluno
  - Objetivo (perda de peso, ganho de massa, etc)
  - Calorias totais
  - Data início/fim
  
- **Passo 2:** Dias da semana
  - Adicionar dias (Segunda, Terça, etc)
  - Calorias por dia
  
- **Passo 3:** Refeições
  - Café da manhã
  - Lanche da manhã
  - Almoço
  - Lanche da tarde
  - Jantar
  - Ceia
  
- **Passo 4:** Revisão e confirmação

**Design:**
- Stepper horizontal
- Formulários limpos
- Validação em tempo real
- Preview da dieta antes de salvar

---

### **4. `lib/screens/nutritionist/diet_details_screen.dart`**
Tela de detalhes/edição da dieta

**Features:**
- Visualização completa da dieta
- Editar informações
- Adicionar/remover dias
- Adicionar/remover refeições
- Histórico de alterações
- Compartilhar dieta com aluno

**Design:**
- Tabs para cada dia da semana
- Cards expansíveis para refeições
- Gráficos de macros (proteína, carbo, gordura)
- Botões de ação flutuantes

---

### **5. `lib/widgets/diet_card.dart`**
Widget reutilizável para card de dieta

**Features:**
- Preview da dieta
- Status visual
- Informações principais
- Ações rápidas (editar, deletar, compartilhar)

---

### **6. `lib/widgets/meal_card.dart`**
Widget reutilizável para card de refeição

**Features:**
- Nome da refeição
- Horário
- Alimentos
- Macros (calorias, proteína, carbo, gordura)
- Instruções

---

## 🎯 FLUXO DO USUÁRIO

```
Nutricionista Login
    ↓
Dashboard
    ↓
Clica em "Dietas" → diets_list_screen.dart
    ↓
Vê lista de dietas criadas
    ↓
Opção 1: Criar Nova Dieta → create_diet_screen.dart
    ↓
    Preenche informações
    ↓
    Adiciona dias e refeições
    ↓
    Salva dieta
    ↓
    Volta para lista

Opção 2: Ver Dieta Existente → diet_details_screen.dart
    ↓
    Visualiza detalhes
    ↓
    Pode editar/deletar
```

---

## 📊 ESTRUTURA DO BANCO (REFERÊNCIA)

```sql
-- Tabela: diets
id UUID
name TEXT
description TEXT
student_id UUID (FK → users)
nutritionist_id UUID (FK → users)
created_by_admin_id UUID (FK → users)
goal TEXT
total_calories INTEGER
start_date DATE
end_date DATE
status TEXT (active, paused, completed)
created_at TIMESTAMP

-- Tabela: diet_days
id UUID
diet_id UUID (FK → diets)
day_name TEXT (Segunda, Terça, etc)
day_number INTEGER (1-7)
total_calories INTEGER
created_at TIMESTAMP

-- Tabela: meals
id UUID
diet_day_id UUID (FK → diet_days)
meal_time TEXT (08:00, 12:00, etc)
meal_name TEXT (Café da manhã, Almoço, etc)
foods TEXT (Descrição dos alimentos)
calories INTEGER
protein INTEGER (gramas)
carbs INTEGER (gramas)
fats INTEGER (gramas)
instructions TEXT
created_at TIMESTAMP
```

---

## 🎨 COMPONENTES DE DESIGN

### **AppBar Nutricionista:**
```dart
AppBar(
  flexibleSpace: Container(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [Color(0xFF2A9D8F), Color(0xFF4CAF50)],
      ),
    ),
  ),
  title: Text('Minhas Dietas'),
  elevation: 0,
)
```

### **Card de Dieta:**
```dart
Container(
  decoration: BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(16),
    boxShadow: [
      BoxShadow(
        color: Color(0xFF2A9D8F).withOpacity(0.1),
        blurRadius: 10,
        offset: Offset(0, 4),
      ),
    ],
  ),
  child: // Conteúdo
)
```

### **FAB Criar Dieta:**
```dart
FloatingActionButton.extended(
  onPressed: () => Navigator.push(...),
  backgroundColor: Color(0xFF2A9D8F),
  icon: Icon(Icons.add),
  label: Text('Nova Dieta'),
)
```

---

## 📝 EXEMPLO DE CÓDIGO (diets_list_screen.dart)

```dart
import 'package:flutter/material.dart';
import '../../services/diet_service.dart';

class DietsListScreen extends StatefulWidget {
  const DietsListScreen({super.key});

  @override
  State<DietsListScreen> createState() => _DietsListScreenState();
}

class _DietsListScreenState extends State<DietsListScreen> {
  List<Map<String, dynamic>> _diets = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDiets();
  }

  Future<void> _loadDiets() async {
    setState(() => _isLoading = true);
    final diets = await DietService.getAllDiets();
    setState(() {
      _diets = diets;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF2A9D8F), Color(0xFF4CAF50)],
            ),
          ),
        ),
        title: Text('Minhas Dietas'),
        elevation: 0,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding: EdgeInsets.all(16),
              itemCount: _diets.length,
              itemBuilder: (context, index) {
                final diet = _diets[index];
                return DietCard(diet: diet);
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          // Navigator.push(context, CreateDietScreen());
        },
        backgroundColor: Color(0xFF2A9D8F),
        icon: Icon(Icons.add),
        label: Text('Nova Dieta'),
      ),
    );
  }
}
```

---

## 🎯 PRÓXIMOS PASSOS

1. ✅ **DietService criado**
2. 🔜 Criar `diets_list_screen.dart`
3. 🔜 Criar `create_diet_screen.dart`
4. 🔜 Criar `diet_details_screen.dart`
5. 🔜 Criar widgets reutilizáveis
6. 🔜 Integrar no dashboard do nutricionista

---

**Quer que eu crie as telas agora?**

Posso criar:
- A) Tela de lista de dietas (diets_list_screen.dart)
- B) Tela de criar dieta (create_diet_screen.dart)
- C) Ambas + widgets

**Qual você prefere?**
