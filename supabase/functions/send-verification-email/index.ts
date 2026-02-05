import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

const RESEND_API_KEY = Deno.env.get('RESEND_API_KEY');

const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

serve(async (req) => {
    if (req.method === 'OPTIONS') {
        return new Response('ok', { headers: corsHeaders });
    }

    try {
        const { email, token, redirect_url } = await req.json();

        if (!email || !token) {
            throw new Error('Email e Token são obrigatórios');
        }

        const activationLink = `${redirect_url}?token=${token}`;

        console.log(`Tentando enviar email para: ${email} com token: ${token}`);

        const res = await fetch('https://api.resend.com/emails', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'Authorization': `Bearer ${RESEND_API_KEY}`,
            },
            body: JSON.stringify({
                from: 'Spartan App <contato@spartanapp.com.br>',
                to: [email],
                subject: '🎉 Bem-vindo ao Spartan App - Confirme seu Email',
                html: `
<!DOCTYPE html>
<html lang="pt-BR">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
</head>
<body style="margin: 0; padding: 0; font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; background-color: #f4f4f4;">
  <table width="100%" cellpadding="0" cellspacing="0" style="background-color: #f4f4f4; padding: 40px 20px;">
    <tr>
      <td align="center">
        <table width="600" cellpadding="0" cellspacing="0" style="background-color: #ffffff; border-radius: 16px; overflow: hidden; box-shadow: 0 4px 20px rgba(0, 0, 0, 0.1);">
          
          <!-- Header -->
          <tr>
            <td style="background: linear-gradient(135deg, #1a1a1a 0%, #2d2d2d 100%); padding: 50px 20px; text-align: center;">
              <h1 style="color: #ffffff; font-size: 36px; font-weight: bold; letter-spacing: 3px; margin: 0;">
                ⚡ SPARTAN APP
              </h1>
              <p style="color: #cccccc; font-size: 16px; margin: 10px 0 0 0;">
                Sistema de Gerenciamento de Academia
              </p>
            </td>
          </tr>
          
          <!-- Content -->
          <tr>
            <td style="padding: 50px 40px;">
              <h2 style="font-size: 24px; color: #333333; margin: 0 0 20px 0;">
                Bem-vindo! 🎉
              </h2>
              
              <p style="font-size: 16px; color: #666666; line-height: 1.8; margin: 0 0 30px 0;">
                Estamos muito felizes em ter você conosco! Você está a apenas um clique de ativar sua conta no Spartan App.
              </p>
              
              <p style="font-size: 16px; color: #666666; line-height: 1.8; margin: 0 0 30px 0;">
                Para confirmar seu email e ativar sua conta, clique no botão abaixo:
              </p>
              
              <!-- Button -->
              <table width="100%" cellpadding="0" cellspacing="0" style="margin: 40px 0;">
                <tr>
                  <td align="center">
                    <a href="${activationLink}" style="display: inline-block; background: linear-gradient(135deg, #1a1a1a 0%, #333333 100%); color: #ffffff; text-decoration: none; padding: 18px 50px; border-radius: 12px; font-size: 18px; font-weight: bold; box-shadow: 0 4px 15px rgba(0, 0, 0, 0.2);">
                      ✅ Confirmar Meu Email
                    </a>
                  </td>
                </tr>
              </table>
              
              <!-- Alternative Link -->
              <table width="100%" cellpadding="0" cellspacing="0" style="margin: 30px 0;">
                <tr>
                  <td style="background-color: #f8f9fa; padding: 20px; border-radius: 8px; border-left: 4px solid #1a1a1a;">
                    <p style="font-size: 14px; color: #666666; margin: 0 0 10px 0;">
                      <strong>Não consegue clicar no botão?</strong>
                    </p>
                    <p style="font-size: 13px; color: #666666; margin: 0;">
                      Copie e cole este link no seu navegador:
                    </p>
                    <p style="font-size: 13px; color: #0066cc; word-break: break-all; margin: 10px 0 0 0;">
                      ${activationLink}
                    </p>
                  </td>
                </tr>
              </table>
              
              <!-- Warning -->
              <table width="100%" cellpadding="0" cellspacing="0" style="margin: 30px 0;">
                <tr>
                  <td style="background-color: #fff3cd; border-left: 4px solid #ffc107; padding: 15px; border-radius: 4px;">
                    <p style="font-size: 14px; color: #856404; margin: 0;">
                      <strong>⏰ Importante:</strong> Este link expira em <strong>24 horas</strong>.
                    </p>
                  </td>
                </tr>
              </table>
              
              <p style="font-size: 16px; color: #666666; line-height: 1.8; margin: 30px 0 0 0;">
                Se você não solicitou este cadastro, pode ignorar este email com segurança.
              </p>
            </td>
          </tr>
          
          <!-- Footer -->
          <tr>
            <td style="background-color: #f8f9fa; padding: 40px; text-align: center; border-top: 1px solid #dee2e6;">
              <p style="font-size: 16px; color: #333333; font-weight: bold; margin: 0 0 10px 0;">
                Spartan App
              </p>
              <p style="font-size: 14px; color: #6c757d; margin: 5px 0;">
                Sistema de Gerenciamento de Academia
              </p>
              <p style="font-size: 14px; color: #6c757d; margin: 20px 0 5px 0;">
                Este é um email automático. Por favor, não responda.
              </p>
              <p style="font-size: 12px; color: #999999; margin: 20px 0 0 0;">
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
        `,
            }),
        });

        const data = await res.json();
        console.log('Resend Response:', data);

        return new Response(JSON.stringify({
            success: res.ok,
            data: data,
            link: activationLink
        }), {
            headers: { ...corsHeaders, 'Content-Type': 'application/json' },
            status: 200,
        });

    } catch (error) {
        console.error('Erro na Edge Function:', error.message);
        return new Response(JSON.stringify({ error: error.message }), {
            headers: { ...corsHeaders, 'Content-Type': 'application/json' },
            status: 200,
        });
    }
});

