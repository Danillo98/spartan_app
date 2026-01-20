# 💰 ESCLARECIMENTO: CUSTOS E RLS

**Data:** 2026-01-17  
**Tópicos:** Custos de Auditoria + Tabelas sem RLS

---

## 💰 PARTE 1: CUSTOS DA AUDITORIA

### **IMPORTANTE: Não são custos financeiros! 💸**

Quando falei "custo baixo, médio, alto", me referi ao **CUSTO DE DESENVOLVIMENTO** (tempo e esforço), **NÃO dinheiro**!

---

### **📊 DETALHAMENTO DOS CUSTOS**

| Opção | Custo Financeiro | Custo de Tempo | Custo de Esforço | Custo de Manutenção |
|-------|------------------|----------------|------------------|---------------------|
| **Básica** | R$ 0,00 | 1-2 horas | Baixo | Mínimo |
| **Completa** | R$ 0,00 | 1-2 dias | Médio | Médio |
| **Avançada** | R$ 0,00 | 1-2 semanas | Alto | Alto |

---

### **OPÇÃO 1: BÁSICA - "Custo Baixo"**

**Custo Financeiro:** R$ 0,00 ✅

**Custo de Tempo:**
- 30 min: Criar tabela audit_logs
- 30 min: Criar triggers
- 30 min: Testar
- **Total:** 1-2 horas

**Custo de Esforço:**
- Apenas SQL (sem código Flutter)
- Copiar e colar script
- Testar uma vez
- **Nível:** Fácil

**Custo de Manutenção:**
- Nenhum (funciona sozinho)
- Apenas consultar logs quando necessário
- **Nível:** Mínimo

**Custo de Performance:**
- Impacto: ~2% (quase zero)
- Espaço em disco: ~10 MB/mês
- **Nível:** Insignificante

---

### **OPÇÃO 2: COMPLETA - "Custo Médio"**

**Custo Financeiro:** R$ 0,00 ✅

**Custo de Tempo:**
- 2 horas: Opção Básica
- 4 horas: Criar AuditService no Flutter
- 2 horas: Criar tela de visualização
- 2 horas: Testes
- **Total:** 1-2 dias

**Custo de Esforço:**
- SQL + Código Flutter
- Criar interface de usuário
- Testes mais complexos
- **Nível:** Médio

**Custo de Manutenção:**
- Atualizar quando adicionar novas features
- Manter dashboard funcionando
- **Nível:** Médio

---

### **OPÇÃO 3: AVANÇADA - "Custo Alto"**

**Custo Financeiro:** R$ 0,00 ✅

**Custo de Tempo:**
- 2 dias: Opção Completa
- 3 dias: Sistema de alertas
- 2 dias: Detecção de anomalias
- 2 dias: Exportação de relatórios
- 2 dias: Testes e refinamento
- **Total:** 1-2 semanas

**Custo de Esforço:**
- SQL + Flutter + Lógica complexa
- Machine Learning (opcional)
- Integração com serviços externos
- **Nível:** Alto

**Custo de Manutenção:**
- Ajustar algoritmos de detecção
- Manter integrações
- Atualizar relatórios
- **Nível:** Alto

---

### **💡 RESUMO: "CUSTO" = TEMPO E ESFORÇO**

```
Custo Baixo   = 1-2 horas de trabalho
Custo Médio   = 1-2 dias de trabalho
Custo Alto    = 1-2 semanas de trabalho

💸 Custo Financeiro = R$ 0,00 (TODAS as opções)
```

---

## 🔒 PARTE 2: TABELAS SEM RLS

### **Por que algumas tabelas NÃO têm RLS?**

Vou explicar cada uma:

---

### **1. `audit_logs` - UNRESTRICTED** ❌

**Por quê?**
- Tabela de sistema/auditoria
- Ainda não foi implementada completamente
- Quando implementar, terá RLS específico

**Deveria ter RLS?**
- ✅ SIM! Cada admin deve ver apenas seus próprios logs
- Será implementado quando criar o sistema de auditoria

**Política futura:**
```sql
CREATE POLICY "audit_logs_select" ON audit_logs
FOR SELECT
USING (user_id = auth.uid());
```

---

### **2. `email_verification_codes` - UNRESTRICTED** ❌

**Por quê?**
- Tabela de sistema para verificação de email
- Gerenciada automaticamente pelo Supabase
- Não contém dados sensíveis dos usuários

**Deveria ter RLS?**
- ⚠️ OPCIONAL
- Códigos são temporários (expiram)
- Não expõe dados críticos

**Se quiser proteger:**
```sql
CREATE POLICY "email_codes_select" ON email_verification_codes
FOR SELECT
USING (email = auth.jwt()->>'email');
```

---

### **3. `login_attempts` - UNRESTRICTED** ❌

**Por quê?**
- Tabela de sistema para segurança
- Rastreia tentativas de login
- Usada para prevenir ataques de força bruta

**Deveria ter RLS?**
- ⚠️ OPCIONAL
- Útil para admins verem tentativas de ataque
- Não expõe senhas (apenas tentativas)

**Se quiser proteger:**
```sql
CREATE POLICY "login_attempts_select" ON login_attempts
FOR SELECT
USING (
  -- Apenas o próprio usuário ou admins
  user_id = auth.uid() 
  OR EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND role = 'admin')
);
```

---

