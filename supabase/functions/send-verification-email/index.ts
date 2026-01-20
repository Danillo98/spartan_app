// Supabase Edge Function para enviar email de verificação
// Deploy: supabase functions deploy send-verification-email

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"

const RESEND_API_KEY = Deno.env.get('RESEND_API_KEY')

const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

interface EmailRequest {
    email: string
    code: string
    name?: string
}

serve(async (req) => {
    // Handle CORS preflight requests
    if (req.method === 'OPTIONS') {
        return new Response('ok', { headers: corsHeaders })
    }

    try {
        const { email, code, name }: EmailRequest = await req.json()

        // Validar dados
        if (!email || !code) {
            throw new Error('Email e código são obrigatórios')
        }

        // Template de email em português
        const htmlContent = `
<!DOCTYPE html>
<html lang="pt-BR">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Código de Verificação - Spartan App</title>
  <style>
    body {
      font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
      background-color: #f4f4f4;
      margin: 0;
      padding: 0;
    }
    .container {
      max-width: 600px;
      margin: 40px auto;
      background-color: #ffffff;
      border-radius: 12px;
      overflow: hidden;
      box-shadow: 0 4px 20px rgba(0, 0, 0, 0.1);
    }
    .header {
      background: linear-gradient(135deg, #1a1a1a 0%, #2d2d2d 100%);
      padding: 40px 20px;
      text-align: center;
    }
    .logo {
      font-size: 32px;
      font-weight: bold;
      color: #ffffff;
      letter-spacing: 2px;
    }
    .content {
      padding: 40px 30px;
    }
    .greeting {
      font-size: 18px;
      color: #333333;
      margin-bottom: 20px;
    }
    .message {
      font-size: 16px;
      color: #666666;
      line-height: 1.6;
      margin-bottom: 30px;
    }
    .code-container {
      background: linear-gradient(135deg, #f8f9fa 0%, #e9ecef 100%);
      border: 2px solid #dee2e6;
      border-radius: 12px;
      padding: 30px;
      text-align: center;
      margin: 30px 0;
    }
    .code-label {
      font-size: 14px;
      color: #666666;
      text-transform: uppercase;
      letter-spacing: 1px;
      margin-bottom: 15px;
    }
    .code {
      font-size: 48px;
      font-weight: bold;
      color: #1a1a1a;
      letter-spacing: 12px;
      font-family: 'Courier New', monospace;
    }
    .warning {
      background-color: #fff3cd;
      border-left: 4px solid #ffc107;
      padding: 15px;
      margin: 20px 0;
      border-radius: 4px;
    }
    .warning-text {
      font-size: 14px;
      color: #856404;
      margin: 0;
    }
    .footer {
      background-color: #f8f9fa;
      padding: 30px;
      text-align: center;
      border-top: 1px solid #dee2e6;
    }
    .footer-text {
      font-size: 14px;
      color: #6c757d;
      margin: 5px 0;
    }
    .button {
      display: inline-block;
      background: linear-gradient(135deg, #1a1a1a 0%, #2d2d2d 100%);
      color: #ffffff;
      padding: 15px 40px;
      text-decoration: none;
      border-radius: 8px;
      font-weight: bold;
      margin: 20px 0;
    }
  </style>
</head>
<body>
  <div class="container">
    <div class="header">
      <div class="logo">⚡ SPARTAN APP</div>
    </div>
    
    <div class="content">
      <div class="greeting">
        Olá${name ? `, ${name}` : ''}! 👋
      </div>
      
      <div class="message">
        Você está a um passo de completar seu cadastro no <strong>Spartan App</strong>.
        Use o código abaixo para verificar seu email e ativar sua conta de administrador.
      </div>
      
      <div class="code-container">
        <div class="code-label">Seu Código de Verificação</div>
        <div class="code">${code}</div>
      </div>
      
      <div class="warning">
        <p class="warning-text">
          <strong>⏰ Atenção:</strong> Este código expira em <strong>10 minutos</strong>.
        </p>
      </div>
      
      <div class="message">
        Se você não solicitou este código, ignore este email.
        Sua conta permanecerá segura.
      </div>
    </div>
    
    <div class="footer">
      <p class="footer-text"><strong>Spartan App</strong></p>
      <p class="footer-text">Sistema de Gerenciamento de Academia</p>
      <p class="footer-text" style="margin-top: 20px;">
        Este é um email automático. Por favor, não responda.
      </p>
    </div>
  </div>
</body>
</html>
    `

        const textContent = `
Olá${name ? `, ${name}` : ''}!

Você está a um passo de completar seu cadastro no Spartan App.

Seu código de verificação é: ${code}

⏰ Este código expira em 10 minutos.

Se você não solicitou este código, ignore este email.

---
Spartan App
Sistema de Gerenciamento de Academia
    `

        // Enviar email usando Resend
        const res = await fetch('https://api.resend.com/emails', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'Authorization': `Bearer ${RESEND_API_KEY}`,
            },
            body: JSON.stringify({
                from: 'Spartan App <noreply@spartanapp.com>',
                to: [email],
                subject: `🔐 Seu código de verificação: ${code}`,
                html: htmlContent,
                text: textContent,
            }),
        })

        if (!res.ok) {
            const error = await res.text()
            throw new Error(`Erro ao enviar email: ${error}`)
        }

        const data = await res.json()

        return new Response(
            JSON.stringify({
                success: true,
                message: 'Email enviado com sucesso',
                data,
            }),
            {
                headers: { ...corsHeaders, 'Content-Type': 'application/json' },
                status: 200,
            },
        )
    } catch (error) {
        return new Response(
            JSON.stringify({
                success: false,
                error: error.message,
            }),
            {
                headers: { ...corsHeaders, 'Content-Type': 'application/json' },
                status: 400,
            },
        )
    }
})
