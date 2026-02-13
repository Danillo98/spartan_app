# Plano de Correção - Problemas Identificados

## 🎯 Problemas a Corrigir:

### 1. Reset de Senha (Intermitente)
**Sintoma:** Às vezes token inválido, às vezes sucesso mas senha antiga continua
**Causa Provável:** Conflict entre fluxo nativo e RPC, ou sessão não sendo limpa
**Solução:** Simplificar lógica e garantir signOut após reset

### 2. Foto de Perfil
**Sintoma:** "Sucesso" mas foto não aparece
**Causa Provável:** URL não sendo atualizada no banco ou cache de imagem
**Solução:** Forçar atualização do estado após upload + cache bust

### 3. Atualização de Avisos
**Sintoma:** Só funciona corretamente ao voltar de "Meu Perfil"
**Causa:** Meu Perfil chama `_loadUserData()` que causa `setState()` → rebuild → BulletinBoard refaz query
**Solução:** Criar método `_refreshDashboard()` e chamar ao voltar de TODAS as telas

### 4. Bloqueio Manual (Usuários Logados)
**Sintoma:** Só funciona no login, não detecta bloqueio durante uso
**Causa:** `checkBlockedStatus` só é chamado no `initState` (primeira vez)
**Solução:** Chamar `checkBlockedStatus` em `_refreshDashboard()` também

## 📝 Implementação:

### Passo 1: Criar método universal de refresh
```dart
Future<void> _refreshDashboard() async {
  // 1. Verificar bloqueio
  await AuthService.checkBlockedStatus(context);
  
  // 2. Recarregar dados do usuário (força rebuild)
  await _loadUserData();
}
```

### Passo 2: Chamar ao voltar de CADA tela
- Admin Users Screen
- Financial Dashboard
- Monthly Payment
- Assessment List
- Notice Manager
- Subscription Screen
- Support Screen

### Passo 3: Corrigir Reset de Senha
- Remover fluxo duplo conflitante
- Usar APENAS updateUser nativo
- Garantir signOut após sucesso

### Passo 4: Corrigir Upload de Foto
- Adicionar cache buster (timestamp) na URL
- Forçar setState após upload
- Verificar se URL está sendo salva no banco
