# 📝 SISTEMA DE AUDITORIA - GUIA COMPLETO

**Data:** 2026-01-17  
**Status Atual:** Não implementado  
**Prioridade:** 🟡 Média (Segurança já está em 8/10)

---

## 🎯 O QUE É AUDITORIA?

### **Definição:**
Sistema de auditoria é um **registro automático de TODAS as ações** realizadas no sistema, criando um **histórico completo** de quem fez o quê, quando e onde.

### **Analogia:**
Imagine uma **câmera de segurança** que grava tudo que acontece:
- 📹 Quem entrou no sistema
- 📹 Quem criou/editou/excluiu dados
- 📹 Quando isso aconteceu
- 📹 De onde veio (IP, dispositivo)

---

## 🔍 POR QUE IMPLEMENTAR AUDITORIA?

### **1. Segurança** 🔒
```
Cenário: Dados foram deletados acidentalmente
Sem auditoria: ❌ Não sabe quem deletou
Com auditoria: ✅ Sabe exatamente quem, quando e o quê
```

### **2. Conformidade Legal** ⚖️
```
LGPD exige:
- Registro de acesso a dados pessoais
- Rastreamento de modificações
- Evidências para investigações
```

### **3. Detecção de Ataques** 🚨
```
Auditoria detecta:
- Tentativas de acesso não autorizado
- Padrões anormais de uso
- Ações suspeitas
```

### **4. Responsabilização** 👤
```
Com auditoria:
- Cada ação tem um responsável
- Impossível negar ações
- Transparência total
```

---

## 📊 O QUE SERÁ REGISTRADO?

### **Ações Rastreadas:**

| Ação | Exemplo | Importância |
|------|---------|-------------|
| **LOGIN** | Admin fez login às 14:30 | 🔴 Alta |
| **LOGOUT** | Admin fez logout às 18:00 | 🟢 Baixa |
| **CREATE** | Admin criou usuário "João" | 🔴 Alta |
| **UPDATE** | Admin editou usuário "Maria" | 🟡 Média |
| **DELETE** | Admin excluiu usuário "Pedro" | 🔴 Alta |
| **VIEW** | Admin visualizou lista de usuários | 🟢 Baixa |
| **EXPORT** | Admin exportou dados | 🔴 Alta |
| **ERROR** | Tentativa de acesso negado | 🔴 Alta |

---

## 🗄️ ESTRUTURA DO SISTEMA

### **Tabela: audit_logs**

```sql
CREATE TABLE audit_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  
  -- Quem fez?
  user_id UUID REFERENCES auth.users(id),
  user_email TEXT,
  user_name TEXT,
  user_role TEXT,
  
  -- O que fez?
  action TEXT,  -- 'INSERT', 'UPDATE', 'DELETE', 'SELECT'
  table_name TEXT,  -- 'users', 'diets', 'workouts'
  record_id UUID,  -- ID do registro afetado
  old_data JSONB,  -- Dados antes da mudança
  new_data JSONB,  -- Dados depois da mudança
  
  -- Quando fez?
  created_at TIMESTAMP DEFAULT NOW(),
  
  -- De onde fez?
  ip_address TEXT,
  user_agent TEXT,
  device_info TEXT,
  
  -- Contexto adicional
  description TEXT,
  severity TEXT,  -- 'LOW', 'MEDIUM', 'HIGH', 'CRITICAL'
  status TEXT  -- 'SUCCESS', 'FAILED', 'BLOCKED'
);
```

---

## 📝 EXEMPLOS PRÁTICOS

### **Exemplo 1: Criar Usuário**

```sql
INSERT INTO audit_logs (
  user_id, user_email, user_name, user_role,
  action, table_name, record_id,
  new_data,
  ip_address, user_agent,
  description, severity, status
) VALUES (
  'admin-uuid-123',
  'admin@academia.com',
  'Admin Silva',
  'admin',
  'INSERT',
  'users',
  'new-user-uuid-456',
  '{"name": "João", "email": "joao@email.com", "role": "nutritionist"}',
  '192.168.1.100',
  'Mozilla/5.0 (Android)',
  'Admin criou novo nutricionista',
  'HIGH',
  'SUCCESS'
);
```

