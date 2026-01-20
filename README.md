# Gym Management App (Spartan App)

Este projeto é um aplicativo em Flutter para gerenciamento de academias com 4 perfis de usuário, integrado com Supabase e Firebase.

## Como rodar localmente

1. Certifique-se de ter o [Flutter SDK](https://flutter.dev/docs/get-started/install) instalado.
2. Abra o terminal na pasta do projeto.
3. Execute `flutter pub get` para instalar as dependências.
4. Execute `flutter run` para iniciar o aplicativo.

## Arquitetura e Funcionalidades

- **Frontend:** Flutter (Mobile + Web PWA)
- **Backend:** Supabase (PostgreSQL, Auth, Edge Functions)
- **Notificações:** Firebase Cloud Messaging (API V1) via Supabase Edge Functions.
- **Hospedagem Web:** Netlify (CI/CD Automático via GitHub Actions).

## Automação (CI/CD)

Este projeto possui integração contínua configurada com GitHub Actions:

1.  **Deploy Web:** Ao fazer push na branch `main`, o site é compilado e publicado no Netlify.
2.  **Deploy Backend:** Alterações em `supabase/functions` são automaticamente publicadas no Supabase.

## Estrutura

- `lib/main.dart`: Ponto de entrada.
- `lib/screens/`: Contém os painéis para Administrador, Nutricionista, Personal Trainer e Aluno.
- `supabase/functions/`: Código das Edge Functions (ex: envio de push).
