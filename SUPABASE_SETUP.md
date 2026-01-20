# Configuração do Supabase - Spartan App

## 📋 Passos para Conectar ao Supabase

### 1. Obter Credenciais do Supabase

1. Acesse seu projeto no [Supabase](https://supabase.com)
2. Vá em **Project Settings** (ícone de engrenagem)
3. Clique em **API** no menu lateral
4. Copie as seguintes informações:
   - **Project URL** (URL)
   - **anon public** (Anon Key)

### 2. Configurar as Credenciais no App

Abra o arquivo `lib/config/supabase_config.dart` e substitua:

```dart
static const String supabaseUrl = 'SUA_URL_AQUI';
static const String supabaseAnonKey = 'SUA_ANON_KEY_AQUI';
```

Por suas credenciais reais:

```dart
static const String supabaseUrl = 'https://seu-projeto.supabase.co';
static const String supabaseAnonKey = 'sua-chave-anon-aqui';
```

### 3. Instalar Dependências

Execute no terminal (na pasta do projeto):

```bash
flutter pub get
```

### 4. Executar o App

```bash
flutter run
```

## 🗄️ Estrutura do Banco de Dados Sugerida

Aqui está uma estrutura básica de tabelas que você pode criar no Supabase:

### Tabela: `users`
```sql
CREATE TABLE users (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  email TEXT UNIQUE NOT NULL,
  name TEXT NOT NULL,
  role TEXT NOT NULL CHECK (role IN ('admin', 'nutritionist', 'trainer', 'student')),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
```

### Tabela: `workout_plans`
```sql
CREATE TABLE workout_plans (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  student_id UUID REFERENCES users(id),
  trainer_id UUID REFERENCES users(id),
  title TEXT NOT NULL,
  description TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
```

### Tabela: `diet_plans`
```sql
CREATE TABLE diet_plans (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  student_id UUID REFERENCES users(id),
  nutritionist_id UUID REFERENCES users(id),
  title TEXT NOT NULL,
  description TEXT,
  calories INTEGER,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
```

## 🔧 Como Usar o Supabase no Código

### Exemplo: Buscar todos os usuários
```dart
import 'package:spartan_app/services/supabase_service.dart';

Future<void> getUsers() async {
  final response = await SupabaseService.client
      .from('users')
      .select();
  
  print(response);
}
```

### Exemplo: Inserir um novo usuário
```dart
Future<void> createUser(String email, String name, String role) async {
  await SupabaseService.client
      .from('users')
      .insert({
        'email': email,
        'name': name,
        'role': role,
      });
}
```

### Exemplo: Atualizar um usuário
```dart
Future<void> updateUser(String userId, String newName) async {
  await SupabaseService.client
      .from('users')
      .update({'name': newName})
      .eq('id', userId);
}
```

### Exemplo: Deletar um usuário
```dart
Future<void> deleteUser(String userId) async {
  await SupabaseService.client
      .from('users')
      .delete()
      .eq('id', userId);
}
```

## ✅ Verificação

Para verificar se está tudo funcionando, o app tentará conectar ao Supabase quando iniciar. Se houver erro, verifique:

1. ✓ As credenciais estão corretas em `supabase_config.dart`
2. ✓ Executou `flutter pub get`
3. ✓ Seu projeto Supabase está ativo
4. ✓ Tem conexão com a internet

## 📚 Próximos Passos

1. Configure as tabelas no Supabase usando o SQL Editor
2. Implemente autenticação (login/registro)
3. Crie as telas de CRUD para cada tipo de usuário
4. Configure Row Level Security (RLS) no Supabase para segurança

## 🔐 Segurança

⚠️ **IMPORTANTE**: Nunca compartilhe suas credenciais do Supabase publicamente!

Para produção, considere:
- Usar variáveis de ambiente
- Configurar Row Level Security (RLS)
- Implementar autenticação adequada
