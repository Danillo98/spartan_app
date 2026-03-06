import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

const MP_ACCESS_TOKEN = Deno.env.get("MP_ACCESS_TOKEN") ?? "";
const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

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
        const topic = body.type;       // "payment"
        const paymentId = body.data?.id; // ID do pagamento

        if (!paymentId) {
            return new Response("Sem paymentId", { status: 400 });
        }

        // Consulta o status real do pagamento no Mercado Pago
        const mpResponse = await fetch(`https://api.mercadopago.com/v1/payments/${paymentId}`, {
            headers: { Authorization: `Bearer ${MP_ACCESS_TOKEN}` },
        });

        const payment = await mpResponse.json();
        console.log(`Webhook MP: payment ${paymentId} status=${payment.status}`);

        if (payment.status !== "approved") {
            // Ainda não aprovado, apenas confirmar recebimento
            return new Response("ok", { status: 200 });
        }

        // Pagamento aprovado! Buscar o userId pelo external_reference
        const userId = payment.external_reference;
        if (!userId) {
            console.error("Sem external_reference no pagamento");
            return new Response("sem external_reference", { status: 400 });
        }

        // Conecta ao Supabase com a Service Role Key (acesso total)
        const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY);

        // Atualiza o status da assinatura do usuário
        // (Adapte conforme sua tabela de usuários no Supabase)
        const now = new Date();
        const expiresAt = new Date(now);
        expiresAt.setDate(expiresAt.getDate() + 30); // 30 dias após hoje

        const deletedAt = new Date(now);
        deletedAt.setDate(deletedAt.getDate() + 90); // 90 dias após hoje

        const planStr = payment.description
            ?.replace("Spartan App - Plano ", "")
            ?.toLowerCase() ?? "prata";
        const planName = planStr.charAt(0).toUpperCase() + planStr.slice(1);

        const { error } = await supabase
            .from("users_adm")
            .update({
                assinatura_status: "active",
                plano_mensal: planName,
                assinatura_iniciada: now.toISOString(),
                assinatura_expirada: expiresAt.toISOString(),
                assinatura_deletada: deletedAt.toISOString(),
                is_blocked: false,
            })
            .eq("id", userId);

        if (error) {
            console.error("Erro ao atualizar Supabase:", error);
            return new Response(JSON.stringify({ error: error.message }), { status: 500 });
        }

        console.log(`✅ Assinatura do usuário ${userId} atualizada para plano ${planName}`);
        return new Response("ok", { status: 200 });
    } catch (e) {
        console.error("Erro geral no webhook:", e);
        return new Response(`Erro: ${e}`, { status: 500 });
    }
});
