# 🖥️ Configuração Desktop Windows (Solução de Problemas)

Para resolver o problema de **duplicação de janelas** e **erro na redefinição de senha**, realizamos as seguintes alterações:

1. **Instância Única**: Adicionado o pacote `windows_single_instance`. Isso impede que o aplicativo abra múltiplas vezes. Quando você clica num link e o app já está aberto, a nova janela "passa" o link para a janela existente e se fecha.
2. **Deep Linking Robusto**: Adicionado `app_links` para capturar links de recuperação de senha corretamente no Windows (e outras plataformas), mesmo que o Supabase não detecte a sessão imediatamente.

## 🛠️ O que você precisa fazer agora

### 1. Atualizar Dependências
Rode o comando para baixar os novos pacotes:
```bash
flutter pub get
```

### 2. Configuração de Protocolo (Deep Link)
Para que o Windows saiba que um link (ex: `io.supabase.antigravity://...`) deve abrir o seu app, certifique-se de que o protocolo está registrado.

**Se você usa um instalador (ex: Inno Setup):**
Certifique-se de que o script do instalador registra o protocolo URI scheme associado ao seu executável.

**Para Desenvolvimento (Debug):**
O pacote `app_links` tenta registrar, mas pode ser necessário registrar manualmente no Registro do Windows se não funcionar automaticamente.

### 3. Teste
1. Abra o app Desktop e faça login.
2. Minimize o app ou deixe aberto.
3. No navegador, simule um clique num link de recuperação de senha (ou use o fluxo real).
4. O app deve vir para frente (foco) e navegar para a tela de redefinição de senha, SEM abrir uma segunda janela.

### ⚠️ Observação sobre Builds
Como alteramos dependências nativas (Windows), pode ser necessário rodar um `flutter clean` antes de `flutter run -d windows`.
