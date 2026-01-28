# INSTRUÇÕES DE TESTE LOCAL - RESET DE SENHA CUSTOMIZADO

## 1. Rodar o SQL no Supabase
Rode o arquivo `CUSTOM_PASSWORD_RESET.sql` no SQL Editor do Supabase.
Isso cria:
- Tabela `password_reset_tokens`
- Função `request_password_reset(email)` 
- Função `reset_password_with_token(token, senha)`

## 2. Testar Localmente

### Opção A: Testar o App Flutter
```bash
cd c:\Users\Danillo\.gemini\antigravity\scratch\spartan_app
flutter run -d chrome
```

### Opção B: Testar apenas o HTML
1. Abra o arquivo diretamente:
   `file:///c:/Users/Danillo/.gemini/antigravity/scratch/spartan_app/web/reset-password.html?token=TESTE123`

2. Ou use um servidor local:
   ```bash
   cd web
   python -m http.server 8000
   ```
   Depois abra: `http://localhost:8000/reset-password.html?token=TESTE123`

## 3. Fluxo de Teste Completo

1. No App, vá em "Esqueci minha senha"
2. Digite o email do administrador
3. Verifique o email (pode ir no spam)
4. Clique no link do email
5. Digite a nova senha (2x)
6. Clique em "Redefinir Senha"
7. Deve mostrar "Sucesso!"

## 4. Debug

Abra o Console do navegador (F12) para ver os logs:
- ✅ "Token válido encontrado" = Link funcionou
- ❌ "Nenhum token encontrado" = Problema no link do email
- ❌ "Erro na RPC" = Problema no banco de dados

## 5. Problemas Comuns

**Email não chega:**
- Verifique spam
- Verifique se rodou o SQL
- Verifique se o email existe no auth.users

**Link inválido:**
- Token pode ter expirado (1 hora)
- Token pode já ter sido usado
- Rode o SQL novamente

**Erro ao resetar:**
- Verifique se as funções RPC têm permissão (GRANT EXECUTE)
- Verifique se a senha tem mínimo 6 caracteres
