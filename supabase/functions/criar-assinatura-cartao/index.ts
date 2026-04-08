import "jsr:@supabase/functions-js/edge-runtime.d.ts";

// Links de checkout dos Planos criados no Mercado Pago
// Formato: /subscriptions/checkout?preapproval_plan_id=PLAN_ID
const PLAN_CHECKOUT_URLS: Record<string, string> = {
  prata:    "https://www.mercadopago.com.br/subscriptions/checkout?preapproval_plan_id=e1267c1b6f98490cb8c3f4e8216ef66a",
  ouro:     "https://www.mercadopago.com.br/subscriptions/checkout?preapproval_plan_id=619a262122fe4e209685136c833bfec0",
  platina:  "https://www.mercadopago.com.br/subscriptions/checkout?preapproval_plan_id=44b11288134d40aeaa699dac9362a6c3",
  diamante: "https://www.mercadopago.com.br/subscriptions/checkout?preapproval_plan_id=cad3033195b34b07958a90ee4ed93fc3",
};

// Headers CORS aplicados em TODOS os responses
const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Content-Type": "application/json",
};

function jsonResponse(data: unknown, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: corsHeaders,
  });
}

Deno.serve(async (req: Request) => {
  // 1. CORS Preflight
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    let body: { planName?: string; userId?: string; userEmail?: string };
    try {
      body = await req.json();
    } catch {
      return jsonResponse({ error: "Body inválido (JSON esperado)" }, 400);
    }

    const { planName, userId, userEmail } = body;

    if (!planName || !userId || !userEmail) {
      return jsonResponse(
        { error: "Campos obrigatórios: planName, userId, userEmail" },
        400
      );
    }

    const planKey = planName.toLowerCase().trim();
    const baseCheckoutUrl = PLAN_CHECKOUT_URLS[planKey];

    if (!baseCheckoutUrl) {
      return jsonResponse({ error: `Plano inválido: "${planName}"` }, 400);
    }

    // Adiciona email e referência externa ao link de checkout
    // para pré-preencher o formulário e identificar o usuário no webhook
    const checkoutUrl = `${baseCheckoutUrl}&payer_email=${encodeURIComponent(userEmail)}&external_reference=${encodeURIComponent(userId)}`;

    console.log(`Checkout URL gerada para plano "${planKey}" | userId: ${userId}`);

    return jsonResponse({
      success: true,
      init_point: checkoutUrl,
    });
  } catch (e) {
    const msg = e instanceof Error ? e.message : String(e);
    console.error("Erro na Edge Function:", msg);
    return jsonResponse({ error: msg }, 500);
  }
});
