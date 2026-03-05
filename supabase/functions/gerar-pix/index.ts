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

    // Gera o pagamento PIX no Mercado Pago
    // Documentação: https://www.mercadopago.com.br/developers/pt/reference/payments/resource/
    const mpPayload = {
      transaction_amount: Number(amount),
      description: `Spartan App - Plano ${planName}`,
      payment_method_id: "pix",
      payer: {
        email: userEmail,
        identification: {
          type: "CPF",
          number: "00000000000", // Será preenchido pelo usuário na tela
        },
      },
      external_reference: externalReference ?? userId,
      notification_url: `https://waczgosbsrorcibwfayv.supabase.co/functions/v1/webhook-mercadopago`,
    };

    const mpResponse = await fetch("https://api.mercadopago.com/v1/payments", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${MP_ACCESS_TOKEN}`,
        "X-Idempotency-Key": `spartan-${userId}-${Date.now()}`,
      },
      body: JSON.stringify(mpPayload),
    });

    const mpData = await mpResponse.json();

    if (!mpResponse.ok) {
      console.error("Erro MP:", mpData);
      return new Response(JSON.stringify({ error: "Erro ao gerar PIX", detalhes: mpData }), {
        status: 500,
        headers: { "Content-Type": "application/json" },
      });
    }

    // Extrai os dados do PIX para retornar ao app
    const pixData = mpData.point_of_interaction?.transaction_data;

    return new Response(
      JSON.stringify({
        success: true,
        paymentId: mpData.id,
        status: mpData.status,
        qrCode: pixData?.qr_code,           // Código "Copia e Cola"
        qrCodeBase64: pixData?.qr_code_base64, // Imagem do QR Code
        amount: mpData.transaction_amount,
        expiresAt: mpData.date_of_expiration,
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