**Resultado:** Registro completo da criação do usuário!

---

### **Exemplo 2: Editar Usuário**

```sql
INSERT INTO audit_logs (
  user_id, action, table_name, record_id,
  old_data, new_data,
  description, severity
) VALUES (
  'admin-uuid-123',
  'UPDATE',
  'users',
  'user-uuid-789',
  '{"name": "Maria Silva", "phone": "11999999999"}',
  '{"name": "Maria Santos", "phone": "11988888888"}',
  'Admin alterou nome e telefone',
  'MEDIUM'
);
```

**Resultado:** Sabe exatamente o que mudou (antes e depois)!

---

### **Exemplo 3: Deletar Usuário**

```sql
INSERT INTO audit_logs (
  user_id, action, table_name, record_id,
  old_data,
  description, severity, status
) VALUES (
  'admin-uuid-123',
  'DELETE',
  'users',
  'user-uuid-999',
  '{"name": "Pedro", "email": "pedro@email.com", "role": "student"}',
  'Admin excluiu aluno Pedro',
  'CRITICAL',
  'SUCCESS'
);
```

**Resultado:** Dados do usuário deletado ficam salvos no log!

---

### **Exemplo 4: Tentativa de Acesso Negado**

```sql
INSERT INTO audit_logs (
  user_id, action, table_name,
  ip_address,
  description, severity, status
) VALUES (
  'admin-uuid-123',
  'SELECT',
  'users',
  '192.168.1.100',
  'Admin tentou acessar usuários de outro admin',
  'HIGH',
  'BLOCKED'
);
```

**Resultado:** Detecta tentativas de burlar segurança!

---

## 🔧 COMO FUNCIONA (TÉCNICO)

### **1. Triggers Automáticos**

```sql
-- Trigger que dispara APÓS inserção
CREATE TRIGGER audit_users_insert
  AFTER INSERT ON users
  FOR EACH ROW
  EXECUTE FUNCTION log_insert_action();

-- Função que registra a ação
CREATE FUNCTION log_insert_action()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO audit_logs (
    user_id, action, table_name, record_id, new_data
  ) VALUES (
    auth.uid(),
    'INSERT',
    TG_TABLE_NAME,
    NEW.id,
    to_jsonb(NEW)
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;
```

**Resultado:** TODA inserção é registrada automaticamente!

---

### **2. Logs no Código Flutter**

```dart
// Exemplo: Registrar visualização de dados
Future<void> logAction({
  required String action,
  required String tableName,
  String? recordId,
  String? description,
}) async {
  await supabase.from('audit_logs').insert({
    'user_id': currentUser.id,
    'user_email': currentUser.email,
    'action': action,
    'table_name': tableName,
    'record_id': recordId,
    'description': description,
    'severity': 'LOW',
    'status': 'SUCCESS',
  });
}

// Uso:
await logAction(
  action: 'VIEW',
  tableName: 'users',
  description: 'Admin visualizou lista de usuários',
);
```

---

## 📊 DASHBOARD DE AUDITORIA

### **Visualizações Úteis:**

**1. Últimas Ações:**
```sql
SELECT 
  user_name,
  action,
  table_name,
  description,
  created_at
FROM audit_logs
ORDER BY created_at DESC
LIMIT 50;
```

**2. Ações por Usuário:**
```sql
SELECT 
  user_name,
  COUNT(*) as total_actions,
  COUNT(CASE WHEN action = 'INSERT' THEN 1 END) as criados,
  COUNT(CASE WHEN action = 'UPDATE' THEN 1 END) as editados,
  COUNT(CASE WHEN action = 'DELETE' THEN 1 END) as deletados
FROM audit_logs
GROUP BY user_name
ORDER BY total_actions DESC;
```

**3. Ações Suspeitas:**
```sql
SELECT *
FROM audit_logs
WHERE status = 'BLOCKED'
   OR severity = 'CRITICAL'
ORDER BY created_at DESC;
```

---

## 🎯 BENEFÍCIOS

### **Para Você (Desenvolvedor):**
- ✅ Debugar problemas facilmente
- ✅ Entender como usuários usam o sistema
- ✅ Detectar bugs rapidamente

