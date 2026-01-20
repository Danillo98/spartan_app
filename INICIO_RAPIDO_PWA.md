# 🎯 INÍCIO RÁPIDO - PWA Spartan App

## ✅ Configuração PWA Completa!

Seu aplicativo está configurado como PWA e pronto para testar em **Android, iOS, Windows e Mac**!

---

## 🚀 Como Testar (3 Passos Simples)

### 1️⃣ Compilar o App

```powershell
.\compilar_pwa.ps1
```

Ou manualmente:
```powershell
flutter build web --release
```

### 2️⃣ Iniciar Servidor Local

```powershell
.\testar_pwa.ps1
```

Ou manualmente:
```powershell
cd build\web
python -m http.server 8000
```

### 3️⃣ Acessar e Instalar

**No Computador:**
- Abra: `http://localhost:8000`

**No Celular (mesma rede Wi-Fi):**
- Descubra seu IP: `ipconfig` (procure por IPv4, ex: 192.168.1.100)
- Abra no celular: `http://SEU_IP:8000`

**Instalar no Celular:**
- **Android**: Menu (⋮) → "Adicionar à tela inicial"
- **iOS**: Compartilhar (□↑) → "Adicionar à Tela de Início"

---

## 📱 Ícones Criados

✅ Todos os ícones foram gerados com o logo do capacete espartano:
- 512x512 (Android, Web)
- 192x192 (Android, Web)
- 144x144 (Windows)
- 96x96 (Android)
- 72x72 (Android)
- 48x48 (Favicon)

---

## 🌐 Deploy em Produção (GRÁTIS)

### Firebase Hosting (Recomendado)
```powershell
npm install -g firebase-tools
firebase login
firebase init hosting
firebase deploy
```

### Netlify (Mais Fácil)
1. Acesse: https://www.netlify.com
2. Arraste a pasta `build/web`
3. Pronto!

### Vercel
```powershell
npm install -g vercel
cd build\web
vercel
```

---

## 📚 Documentação Completa

Veja o arquivo `GUIA_PWA_COMPLETO.md` para:
- Instruções detalhadas
- Troubleshooting
- Configuração do Supabase
- E muito mais!

---

## ✨ Recursos PWA

✅ Funciona offline  
✅ Instalável como app nativo  
✅ Responsivo (adapta ao tamanho da tela)  
✅ Multiplataforma (Android, iOS, Windows, Mac)  
✅ Ícone personalizado  
✅ Tela de loading personalizada  

---

## 🆘 Problemas?

1. **Flutter não encontrado**: Adicione ao PATH ou use o caminho completo
2. **Python não encontrado**: Instale em https://www.python.org/downloads/
3. **Erro ao compilar**: Execute `flutter clean` e tente novamente

---

## 🎉 Pronto para Testar!

Execute `.\compilar_pwa.ps1` e depois `.\testar_pwa.ps1` para começar!
