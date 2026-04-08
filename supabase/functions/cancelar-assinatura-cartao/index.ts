import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

const MP_ACCESS_TOKEN = Deno.env.get("MP_ACCESS_TOKEN") ?? "";
const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

Deno.serve(async (req: Request) => {
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
    const { subscriptionId, userId } = await req.json();

    if (!subscriptionId || !userId) {
      return new Response(JSON.stringify({ error: "Dados insuficientes" }), {
        status: 400,
        headers: { "Content-Type": "application/json" },
      });
    }

    // Cancelar no Mercado Pago
    // Documentação: https://www.mercadopago.com.br/developers/pt/reference/subscriptions/_preapproval/put
    const response = await fetch(`https://api.mercadopago.com/preapproval/${subscriptionId}`, {
      method: "PUT",
      headers: {
        "Authorization": `Bearer ${MP_ACCESS_TOKEN}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        status: "cancelled",
      }),
    });

    const data = await response.json();

    if (data.status === "cancelled" || data.status === "paused") {
      // Atualizar banco de dados para limpar as referências da assinatura
      const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY);
      
      const { error } = await supabase
        .from("users_adm")
        .update({
          mp_subscription_id: null,
          payment_method: "pix", // Volta para pix para renovações manuais futuras
        })
        .eq("id", userId);

      if (error) {
        console.error("Erro Supabase:", error);
      }

      return new Response(JSON.stringify({ success: true, message: "Assinatura cancelada com sucesso" }), {
        headers: {
          "Access-Control-Allow-Origin": "*",
          "Content-Type": "application/json"
        },
      });
    } else {
      console.error("Erro MP:", data);
      return new Response(JSON.stringify({ success: false, error: data.message || "Erro ao cancelar assinatura" }), {
        status: 400,
        headers: { "Content-Type": "application/json" },
      });
    }
  } catch (e) {
    return new Response(JSON.stringify({ error: e.message }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }
});