### **Para o Negócio:**
- ✅ Conformidade com LGPD
- ✅ Evidências para disputas legais
- ✅ Transparência com clientes

### **Para Segurança:**
- ✅ Detectar ataques em tempo real
- ✅ Rastrear ações maliciosas
- ✅ Prevenir fraudes

---

## 🚀 IMPLEMENTAÇÃO

### **Fase 1: Estrutura Básica** (1-2 horas)
```
1. Criar tabela audit_logs
2. Criar triggers para INSERT/UPDATE/DELETE
3. Testar registro automático
```

### **Fase 2: Logs no Código** (2-3 horas)
```
1. Criar AuditService no Flutter
2. Adicionar logs em ações críticas
3. Testar logs manuais
```

### **Fase 3: Dashboard** (4-6 horas)
```
1. Criar tela de auditoria
2. Mostrar últimas ações
3. Filtros e busca
```

---

## 📋 EXEMPLO COMPLETO DE USO

### **Cenário: Investigação de Dados Deletados**

**Problema:**
```
Cliente reclama: "Meu aluno João sumiu do sistema!"
```

**Sem Auditoria:**
```
❌ Não sabe quem deletou
❌ Não sabe quando deletou
❌ Não sabe se foi acidente ou proposital
❌ Dados perdidos para sempre
```

**Com Auditoria:**
```sql
-- Buscar o que aconteceu com João
SELECT *
FROM audit_logs
WHERE new_data->>'name' = 'João'
   OR old_data->>'name' = 'João'
ORDER BY created_at DESC;
```

**Resultado:**
```
✅ Descobriu: Admin Silva deletou às 14:30
✅ Motivo: Acidental (clicou errado)
✅ Dados: Salvos no old_data
✅ Solução: Restaurar o usuário
```

---

## 🎯 PRÓXIMOS PASSOS

### **Quer implementar auditoria?**

**Opção 1: Básica (Recomendado para começar)**
- Apenas triggers automáticos
- Registra INSERT/UPDATE/DELETE
- Sem dashboard (vê direto no banco)
- **Tempo:** 1-2 horas

**Opção 2: Completa**
- Triggers + logs no código
- Dashboard de visualização
- Alertas automáticos
- **Tempo:** 1-2 dias

**Opção 3: Avançada**
- Tudo da Opção 2 +
- Machine Learning para detectar anomalias
- Integração com sistemas externos
- **Tempo:** 1-2 semanas

---

## 💰 CUSTO vs BENEFÍCIO

| Aspecto | Sem Auditoria | Com Auditoria |
|---------|---------------|---------------|
| **Segurança** | 8/10 | 10/10 |
| **Conformidade LGPD** | ⚠️ Parcial | ✅ Total |
| **Rastreamento** | ❌ Nenhum | ✅ Completo |
| **Investigações** | ❌ Impossível | ✅ Fácil |
| **Performance** | 100% | 98% (impacto mínimo) |
| **Espaço em disco** | 0 MB | ~10 MB/mês |

---

## 🤔 VALE A PENA?

### **SIM, se você:**
- ✅ Precisa de conformidade com LGPD
- ✅ Quer rastrear ações dos usuários
- ✅ Precisa de evidências para disputas
- ✅ Quer detectar ataques
- ✅ Tem múltiplos administradores

### **TALVEZ, se você:**
- ⚠️ Tem poucos usuários
- ⚠️ Não precisa de conformidade legal
- ⚠️ Confia 100% nos admins

### **NÃO, se você:**
- ❌ App é apenas para você
- ❌ Não tem dados sensíveis
- ❌ Não precisa rastrear nada

---

## 📞 CONCLUSÃO

**Sistema de Auditoria é:**
- 📝 Registro automático de TODAS as ações
- 🔒 Camada extra de segurança
- ⚖️ Conformidade com LGPD
- 🚨 Detecção de ataques
- 👤 Responsabilização de ações

**Recomendação:**
Implementar ao menos a **Opção 1 (Básica)** para ter rastreamento mínimo.

**Quer que eu crie o script de implementação?**

---

**Criado em:** 2026-01-17  
**Status:** Documentação completa  
**Próximo:** Decidir qual opção implementar
