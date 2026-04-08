import "jsr:@supabase/functions-js/edge-runtime.d.ts";

const MP_ACCESS_TOKEN = Deno.env.get("MP_ACCESS_TOKEN") ?? "";

Deno.serve(async (req: Request) => {
  // CORS preflight
  if (req.method === "OPTIONS") {
    return new Response("ok", {
      headers: {
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Methods": "POST, OPTIONS",
        "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
      },
    });
  }

  try {
    const body = await req.json();
    const { userId, userEmail, planName, amount, externalReference } = body;

    if (!userId || !amount) {
      return new Response(JSON.stringify({ error: "userId e amount são obrigatórios" }), {
        status: 400,
        headers: { "Content-Type": "application/json" },
      });
    }

    // Cria a intenção de Assinatura Recorrente no Mercado Pago
    // Documentação: https://www.mercadopago.com.br/developers/pt/docs/subscriptions/integration-guide/checkout
    const mpPayload = {
      payer_email: userEmail,
      back_url: "https://google.com/", // Onde redirecionar após o pagamento (pode ser o app deep link)
      reason: `Spartan App - Plano ${planName}`,
      external_reference: externalReference ?? userId,
      auto_recurring: {
        frequency: 1,
        frequency_type: "months",
        transaction_amount: Number(amount),
        currency_id: "BRL",
      },
    };

    const mpResponse = await fetch("https://api.mercadopago.com/preapproval", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${MP_ACCESS_TOKEN}`,
      },
      body: JSON.stringify(mpPayload),
    });

    const mpData = await mpResponse.json();

    if (!mpResponse.ok) {
      console.error("Erro MP Preapproval:", mpData);
      return new Response(JSON.stringify({ error: "Erro ao gerar url de assinatura", detalhes: mpData }), {
        status: 500,
        headers: { "Content-Type": "application/json" },
      });
    }

    return new Response(
      JSON.stringify({
        success: true,
        init_point: mpData.init_point, // Link para o qual o usuário será redirecionado para inserir o cartão
        preapproval_id: mpData.id,
      }),
      {
        headers: {
          "Content-Type": "application/json",
          "Access-Control-Allow-Origin": "*",
        },
      }
    );
  } catch (e) {
    console.error("Erro geral:", e);
    return new Response(JSON.stringify({ error: `Erro interno: ${e}` }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }
});
