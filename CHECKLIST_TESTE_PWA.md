# ✅ CHECKLIST - Testar PWA no Celular

Use este checklist para garantir que tudo está funcionando corretamente!

---

## 📋 FASE 1: Preparação (no Computador)

### Compilar o App
- [ ] Abrir PowerShell na pasta do projeto
- [ ] Executar: `.\compilar_pwa.ps1`
- [ ] Aguardar compilação concluir (pode levar alguns minutos)
- [ ] Verificar se apareceu a pasta `build\web`

**OU manualmente:**
- [ ] Executar: `flutter clean`
- [ ] Executar: `flutter pub get`
- [ ] Executar: `flutter build web --release`

---

## 📋 FASE 2: Servidor Local (no Computador)

### Descobrir o IP do Computador
- [ ] Abrir PowerShell
- [ ] Executar: `ipconfig`
- [ ] Procurar por "Endereço IPv4" (ex: 192.168.1.100)
- [ ] Anotar o IP: ___________________

### Iniciar o Servidor
- [ ] Executar: `.\testar_pwa.ps1`

**OU manualmente:**
- [ ] Navegar: `cd build\web`
- [ ] Executar: `python -m http.server 8000`
- [ ] Verificar mensagem: "Serving HTTP on..."

### Testar no Navegador do PC
- [ ] Abrir navegador
- [ ] Acessar: `http://localhost:8000`
- [ ] Verificar se o app carrega
- [ ] Verificar se aparece a tela de loading
- [ ] Verificar se o ícone do capacete aparece
- [ ] Fazer login de teste

---

## 📋 FASE 3: Testar no Celular

### Conectar na Mesma Rede Wi-Fi
- [ ] Celular conectado na mesma rede Wi-Fi do PC
- [ ] Verificar nome da rede: ___________________

### Acessar no Celular (Android)
- [ ] Abrir Chrome no celular
- [ ] Digitar: `http://SEU_IP:8000` (substituir SEU_IP)
- [ ] Exemplo: `http://192.168.1.100:8000`
- [ ] Verificar se o app carrega
- [ ] Verificar responsividade (gira tela)
- [ ] Fazer login de teste

### Acessar no Celular (iOS)
- [ ] Abrir Safari no iPhone/iPad
- [ ] Digitar: `http://SEU_IP:8000` (substituir SEU_IP)
- [ ] Exemplo: `http://192.168.1.100:8000`
- [ ] Verificar se o app carrega
- [ ] Verificar responsividade (gira tela)
- [ ] Fazer login de teste

---

## 📋 FASE 4: Instalar PWA no Celular

### Android (Chrome)
- [ ] Abrir o app no Chrome
- [ ] Tocar no menu (⋮) no canto superior direito
- [ ] Selecionar "Adicionar à tela inicial"
- [ ] Confirmar o nome do app
- [ ] Tocar em "Adicionar"
- [ ] Verificar se o ícone apareceu na tela inicial
- [ ] Abrir o app pelo ícone
- [ ] Verificar se abre em tela cheia (sem barra do navegador)

### iOS (Safari)
- [ ] Abrir o app no Safari
- [ ] Tocar no botão de compartilhar (□↑) na parte inferior
- [ ] Rolar e tocar em "Adicionar à Tela de Início"
- [ ] Editar o nome se necessário
- [ ] Tocar em "Adicionar"
- [ ] Verificar se o ícone apareceu na tela inicial
- [ ] Abrir o app pelo ícone
- [ ] Verificar se abre em tela cheia

---

## 📋 FASE 5: Testar Funcionalidades

### Funcionalidades Básicas
- [ ] Login funciona
- [ ] Cadastro funciona
- [ ] Navegação entre telas funciona
- [ ] Ícones e imagens carregam
- [ ] Cores e tema aparecem corretamente
- [ ] Botões respondem ao toque
- [ ] Formulários funcionam

### Funcionalidades PWA
- [ ] App abre em tela cheia (sem barra do navegador)
- [ ] Ícone do capacete aparece correto
- [ ] Splash screen (tela de loading) aparece
- [ ] App funciona em modo retrato
- [ ] App funciona em modo paisagem
- [ ] Rotação de tela funciona

### Teste de Conectividade
- [ ] App funciona com Wi-Fi
- [ ] App funciona com dados móveis
- [ ] Desligar internet e recarregar (deve mostrar cache)
- [ ] Religar internet e verificar sincronização

---

## 📋 FASE 6: Testar em Múltiplos Dispositivos

