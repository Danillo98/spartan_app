import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  // Handle CORS
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const { email } = await req.json()

    // Criar cliente Supabase
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!
    const supabaseKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    const supabase = createClient(supabaseUrl, supabaseKey)

    // Chamar RPC para gerar token customizado
    const { data: rpcData, error: rpcError } = await supabase.rpc('request_password_reset', {
      user_email: email
    })

    if (rpcError) throw rpcError
    
    if (!rpcData || !rpcData.success) {
      throw new Error(rpcData?.message || 'Erro ao gerar token')
    }

    const resetLink = rpcData.reset_url

    // Template HTML do email em português
    const htmlContent = `
<!DOCTYPE html>
<html lang="pt-BR">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Recuperar Senha - Spartan App</title>
</head>
<body style="margin: 0; padding: 0; font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; background-color: #f5f5f5;">
  <table width="100%" cellpadding="0" cellspacing="0" style="background-color: #f5f5f5; padding: 40px 20px;">
    <tr>
      <td align="center">
        <table width="600" cellpadding="0" cellspacing="0" style="background-color: #ffffff; border-radius: 16px; overflow: hidden; box-shadow: 0 4px 20px rgba(0,0,0,0.1);">
          
          <!-- Header com gradiente preto -->
          <tr>
            <td style="background: linear-gradient(135deg, #1a1a1a 0%, #2d2d2d 100%); padding: 40px 30px; text-align: center;">
              <div style="background-color: rgba(255,255,255,0.1); width: 80px; height: 80px; border-radius: 50%; margin: 0 auto 20px; display: flex; align-items: center; justify-content: center;">
                <span style="font-size: 40px;">🔐</span>
              </div>
              <h1 style="color: #ffffff; margin: 0; font-size: 28px; font-weight: bold; letter-spacing: 2px;">SPARTAN APP</h1>
              <p style="color: rgba(255,255,255,0.8); margin: 10px 0 0; font-size: 14px;">Sistema de Gerenciamento de Academia</p>
            </td>
          </tr>

          <!-- Conteúdo -->
          <tr>
            <td style="padding: 40px 30px;">
              <h2 style="color: #1a1a1a; margin: 0 0 20px; font-size: 24px; font-weight: bold;">Recuperação de Senha</h2>
              
              <p style="color: #666; font-size: 16px; line-height: 1.6; margin: 0 0 20px;">
                Olá! 👋
              </p>

              <p style="color: #666; font-size: 16px; line-height: 1.6; margin: 0 0 20px;">
                Você solicitou a redefinição de senha da sua conta de <strong>Administrador</strong> no Spartan App.
              </p>

              <p style="color: #666; font-size: 16px; line-height: 1.6; margin: 0 0 30px;">
                Clique no botão abaixo para criar uma nova senha:
              </p>

              <!-- Botão -->
              <table width="100%" cellpadding="0" cellspacing="0">
                <tr>
                  <td align="center" style="padding: 20px 0;">
                    <a href="${resetLink}" style="background: linear-gradient(135deg, #1a1a1a 0%, #2d2d2d 100%); color: #ffffff; text-decoration: none; padding: 16px 40px; border-radius: 12px; font-size: 16px; font-weight: bold; letter-spacing: 1px; display: inline-block; box-shadow: 0 4px 15px rgba(26,26,26,0.3);">
                      REDEFINIR SENHA
                    </a>
                  </td>
                </tr>
              </table>

              <!-- Aviso de tempo -->
              <div style="background-color: #fff3cd; border-left: 4px solid #ffc107; padding: 15px; margin: 30px 0; border-radius: 8px;">
                <p style="color: #856404; margin: 0; font-size: 14px; line-height: 1.6;">
                  <strong>⏰ Atenção:</strong> Este link expira em <strong>1 hora</strong> por motivos de segurança.
                </p>
              </div>

              <!-- Link alternativo -->
              <p style="color: #999; font-size: 13px; line-height: 1.6; margin: 20px 0 0;">
                Se o botão não funcionar, copie e cole este link no seu navegador:
              </p>
              <p style="color: #666; font-size: 12px; word-break: break-all; background-color: #f5f5f5; padding: 10px; border-radius: 6px; margin: 10px 0 0;">
                ${resetLink}
              </p>

              <!-- Aviso de segurança -->
              <div style="background-color: #f8f9fa; border-radius: 8px; padding: 20px; margin: 30px 0 0;">
                <p style="color: #666; font-size: 14px; line-height: 1.6; margin: 0;">
                  <strong>🔒 Segurança:</strong> Se você não solicitou esta redefinição de senha, ignore este email. Sua senha permanecerá inalterada.
                </p>
              </div>
            </td>
          </tr>

          <!-- Footer -->
          <tr>
            <td style="background-color: #f8f9fa; padding: 30px; text-align: center; border-top: 1px solid #e0e0e0;">
              <p style="color: #999; font-size: 13px; margin: 0 0 10px;">
                Este é um email automático, por favor não responda.
              </p>
              <p style="color: #999; font-size: 13px; margin: 0;">
                © 2026 Spartan App. Todos os direitos reservados.
              </p>
            </td>
          </tr>

        </table>
      </td>
    </tr>
  </table>
</body>
</html>
    `

    // Enviar email usando Resend
    const resendApiKey = Deno.env.get('RESEND_API_KEY')

    if (!resendApiKey) {
      throw new Error('RESEND_API_KEY não configurada')
    }

    const res = await fetch('https://api.resend.com/emails', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${resendApiKey}`,
      },
      body: JSON.stringify({
        from: 'Spartan App <noreply@spartanapp.com>',
        to: [email],
        subject: '🔐 Recuperação de Senha - Spartan App',
        html: htmlContent,
      }),
    })

    const resendData = await res.json()

    if (!res.ok) {
      throw new Error(`Erro ao enviar email: ${JSON.stringify(resendData)}`)
    }

    return new Response(
      JSON.stringify({ success: true, message: 'Email enviado com sucesso!' }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )

  } catch (error) {
    return new Response(
      JSON.stringify({ error: error.message }),
      { 
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      }
    )
  }
})
