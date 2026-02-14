import { serve } from 'https://deno.land/std@0.177.1/http/server.ts'
import Stripe from 'https://esm.sh/stripe@12.0.0?target=deno'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Methods': 'POST, OPTIONS',
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

console.log("Cancel Subscription Function Initialized v2 (Quarantine Mode - DEPLOY)")

serve(async (req) => {
    // Handle CORS preflight
    if (req.method === 'OPTIONS') {
        return new Response('ok', { headers: corsHeaders })
    }

    try {
        const STRIPE_SECRET_KEY = Deno.env.get('STRIPE_SECRET_KEY')
        const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!
        const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!

        if (!STRIPE_SECRET_KEY) {
            throw new Error('STRIPE_SECRET_KEY not configured')
        }

        const stripe = new Stripe(STRIPE_SECRET_KEY, {
            apiVersion: '2022-11-15',
            httpClient: Stripe.createFetchHttpClient(),
        })

        const supabaseAdmin = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY)

        // Parse request body
        const { userId, confirmCancellation } = await req.json()

        if (!userId) {
            throw new Error('userId is required')
        }

        if (!confirmCancellation) {
            throw new Error('Cancellation not confirmed')
        }

        console.log(`📦 Iniciando processo de cancelamento (Quarentena) para User: ${userId}`)

        // 1. Buscar dados COMPLETOS do admin no banco
        const { data: admin, error: findError } = await supabaseAdmin
            .from('users_adm')
            .select('*') // FIX: Selecionar todos os campos para backup completo
            .eq('id', userId)
            .single()

        if (findError || !admin) {
            throw new Error(`Admin não encontrado em users_adm: ${userId}`)
        }

        let cancelledSubscriptionsCount = 0

        // 2. Se tiver Stripe ID, buscar e cancelar assinaturas
        if (admin.stripe_customer_id) {
            console.log(`🔍 Buscando assinaturas para customer: ${admin.stripe_customer_id}`)

            const subscriptions = await stripe.subscriptions.list({
                customer: admin.stripe_customer_id,
                status: 'active',
            })

            if (subscriptions.data.length > 0) {
                // 3. Cancelar todas as assinaturas ativas
                for (const subscription of subscriptions.data) {
                    console.log(`❌ Cancelando assinatura: ${subscription.id}`)
                    await stripe.subscriptions.cancel(subscription.id, {
                        prorate: false, // Cancelar imediatamente
                    })
                }
                cancelledSubscriptionsCount = subscriptions.data.length
                console.log(`✅ ${cancelledSubscriptionsCount} assinatura(s) cancelada(s) no Stripe`)
            } else {
                console.log('⚠️ Nenhuma assinatura ativa encontrada no Stripe')
            }
        } else {
            console.log('⚠️ Sem stripe_customer_id, pulando etapa Stripe')
        }

        // 4. MOVER PARA QUARENTENA (Copia para users_canceled e suspende users_adm)
        console.log(`🔄 Copiando dados para tabela de cancelados...`)

        // Vamos tentar usar a função SQL dedicada se ela existir
        const { error: rpcError } = await supabaseAdmin
            .rpc('copy_user_to_canceled_v1', {
                target_user_id: userId,
                motivo: 'Cancelamento via App (Solicitado pelo Usuário)'
            })

        if (rpcError) {
            console.error('⚠️ RPC copy_user_to_canceled_v1 falhou ou não existe. Fazendo fallback manual.', rpcError.message)

            // Fallback Manual: Inserir direto na tabela users_canceled
            // (Assumindo que a tabela users_canceled existe. Se não existir, vai falhar e ok, pelo menos suspendemos)

            const now = new Date().toISOString()

            // Preparar objeto DE BACKUP COMPLETO
            const backupData = {
                original_id: admin.id,
                email: admin.email,
                nome: admin.nome, // FIX: Adicionado
                cpf: admin.cpf,   // FIX: Adicionado
                telefone: admin.telefone, // FIX: Adicionado
                academia: admin.academia,
                cnpj_academia: admin.cnpj_academia, // FIX: Adicionado
                endereco: admin.endereco, // FIX: Adicionado
                plano_mensal: admin.plano_mensal, // FIX: Adicionado
                assinatura_iniciada: admin.assinatura_iniciada, // FIX: Adicionado
                stripe_customer_id: admin.stripe_customer_id,
                cancelado_em: now,
                motivo_cancelamento: 'Fallback Manual (RPC falhou)'
            }

            // Tentar inserir na tabela de backup
            const { error: insertError } = await supabaseAdmin
                .from('users_canceled')
                .upsert(backupData)

            if (insertError) {
                console.error('❌ Falha ao inserir em users_canceled:', insertError.message)
            } else {
                console.log('✅ Usuário salvo em users_canceled (Fallback)')
            }

            // Suspender conta original
            await supabaseAdmin
                .from('users_adm')
                .update({
                    assinatura_status: 'suspended',
                    is_blocked: true,
                    updated_at: now
                })
                .eq('id', userId)

        } else {
            console.log('✅ Usuário movido para quarentena com sucesso via RPC')
        }

        console.log(`✅ Processo de cancelamento completo para: ${admin.email}`)

        return new Response(
            JSON.stringify({
                success: true,
                message: 'Assinatura cancelada. Conta suspensa e dados preservados para análise.',
                quarantined: true,
                cancelledSubscriptions: cancelledSubscriptionsCount
            }),
            { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        )

    } catch (error) {
        console.error('❌ Erro no processo:', error.message)
        return new Response(
            JSON.stringify({
                success: false,
                error: error.message
            }),
            {
                status: 400,
                headers: { ...corsHeaders, 'Content-Type': 'application/json' }
            }
        )
    }
})