### **4. `students_with_diet` - UNRESTRICTED** ❌

**Por quê?**
- ❗ **ATENÇÃO: Esta DEVERIA ter RLS!**
- Relaciona alunos com dietas
- Contém dados sensíveis

**Deveria ter RLS?**
- ✅ **SIM! URGENTE!**
- Precisa proteger para evitar vazamento

**Política necessária:**
```sql
CREATE POLICY "students_with_diet_policy" ON students_with_diet
FOR ALL
USING (
  -- Admin vê se criou o aluno OU a dieta
  EXISTS (
    SELECT 1 FROM users 
    WHERE id = students_with_diet.student_id 
      AND created_by_admin_id = auth.uid()
  )
  OR
  EXISTS (
    SELECT 1 FROM diets 
    WHERE id = students_with_diet.diet_id 
      AND created_by_admin_id = auth.uid()
  )
  OR
  -- Aluno vê suas próprias dietas
  student_id = auth.uid()
  OR
  -- Nutricionista vê dietas que criou
  EXISTS (
    SELECT 1 FROM diets 
    WHERE id = students_with_diet.diet_id 
      AND nutritionist_id = auth.uid()
  )
);
```

---

### **5. `students_with_workout` - UNRESTRICTED** ❌

**Por quê?**
- ❗ **ATENÇÃO: Esta DEVERIA ter RLS!**
- Relaciona alunos com treinos
- Contém dados sensíveis

**Deveria ter RLS?**
- ✅ **SIM! URGENTE!**
- Precisa proteger para evitar vazamento

**Política necessária:**
```sql
CREATE POLICY "students_with_workout_policy" ON students_with_workout
FOR ALL
USING (
  -- Admin vê se criou o aluno OU o treino
  EXISTS (
    SELECT 1 FROM users 
    WHERE id = students_with_workout.student_id 
      AND created_by_admin_id = auth.uid()
  )
  OR
  EXISTS (
    SELECT 1 FROM workouts 
    WHERE id = students_with_workout.workout_id 
      AND created_by_admin_id = auth.uid()
  )
  OR
  -- Aluno vê seus próprios treinos
  student_id = auth.uid()
  OR
  -- Trainer vê treinos que criou
  EXISTS (
    SELECT 1 FROM workouts 
    WHERE id = students_with_workout.workout_id 
      AND trainer_id = auth.uid()
  )
);
```

---

## 📊 RESUMO: TABELAS SEM RLS

| Tabela | Status Atual | Deveria ter RLS? | Prioridade |
|--------|--------------|------------------|------------|
| `audit_logs` | ❌ Sem RLS | ✅ Sim | 🟡 Média |
| `email_verification_codes` | ❌ Sem RLS | ⚠️ Opcional | 🟢 Baixa |
| `login_attempts` | ❌ Sem RLS | ⚠️ Opcional | 🟢 Baixa |
| `students_with_diet` | ❌ Sem RLS | ✅ **SIM!** | 🔴 **ALTA** |
| `students_with_workout` | ❌ Sem RLS | ✅ **SIM!** | 🔴 **ALTA** |

---

## 🚨 VULNERABILIDADE IDENTIFICADA!

### **CRÍTICO: `students_with_diet` e `students_with_workout`**

Essas tabelas **NÃO têm RLS** e contêm dados sensíveis!

**Risco:**
```
❌ Admin A pode ver quais alunos do Admin B têm dietas
❌ Admin A pode ver quais alunos do Admin B têm treinos
❌ Possível vazamento de informações
```

**Impacto:**
- 🔴 Segurança: 8/10 → 6/10
- 🔴 Privacidade: Comprometida
- 🔴 LGPD: Violação potencial

---

## 🔧 SOLUÇÃO URGENTE

Vou criar um script para adicionar RLS nessas 2 tabelas críticas:

**Script:** `CORRIGIR_RLS_TABELAS_FALTANTES.sql`

**O que faz:**
1. Adiciona RLS em `students_with_diet`
2. Adiciona RLS em `students_with_workout`
3. Cria políticas de segurança
4. Testa isolamento

**Tempo:** 5 minutos
**Risco:** Baixo
**Benefício:** Segurança 6/10 → 9/10

---

## 🎯 RECOMENDAÇÃO

### **URGENTE (Agora):**
1. ✅ Adicionar RLS em `students_with_diet`
2. ✅ Adicionar RLS em `students_with_workout`

### **Médio Prazo (Esta Semana):**
3. ⚠️ Considerar RLS em `login_attempts`
4. ⚠️ Considerar RLS em `email_verification_codes`

### **Longo Prazo (Quando implementar auditoria):**
5. 🔜 Adicionar RLS em `audit_logs`

---

## 💡 CONCLUSÃO

### **Sobre Custos:**
- 💸 **Custo Financeiro:** R$ 0,00 (todas as opções)
- ⏱️ **Custo de Tempo:** 1h a 2 semanas (depende da opção)
- 🔧 **Custo de Esforço:** Baixo a Alto (depende da opção)

### **Sobre Tabelas sem RLS:**
- ⚠️ **2 tabelas críticas** sem proteção
- 🔴 **Vulnerabilidade** identificada
- ✅ **Solução** pronta para implementar

---

**Quer que eu crie o script para corrigir as 2 tabelas críticas?**

Isso vai elevar a segurança de 8/10 para 9/10! 🚀
