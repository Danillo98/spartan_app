# 🚀 COMPILAR PWA - Guia Rápido

## ⚠️ Problema: Flutter não está no PATH

O comando `flutter` não está disponível no PowerShell. Vamos resolver isso!

---

## ✅ Solução 1: Compilar Manualmente (MAIS FÁCIL)

### Passo 1: Encontrar o Flutter

O Flutter provavelmente está instalado em um destes locais:
- `C:\src\flutter\bin\flutter`
- `C:\flutter\bin\flutter`
- `C:\Users\SEU_USUARIO\flutter\bin\flutter`
- `C:\development\flutter\bin\flutter`

### Passo 2: Abrir Terminal no VS Code

1. No VS Code, pressione `` Ctrl+` `` (abre terminal)
2. Ou vá em: **Terminal** → **New Terminal**

### Passo 3: Executar Comandos

**Substitua** `C:\src\flutter` pelo caminho real do seu Flutter:

```powershell
# 1. Clean
C:\src\flutter\bin\flutter clean

# 2. Get dependencies
C:\src\flutter\bin\flutter pub get

# 3. Build web
C:\src\flutter\bin\flutter build web --release --web-renderer html
```

### Passo 4: Aguardar

A compilação leva 2-5 minutos. Aguarde até aparecer:
```
✓ Built build\web
```

---

## ✅ Solução 2: Adicionar Flutter ao PATH (Permanente)

### Windows 10/11:

1. Pressione `Win + R`
2. Digite: `sysdm.cpl` e pressione Enter
3. Vá na aba **"Avançado"**
4. Clique em **"Variáveis de Ambiente"**
5. Em **"Variáveis do sistema"**, encontre **"Path"**
6. Clique em **"Editar"**
7. Clique em **"Novo"**
8. Adicione: `C:\src\flutter\bin` (ou o caminho correto)
9. Clique em **"OK"** em todas as janelas
10. **Feche e abra novamente** o VS Code
11. Agora `flutter` funcionará!

---

## ✅ Solução 3: Usar Android Studio (Se Tiver)

Se você usa Android Studio para desenvolvimento Flutter:

1. Abra o projeto no Android Studio
2. No terminal do Android Studio, execute:
   ```bash
   flutter build web --release --web-renderer html
   ```

---

## 📁 Verificar se Compilou

Após executar o comando, verifique se a pasta foi criada:

```
spartan_app/
└── build/
    └── web/           ← Esta pasta deve existir
        ├── index.html
        ├── landing.html
        ├── confirm.html
        ├── reset-password.html
        ├── manifest.json
        ├── icons/
        └── ...
```

---

## 🌐 Próximo Passo: Deploy no Netlify

Após compilar com sucesso:

### 1. Acesse Netlify
https://app.netlify.com

### 2. Vá no Seu Projeto Existente

### 3. Deploy Manual
- Clique em **"Deploys"**
- Clique em **"Deploy manually"** ou arraste a pasta

### 4. Arraste a Pasta
Arraste a pasta: `build\web` (a pasta inteira!)

### 5. Aguarde
Deploy leva 1-2 minutos

### 6. Pronto!
Acesse: `https://seu-projeto.netlify.app`

---

## 🎯 Comandos Resumidos

**Se souber o caminho do Flutter:**

```powershell
# Substitua C:\src\flutter pelo caminho real
C:\src\flutter\bin\flutter clean
C:\src\flutter\bin\flutter pub get
C:\src\flutter\bin\flutter build web --release --web-renderer html
```

**Se Flutter estiver no PATH:**

```powershell
flutter clean
flutter pub get
flutter build web --release --web-renderer html
```

---

## 🆘 Como Encontrar o Caminho do Flutter

### Opção 1: Procurar no Disco
1. Abra o Explorador de Arquivos
2. Vá em `C:\`
3. Procure por pasta chamada `flutter` ou `src\flutter`
4. Dentro deve ter: `bin\flutter.bat`

### Opção 2: Usar PowerShell
```powershell
Get-ChildItem -Path C:\ -Filter flutter.bat -Recurse -ErrorAction SilentlyContinue
```

### Opção 3: Verificar Variáveis de Ambiente
```powershell
$env:Path -split ';' | Select-String flutter
```

---

## ✅ Checklist

- [ ] Encontrei o caminho do Flutter
- [ ] Executei `flutter clean`
- [ ] Executei `flutter pub get`
- [ ] Executei `flutter build web --release`
- [ ] Pasta `build\web` foi criada
- [ ] Verifiquei que `landing.html` está em `build\web`
- [ ] Pronto para fazer deploy no Netlify!

---

## 📝 Exemplo Completo

Se seu Flutter está em `C:\flutter`:

```powershell
# Navegar para o projeto
cd C:\Users\Danillo\.gemini\antigravity\scratch\spartan_app

# Limpar
C:\flutter\bin\flutter clean

# Dependências
C:\flutter\bin\flutter pub get

# Compilar
C:\flutter\bin\flutter build web --release --web-renderer html

# Verificar
dir build\web
```

Deve mostrar:
```
confirm.html
index.html
landing.html
reset-password.html
manifest.json
icons/
...
```

---

## 🎉 Pronto!

Depois de compilar, arraste `build\web` para o Netlify e está pronto! 🚀
