# ⚙️ Configuração Supabase para PWA

## 🔧 URLs que você precisa configurar no Supabase

Após fazer o deploy do seu PWA, você precisa adicionar as URLs no Supabase para que a autenticação funcione corretamente.

---

## 📍 Onde Configurar

1. Acesse: https://app.supabase.com
2. Selecione seu projeto
3. Vá em: **Authentication** → **URL Configuration**

---

## 🌐 URLs para Adicionar

### Se estiver testando LOCALMENTE:

**Site URL:**
```
http://localhost:8000
```

**Redirect URLs:**
```
http://localhost:8000/*
http://localhost:8000/confirm
http://localhost:8000/reset-password
```

### Se estiver testando no CELULAR (mesma rede):

Substitua `192.168.1.100` pelo seu IP real (descubra com `ipconfig`):

**Redirect URLs (adicione também):**
```
http://192.168.1.100:8000/*
http://192.168.1.100:8000/confirm
http://192.168.1.100:8000/reset-password
```

### Quando fizer DEPLOY em PRODUÇÃO:

Substitua `sua-url.com` pela URL real do seu deploy:

**Site URL:**
```
https://sua-url.com
```

**Redirect URLs:**
```
https://sua-url.com/*
https://sua-url.com/confirm
https://sua-url.com/reset-password
```

---

## 📋 Exemplos de URLs de Produção

### Firebase Hosting:
```
https://spartan-app-12345.web.app
https://spartan-app-12345.web.app/*
https://spartan-app-12345.web.app/confirm
https://spartan-app-12345.web.app/reset-password
```

### Netlify:
```
https://spartan-app.netlify.app
https://spartan-app.netlify.app/*
https://spartan-app.netlify.app/confirm
https://spartan-app.netlify.app/reset-password
```

### Vercel:
```
https://spartan-app.vercel.app
https://spartan-app.vercel.app/*
https://spartan-app.vercel.app/confirm
https://spartan-app.vercel.app/reset-password
```

### Domínio Personalizado:
```
https://www.meuapp.com.br
https://www.meuapp.com.br/*
https://www.meuapp.com.br/confirm
https://www.meuapp.com.br/reset-password
```

---

## ⚠️ IMPORTANTE

1. **SEMPRE use `/*` no final** para permitir todas as rotas
2. **Use HTTPS em produção** (obrigatório para PWA funcionar completamente)
3. **Adicione TODAS as URLs** onde o app será acessado
4. **Não esqueça** de adicionar as rotas `/confirm` e `/reset-password`

---

## ✅ Checklist de Configuração

Após fazer o deploy, verifique:

- [ ] Site URL configurada
- [ ] Redirect URLs configuradas (com `/*`)
- [ ] Rota `/confirm` adicionada
- [ ] Rota `/reset-password` adicionada
- [ ] HTTPS habilitado (em produção)
- [ ] Testado login/cadastro
- [ ] Testado confirmação de email
- [ ] Testado recuperação de senha

---

## 🔍 Como Testar

1. Faça login no app
2. Tente criar uma conta
3. Verifique se recebe o email de confirmação
4. Clique no link do email
5. Verifique se é redirecionado corretamente

Se algo não funcionar, verifique:
- Console do navegador (F12)
- Se as URLs estão corretas no Supabase
- Se o HTTPS está ativo (em produção)

---

## 📞 Suporte

Se tiver problemas:
1. Verifique o console do navegador (F12)
2. Verifique os logs do Supabase
3. Confirme que as URLs estão corretas
4. Tente limpar o cache do navegador

---

## 🎯 Resumo Rápido

**Para testar localmente:**
```
Site URL: http://localhost:8000
Redirect: http://localhost:8000/*
```

**Para produção:**
```
Site URL: https://sua-url.com
Redirect: https://sua-url.com/*
```

**Sempre adicione também:**
```
/confirm
/reset-password
```

---

✅ Pronto! Com isso configurado, seu PWA funcionará perfeitamente em qualquer dispositivo!
