import { serve } from 'https://deno.land/std@0.177.1/http/server.ts'
import Stripe from 'https://esm.sh/stripe@12.0.0?target=deno'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

console.log("Stripe Webhook Function Initialized v3 (Fix CNPJ - DEPLOY)")

serve(async (req) => {
    const signature = req.headers.get('Stripe-Signature')

    // 1. Verificar Assinatura (Segurança Extrema)
    const STRIPE_WEBHOOK_SECRET = Deno.env.get('STRIPE_WEBHOOK_SECRET')
    const STRIPE_SECRET_KEY = Deno.env.get('STRIPE_SECRET_KEY')

    if (!STRIPE_WEBHOOK_SECRET || !STRIPE_SECRET_KEY) {
        return new Response('Server configuration error: Missing Secrets', { status: 500 })
    }

    const stripe = new Stripe(STRIPE_SECRET_KEY, {
        apiVersion: '2022-11-15',
        httpClient: Stripe.createFetchHttpClient(),
    })

    const bodyBuffer = await req.arrayBuffer()
    const bodyText = new TextDecoder().decode(bodyBuffer)

    let event;
    try {
        event = await stripe.webhooks.constructEventAsync(
            bodyText,
            signature!,
            STRIPE_WEBHOOK_SECRET
        )
    } catch (err) {
        console.error(`Webhook Signature Verification Failed: ${err.message}`)
        return new Response(`Webhook Error: ${err.message}`, { status: 400 })
    }

    // 2. Processar Eventos de Sessão de Checkout
    if (event.type === 'checkout.session.completed' || event.type === 'checkout.session.async_payment_succeeded') {
        const session = event.data.object
        const metadata = session.metadata

        // REGRA DE OURO: Só liberar se o pagamento estiver CONFIRMADO ('paid')
        if (session.payment_status !== 'paid') {
            console.log(`⏳ Pagamento pendente para o usuário ${metadata.user_id_auth} (Status: ${session.payment_status}). Aguardando confirmação real.`);
            return new Response(JSON.stringify({ received: true, status: 'pending' }), {
                headers: { 'Content-Type': 'application/json' },
            })
        }

        console.log(`💰 Pagamento CONFIRMADO via ${event.type}! User: ${metadata.user_id_auth}, Email: ${session.customer_details?.email}`)

        // 3. Inicializar Supabase Admin (Service Role)
        const supabaseUrl = Deno.env.get('SUPABASE_URL')!
        const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
        const supabaseAdmin = createClient(supabaseUrl, supabaseServiceKey)

        // 3.B Se houver email real para atualizar
        if (metadata.real_email_to_update) {
            console.log(`📧 Processando email para usuário ${metadata.user_id_auth}`);
            try {
                const { error: updateError } = await supabaseAdmin.auth.admin.updateUserById(
                    metadata.user_id_auth,
                    {
                        email: metadata.real_email_to_update,
                        email_confirm: true,
                    }
                );
                if (updateError) console.error('⚠️ Falha ao atualizar email:', updateError.message);
            } catch (detailsError) {
                console.error('⚠️ Erro ao atualizar email:', detailsError);
            }
        }

        // 4. Executar Lógica de Criação/Atualização da Academia (Upsert com Smart Merge)
        try {
            const [{ data: existingUser }, { data: pendingData }] = await Promise.all([
                supabaseAdmin.from('users_adm').select('*').eq('id', metadata.user_id_auth).maybeSingle(),
                supabaseAdmin.from('pending_registrations').select('*').eq('id', metadata.user_id_auth).maybeSingle()
            ]);

            const getField = (metaValue: any, pendingValue: any, dbValue: any, defaultValue: any) => {
                const isValid = (val: any) => val && val !== '' && val !== '00' && val !== 'undefined' && val !== 'null' && val !== null;
                if (isValid(metaValue)) return metaValue;
                if (isValid(pendingValue)) return pendingValue;
                if (isValid(dbValue)) return dbValue;
                return defaultValue;
            };

            const nomeFinal = getField(metadata.nome, pendingData?.full_name, existingUser?.nome, 'Admin');
            const emailFinal = session.customer_details?.email || getField(metadata.userEmail, pendingData?.email, existingUser?.email, null);
            const telefoneFinal = getField(metadata.telefone, pendingData?.phone, existingUser?.telefone, '00');
            const cpfFinal = getField(metadata.cpf_responsavel, pendingData?.cpf, existingUser?.cpf, '00');
            const academiaFinal = getField(metadata.academia, pendingData?.gym_name, existingUser?.academia, 'Academia');
            const cnpjFinal = getField(metadata.cnpj_academia, pendingData?.gym_cnpj || pendingData?.cnpj, existingUser?.cnpj_academia, '00');
            const enderecoFinal = getField(metadata.endereco, pendingData?.address_street, existingUser?.endereco, 'Endereço');
            const planoFinal = getField(metadata.plano_selecionado, null, existingUser?.plano_mensal, 'Prata');
            const stripeCustomerFinal = session.customer || existingUser?.stripe_customer_id;

            const now = new Date();
            const assinaturaIniciada = now.toISOString();

            const expiracaoDate = new Date(now); expiracaoDate.setDate(expiracaoDate.getDate() + 30);
            const assinaturaExpirada = expiracaoDate.toISOString();

            const delecaoDate = new Date(now); delecaoDate.setDate(delecaoDate.getDate() + 91);
            const assinaturaDeletada = delecaoDate.toISOString();

            const dbPayload = {
                id: metadata.user_id_auth,
                nome: nomeFinal,
                email: emailFinal,
                telefone: telefoneFinal,
                cpf: cpfFinal,
                academia: academiaFinal,
                cnpj_academia: cnpjFinal,
                endereco: enderecoFinal,
                plano_mensal: planoFinal,
                email_verified: true,
                is_blocked: false,
                updated_at: new Date().toISOString(),
                assinatura_status: 'active',
                assinatura_iniciada: assinaturaIniciada,
                assinatura_expirada: assinaturaExpirada,
                assinatura_deletada: assinaturaDeletada,
                stripe_customer_id: stripeCustomerFinal,
            };

            let { error: adminError } = await supabaseAdmin.from('users_adm').upsert(dbPayload);
            if (adminError) throw adminError;

            // Limpeza
            await supabaseAdmin.from('pending_registrations').delete().eq('id', metadata.user_id_auth);
            await supabaseAdmin.from('email_verification_codes').delete().eq('user_id', metadata.user_id_auth);
            await supabaseAdmin.from('users_canceled').delete().eq('user_id', metadata.user_id_auth);

        } catch (dbError) {
            console.error('Erro ao salvar no banco:', dbError)
            return new Response('Database Error', { status: 500 })
        }
    }

    // ============================================
    // EVENTO: PAGAMENTO FALHOU (invoice.payment_failed)
    // ============================================
    if (event.type === 'invoice.payment_failed') {
        // (Mantido igual - Lógica de Grace Period)
        const invoice = event.data.object;
        const customerId = invoice.customer;
        console.log(`❌ Pagamento Falhou! Customer: ${customerId}`);

        const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
        const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
        const supabaseAdmin = createClient(supabaseUrl, supabaseServiceKey);

        try {
            const { data: admin } = await supabaseAdmin.from('users_adm').select('id').eq('stripe_customer_id', customerId).single();
            if (admin) {
                await supabaseAdmin.from('users_adm').update({ assinatura_status: 'grace_period', updated_at: new Date().toISOString() }).eq('id', admin.id);
            }
        } catch (e) {
            console.error('Erro invoice.payment_failed:', e);
        }
    }

    // ============================================
    // EVENTO: ASSINATURA ATUALIZADA (customer.subscription.updated)
    // ============================================
    if (event.type === 'customer.subscription.updated') {
        const subscription = event.data.object;
        const customerId = subscription.customer;
        const stripeStatus = subscription.status;

        console.log(`🔄 Assinatura Atualizada! Customer: ${customerId}, Status: ${stripeStatus}`);

        const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
        const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
        const supabaseAdmin = createClient(supabaseUrl, supabaseServiceKey);

        try {
            let novoStatus = 'active';
            let isBlocked = false;

            switch (stripeStatus) {
                case 'active': novoStatus = 'active'; isBlocked = false; break;
                case 'past_due': novoStatus = 'grace_period'; isBlocked = false; break;
                case 'unpaid': case 'canceled': novoStatus = 'suspended'; isBlocked = true; break;
            }

            const { data: admin } = await supabaseAdmin.from('users_adm').select('*').eq('stripe_customer_id', customerId).single();

            if (admin) {
                let updatePayload: any = {
                    assinatura_status: novoStatus,
                    is_blocked: isBlocked,
                    updated_at: new Date().toISOString(),
                };

                // Se voltou a ser ativo, atualiza datas
                if (stripeStatus === 'active') {
                    const now = new Date();
                    const expiracaoDate = new Date(now); expiracaoDate.setDate(expiracaoDate.getDate() + 30);
                    const toleranciaDate = new Date(now); toleranciaDate.setDate(toleranciaDate.getDate() + 31);
                    const delecaoDate = new Date(now); delecaoDate.setDate(delecaoDate.getDate() + 91);

                    updatePayload = {
                        ...updatePayload,
                        assinatura_iniciada: now.toISOString(),
                        assinatura_expirada: expiracaoDate.toISOString(),
                        assinatura_deletada: delecaoDate.toISOString(),
                    };

                    // ADD: Remover da lista de cancelados ao reativar
                    await supabaseAdmin.from('users_canceled').delete().eq('user_id', admin.id);
                }

                await supabaseAdmin.from('users_adm').update(updatePayload).eq('id', admin.id);
                console.log(`✅ Status atualizado para ${novoStatus}: ${admin.id}`);
            }
        } catch (e) {
            console.error('Erro subscription.updated:', e);
        }
    }

    // ============================================
    // EVENTO: ASSINATURA CANCELADA (customer.subscription.deleted)
    // ============================================
    if (event.type === 'customer.subscription.deleted') {
        // (Mantido igual)
        const subscription = event.data.object;
        const customerId = subscription.customer;
        console.log(`🗑️ Assinatura Cancelada (Evento Stripe)! Customer: ${customerId}`);

        const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
        const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
        const supabaseAdmin = createClient(supabaseUrl, supabaseServiceKey);

        try {
            const { data: admin } = await supabaseAdmin.from('users_adm').select('id').eq('stripe_customer_id', customerId).single();
            if (admin) {
                const now = new Date();
                const delecaoDate = new Date(now);
                delecaoDate.setDate(delecaoDate.getDate() + 60);

                await supabaseAdmin.from('users_adm').update({
                    assinatura_status: 'suspended',
                    is_blocked: true,
                    assinatura_deletada: delecaoDate.toISOString(),
                    updated_at: now.toISOString(),
                }).eq('id', admin.id);
            }
        } catch (e) { console.error('Error subs deleted:', e); }
    }

    return new Response(JSON.stringify({ received: true }), {
        headers: { 'Content-Type': 'application/json' },
    })
})
