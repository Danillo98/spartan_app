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
        const type = body.type || body.topic; // Versão legado usava topic, v2 usa type
        const id = body.data?.id || body.resource?.id;

        if (!id) {
            return new Response("Sem id", { status: 400 });
        }

        const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY);

        // CASE 1: ASSINATURA CRIADA/ALTERADA (PREAPPROVAL)
        if (type === "preapproval") {
            const mpResponse = await fetch(`https://api.mercadopago.com/preapproval/${id}`, {
                headers: { Authorization: `Bearer ${MP_ACCESS_TOKEN}` },
            });
            const preapproval = await mpResponse.json();

            if (preapproval.status === "authorized") {
                const userId = preapproval.external_reference;
                if (userId) {
                    await supabase.from("users_adm").update({
                        mp_subscription_id: preapproval.id,
                        mp_customer_id: preapproval.payer_id,
                        payment_method: "card"
                    }).eq("id", userId);
                    console.log(`✅ Cartão assinado: ${preapproval.id} para usuário ${userId}`);
                }
            }
            return new Response("ok", { status: 200 });
        }

        // CASE 2: PAGAMENTO RECEBIDO (PIX OU RECORRÊNCIA DO CARTÃO)
        if (type === "payment" || type === "payment_v2") {
            // Consulta o status real do pagamento no Mercado Pago
            const mpResponse = await fetch(`https://api.mercadopago.com/v1/payments/${id}`, {
                headers: { Authorization: `Bearer ${MP_ACCESS_TOKEN}` },
            });

            const payment = await mpResponse.json();
            console.log(`Webhook MP: payment ${id} status=${payment.status}`);

            if (payment.status !== "approved") {
                // Se foi rejeitado ou cancelado e é um pagamento da assinatura
                if (payment.preapproval_id && (payment.status === "rejected" || payment.status === "cancelled")) {
                    const userId = payment.external_reference;
                    if (userId) {
                        // Opcional: Notificar o usuário que o pagamento falhou
                        console.log(`❌ Falha no pagamento da assinatura para usuário ${userId}`);
                    }
                }
                return new Response("ok", { status: 200 });
            }

            // Pagamento aprovado! Buscar o userId pelo external_reference
            const userId = payment.external_reference;
            if (!userId) {
                console.error("Sem external_reference no pagamento");
                return new Response("sem external_reference", { status: 400 });
            }

            const now = new Date();
            const expiresAt = new Date(now);
            expiresAt.setDate(expiresAt.getDate() + 30); // 30 dias após hoje

            const deletedAt = new Date(now);
            deletedAt.setDate(deletedAt.getDate() + 90); // 90 dias após hoje

            const planStr = payment.description
                ?.replace("Spartan App - Assinatura ", "")
                ?.replace("Spartan App - Plano ", "")
                ?.toLowerCase() ?? "prata";
            const planName = planStr.charAt(0).toUpperCase() + planStr.slice(1);

            const updatePayload: any = {
                assinatura_status: "active",
                plano_mensal: planName,
                assinatura_iniciada: now.toISOString(),
                assinatura_expirada: expiresAt.toISOString(),
                assinatura_deletada: deletedAt.toISOString(),
                is_blocked: false,
            };

            // Se o pagamento veio de uma assinatura, garantir que salvamos o ID
            if (payment.preapproval_id) {
                updatePayload.mp_subscription_id = payment.preapproval_id;
                updatePayload.payment_method = "card";
            }

            const { error } = await supabase
                .from("users_adm")
                .update(updatePayload)
                .eq("id", userId);

            if (error) {
                console.error("Erro ao atualizar Supabase:", error);
                return new Response(JSON.stringify({ error: error.message }), { status: 500 });
            }

            console.log(`✅ Assinatura do usuário ${userId} atualizada para plano ${planName} via ${updatePayload.payment_method || 'PIX'}`);
            return new Response("ok", { status: 200 });
        }

        return new Response("Tópico ignorado", { status: 200 });
    } catch (e) {
        console.error("Erro geral no webhook:", e);
        return new Response(`Erro: ${e.message}`, { status: 500 });
    }
});
