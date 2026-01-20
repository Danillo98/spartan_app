-- ============================================
-- CONFIGURAÇÃO DE EMAIL CUSTOMIZADO NO SUPABASE
-- ============================================

-- Este script configura templates de email customizados no Supabase
-- 100% GRATUITO - Sem necessidade de serviços externos

-- ============================================
-- PASSO 1: CONFIGURAR NO DASHBOARD DO SUPABASE
-- ============================================

/*
1. Vá em: Authentication → Email Templates
2. Selecione: "Magic Link" (vamos usar este template)
3. Customize o template:

ASSUNTO:
🔐 Seu código de verificação - Spartan App

CORPO (HTML):
*/

<!DOCTYPE html>
<html lang="pt-BR">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Código de Verificação - Spartan App</title>
</head>
<body style="margin: 0; padding: 0; font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; background-color: #f4f4f4;">
  <table width="100%" cellpadding="0" cellspacing="0" style="background-color: #f4f4f4; padding: 40px 20px;">
    <tr>
      <td align="center">
        <table width="600" cellpadding="0" cellspacing="0" style="background-color: #ffffff; border-radius: 12px; overflow: hidden; box-shadow: 0 4px 20px rgba(0, 0, 0, 0.1);">
          
          <!-- Header -->
          <tr>
            <td style="background: linear-gradient(135deg, #1a1a1a 0%, #2d2d2d 100%); padding: 40px 20px; text-align: center;">
              <h1 style="color: #ffffff; font-size: 32px; font-weight: bold; letter-spacing: 2px; margin: 0;">
                ⚡ SPARTAN APP
              </h1>
            </td>
          </tr>
          
          <!-- Content -->
          <tr>
            <td style="padding: 40px 30px;">
              <h2 style="font-size: 18px; color: #333333; margin: 0 0 20px 0;">
                Olá! 👋
              </h2>
              
              <p style="font-size: 16px; color: #666666; line-height: 1.6; margin: 0 0 30px 0;">
                Você está a um passo de completar seu cadastro no <strong>Spartan App</strong>.
                Use o código abaixo para verificar seu email e ativar sua conta de administrador.
              </p>
              
              <!-- Code Box -->
              <table width="100%" cellpadding="0" cellspacing="0" style="margin: 30px 0;">
                <tr>
                  <td style="background: linear-gradient(135deg, #f8f9fa 0%, #e9ecef 100%); border: 2px solid #dee2e6; border-radius: 12px; padding: 30px; text-align: center;">
                    <p style="font-size: 14px; color: #666666; text-transform: uppercase; letter-spacing: 1px; margin: 0 0 15px 0;">
                      Seu Código de Verificação
                    </p>
                    <p style="font-size: 48px; font-weight: bold; color: #1a1a1a; letter-spacing: 12px; font-family: 'Courier New', monospace; margin: 0;">
                      {{ .Token }}
                    </p>
                  </td>
                </tr>
              </table>
              
              <!-- Warning -->
              <table width="100%" cellpadding="0" cellspacing="0" style="margin: 20px 0;">
                <tr>
                  <td style="background-color: #fff3cd; border-left: 4px solid #ffc107; padding: 15px; border-radius: 4px;">
                    <p style="font-size: 14px; color: #856404; margin: 0;">
                      <strong>⏰ Atenção:</strong> Este código expira em <strong>10 minutos</strong>.
                    </p>
                  </td>
                </tr>
              </table>
              
              <p style="font-size: 16px; color: #666666; line-height: 1.6; margin: 20px 0 0 0;">
                Se você não solicitou este código, ignore este email.
                Sua conta permanecerá segura.
              </p>
            </td>
          </tr>
          
          <!-- Footer -->
          <tr>
            <td style="background-color: #f8f9fa; padding: 30px; text-align: center; border-top: 1px solid #dee2e6;">
              <p style="font-size: 14px; color: #6c757d; margin: 5px 0;">
                <strong>Spartan App</strong>
              </p>
              <p style="font-size: 14px; color: #6c757d; margin: 5px 0;">
                Sistema de Gerenciamento de Academia
              </p>
              <p style="font-size: 14px; color: #6c757d; margin: 20px 0 5px 0;">
                Este é um email automático. Por favor, não responda.
              </p>
            </td>
          </tr>
          
        </table>
      </td>
    </tr>
  </table>
</body>
</html>

/*
IMPORTANTE:
- {{ .Token }} será substituído automaticamente pelo código
- Não precisa de Edge Function
- Não precisa de serviço externo
- 100% GRATUITO
- Ilimitado
*/

-- ============================================
-- PASSO 2: CONFIGURAR SMTP (OPCIONAL)
-- ============================================

/*
Por padrão, Supabase usa seu próprio SMTP (gratuito).

Se quiser usar seu próprio domínio:
1. Vá em: Project Settings → Auth → SMTP Settings
2. Configure seu SMTP (Gmail, Outlook, etc)

GMAIL (GRATUITO):
- SMTP Host: smtp.gmail.com
- SMTP Port: 587
- SMTP User: seu-email@gmail.com
- SMTP Password: senha-de-app (não a senha normal)
- Sender Email: seu-email@gmail.com
- Sender Name: Spartan App

Como criar senha de app no Gmail:
1. Conta Google → Segurança
2. Verificação em duas etapas (ativar)
3. Senhas de app → Gerar
4. Copiar senha de 16 dígitos
*/

-- ============================================
-- PASSO 3: DESABILITAR CONFIRMAÇÃO AUTOMÁTICA
-- ============================================

/*
No Dashboard do Supabase:
1. Vá em: Authentication → Settings
2. Em "Email Auth":
   - ✅ Enable email confirmations: ON
   - ✅ Secure email change: ON
   - ❌ Double confirm email changes: OFF (opcional)
3. Em "Email Templates":
   - Customize "Confirm signup" template
*/

-- ============================================
-- RESUMO
-- ============================================

/*
✅ 100% GRATUITO
✅ Ilimitado
✅ Email customizado em português
✅ Sem necessidade de Edge Functions
✅ Sem necessidade de Resend
✅ Usa infraestrutura do Supabase
✅ Código de 4 dígitos destacado

CUSTO: R$ 0,00 para sempre!
*/
