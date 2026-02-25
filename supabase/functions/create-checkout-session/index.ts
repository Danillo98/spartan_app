import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import Stripe from 'https://esm.sh/stripe@12.0.0?target=deno'

console.log("Create Checkout Session Function Initialized - v2.3.3 DEPLOY")

serve(async (req) => {
  // 1. CORS Headers
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
    const STRIPE_SECRET_KEY = Deno.env.get('STRIPE_SECRET_KEY')
    if (!STRIPE_SECRET_KEY) {
      throw new Error('STRIPE_SECRET_KEY não encontrada nas variáveis de ambiente.')
    }

    const stripe = new Stripe(STRIPE_SECRET_KEY, {
      apiVersion: '2022-11-15',
      httpClient: Stripe.createFetchHttpClient(),
    })

    // 4. Ler dados enviados pelo App
    const { priceId, userId, userEmail, userMetadata, origin } = await req.json()

    if (!priceId || !userId) {
      throw new Error('Parâmetros obrigatórios: priceId e userId.')
    }

    const baseUrl = origin || 'https://spartanapp.com.br';
    const successUrl = `${baseUrl}/success_payment.html`;
    const cancelUrl = `${baseUrl}/`;

    console.log(`Gerando checkout para User: ${userId}, Plano: ${priceId}, Origin: ${baseUrl}`)

    // 5. Criar Sessão no Stripe
    const session = await stripe.checkout.sessions.create({
      // card e boleto habilitados. pix removido até aparecer no painel.
      payment_method_types: ['card', 'boleto'],
      allow_promotion_codes: true,
      line_items: [
        {
          price: priceId,
          quantity: 1,
        },
      ],
      mode: 'subscription',

      success_url: successUrl,
      cancel_url: cancelUrl,

      customer_email: userEmail,

      metadata: {
        user_id_auth: userId,
        ...userMetadata
      },
      subscription_data: {
        metadata: {
          user_id_auth: userId
        }
      }
    })

    console.log(`Sessão criada: ${session.id}, URL: ${session.url}`)

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