### Dispositivos Android
- [ ] Celular Android 1: ___________________
- [ ] Celular Android 2: ___________________
- [ ] Tablet Android: ___________________

### Dispositivos iOS
- [ ] iPhone: ___________________
- [ ] iPad: ___________________

### Desktop
- [ ] Windows (Chrome): ___________________
- [ ] Windows (Edge): ___________________
- [ ] Mac (Safari): ___________________
- [ ] Mac (Chrome): ___________________

---

## 📋 FASE 7: Configurar Supabase (Para Produção)

### Configuração Local (Teste)
- [ ] Acessar Supabase Dashboard
- [ ] Ir em Authentication → URL Configuration
- [ ] Adicionar Site URL: `http://localhost:8000`
- [ ] Adicionar Redirect URL: `http://localhost:8000/*`
- [ ] Adicionar Redirect URL: `http://SEU_IP:8000/*`
- [ ] Salvar configurações
- [ ] Testar login novamente

### Testar Autenticação
- [ ] Criar nova conta
- [ ] Verificar se recebe email
- [ ] Clicar no link de confirmação
- [ ] Verificar se confirma corretamente
- [ ] Fazer login
- [ ] Testar recuperação de senha

---

## 📋 FASE 8: Deploy em Produção (Opcional)

### Escolher Plataforma
- [ ] Firebase Hosting
- [ ] Netlify
- [ ] Vercel
- [ ] GitHub Pages
- [ ] Outro: ___________________

### Fazer Deploy
- [ ] Seguir guia da plataforma escolhida
- [ ] Fazer upload da pasta `build\web`
- [ ] Aguardar deploy concluir
- [ ] Anotar URL de produção: ___________________

### Configurar Supabase (Produção)
- [ ] Adicionar Site URL de produção
- [ ] Adicionar Redirect URLs de produção
- [ ] Adicionar rota `/confirm`
- [ ] Adicionar rota `/reset-password`
- [ ] Salvar configurações

### Testar em Produção
- [ ] Acessar URL de produção no PC
- [ ] Acessar URL de produção no celular
- [ ] Instalar PWA da URL de produção
- [ ] Testar todas as funcionalidades
- [ ] Verificar HTTPS ativo
- [ ] Testar login/cadastro
- [ ] Testar confirmação de email

---

## 📋 FASE 9: Verificação Final

### Qualidade
- [ ] App carrega rápido
- [ ] Sem erros no console (F12)
- [ ] Todas as imagens carregam
- [ ] Todas as fontes carregam
- [ ] Cores corretas em todos os dispositivos
- [ ] Responsivo em todos os tamanhos

### Performance
- [ ] Lighthouse Score > 80 (Performance)
- [ ] Lighthouse Score > 90 (PWA)
- [ ] Lighthouse Score > 80 (Accessibility)
- [ ] Lighthouse Score > 90 (Best Practices)

### Compatibilidade
- [ ] Funciona no Android
- [ ] Funciona no iOS
- [ ] Funciona no Windows
- [ ] Funciona no Mac
- [ ] Funciona offline (básico)

---

## 🎉 CONCLUSÃO

### Tudo Funcionando?
- [ ] ✅ PWA instalado no Android
- [ ] ✅ PWA instalado no iOS
- [ ] ✅ PWA instalado no Windows
- [ ] ✅ PWA instalado no Mac
- [ ] ✅ Todas as funcionalidades testadas
- [ ] ✅ Pronto para usar!

---

## 📝 Anotações e Problemas Encontrados

```
_______________________________________________
_______________________________________________
_______________________________________________
_______________________________________________
_______________________________________________
```

---

## 🆘 Problemas Comuns

### App não carrega no celular
- ✅ Verificar se está na mesma rede Wi-Fi
- ✅ Verificar se o IP está correto
- ✅ Verificar se o servidor está rodando
- ✅ Tentar desligar firewall temporariamente

### Não aparece opção "Adicionar à tela inicial"
- ✅ Usar HTTPS (ou localhost para testes)
- ✅ Verificar se manifest.json está acessível
- ✅ Limpar cache do navegador
- ✅ Tentar em outro navegador

### Ícone não aparece correto
- ✅ Limpar cache do dispositivo
- ✅ Desinstalar e reinstalar o PWA
- ✅ Verificar se arquivos estão em web/icons/
- ✅ Verificar console para erros

---

**Data do Teste:** ___/___/______

**Testado por:** _______________________

**Status Final:** ⬜ Aprovado  ⬜ Pendente  ⬜ Problemas

---

✅ **Bons testes!** 💪🏛️
