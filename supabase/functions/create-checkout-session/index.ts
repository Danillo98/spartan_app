import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import Stripe from 'https://esm.sh/stripe@12.0.0?target=deno'

console.log("Create Checkout Session Function Initialized - v3 FORCE DEPLOY")

serve(async (req) => {
  // 1. CORS Headers (Essencial para o Flutter conseguir chamar)
  const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  }

  // 2. Pre-flight request (OPTIONS)
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    // 3. Setup Stripe
    // A chave vem das Secrets que você configurou no Painel
    const STRIPE_SECRET_KEY = Deno.env.get('STRIPE_SECRET_KEY')
    if (!STRIPE_SECRET_KEY) {
      throw new Error('STRIPE_SECRET_KEY não encontrada nas variáveis de ambiente.')
    }

    const stripe = new Stripe(STRIPE_SECRET_KEY, {
      apiVersion: '2022-11-15',
      httpClient: Stripe.createFetchHttpClient(),
    })

    // 4. Ler dados enviados pelo App
    // origin: URL base de quem chamou (ex: http://localhost:5500 ou https://meuapp.com)
    const { priceId, userId, userEmail, userMetadata, origin } = await req.json()

    if (!priceId || !userId) {
      throw new Error('Parâmetros obrigatórios: priceId e userId.')
    }

    // Define success URL dinamicamente ou fallback
    const baseUrl = origin || 'https://spartanapp.com.br';
    const successUrl = `${baseUrl}/success_payment.html`;
    const cancelUrl = `${baseUrl}/`; // Volta pra home se cancelar

    console.log(`Gerando checkout para User: ${userId}, Plano: ${priceId}, Origin: ${baseUrl}`)

    // 5. Criar Sessão no Stripe
    const session = await stripe.checkout.sessions.create({
      payment_method_types: ['card'], // Adicione 'boleto' se quiser (precisa ativar no dashboard do Stripe)
      line_items: [
        {
          price: priceId,
          quantity: 1,
        },
      ],
      mode: 'subscription', // Assinatura recorrente

      // URLs de retorno para o usuário
      success_url: successUrl, // Página de "Obrigado"
      cancel_url: cancelUrl,   // Página de "Cancelou"

      customer_email: userEmail, // Preenche o email automaticamente no checkout

      // 6. METADADOS CRUCIAIS
      // Aqui "escondemos" os dados do cadastro para recuperar no Webhook depois
      metadata: {
        user_id_auth: userId,       // ID do Auth para vincular
        ...userMetadata             // Nome, CNPJ, Telefone do form
      },
      subscription_data: {
        metadata: {
          user_id_auth: userId      // Redundância na assinatura também
        }
      }
    })

    console.log(`Sessão criada: ${session.id}, URL: ${session.url}`)

    // 7. Retornar URL para o App
    return new Response(
      JSON.stringify({ url: session.url }),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 200,
      },
    )

  } catch (error) {
    console.error('Erro na function:', error.message)
    return new Response(
      JSON.stringify({ error: error.message }),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 400,
      },
    )
  }
})
