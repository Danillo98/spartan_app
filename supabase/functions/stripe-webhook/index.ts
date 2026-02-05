import { serve } from 'https://deno.land/std@0.177.1/http/server.ts'
import Stripe from 'https://esm.sh/stripe@12.0.0?target=deno'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

console.log("Stripe Webhook Function Initialized")

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

    // Para validar webhook no Edge Runtime, precisamos do body como texto bruto
    // Mas como ler o body consome o stream, vamos ler como ArrayBuffer e decodificar
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

    // 2. Processar Evento "Checkout Completed"
    if (event.type === 'checkout.session.completed') {
        const session = event.data.object
        const metadata = session.metadata

        console.log(`💰 Pagamento Confirmado! User: ${metadata.user_id_auth}, Email: ${session.customer_details?.email}`)

        // 3. Inicializar Supabase Admin (Service Role)
        const supabaseUrl = Deno.env.get('SUPABASE_URL')!
        const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!

        const supabaseAdmin = createClient(supabaseUrl, supabaseServiceKey)

        // 3.B Se houver email real para atualizar (Fluxo de Email Tardio)
        if (metadata.real_email_to_update) {
            console.log(`📧 Processando email para usuário ${metadata.user_id_auth}`);

            let targetEmail = metadata.real_email_to_update;

            // Tentar atualizar email no Auth
            try {
                const { error: updateError } = await supabaseAdmin.auth.admin.updateUserById(
                    metadata.user_id_auth,
                    {
                        email: metadata.real_email_to_update,
                        email_confirm: true, // Confirma automaticamente
                    }
                );

                if (updateError) {
                    console.error('⚠️ Falha ao atualizar email (pode já estar em uso):', updateError.message);
                    // Se falhou, vamos buscar o email atual do usuário
                    const { data: userData } = await supabaseAdmin.auth.admin.getUserById(metadata.user_id_auth);
                    targetEmail = userData?.user?.email || targetEmail;
                    console.log(`Usando email atual do usuário: ${targetEmail}`);
                } else {
                    console.log('✅ Email atualizado com sucesso para:', metadata.real_email_to_update);
                }
            } catch (detailsError) {
                console.error('⚠️ Erro ao atualizar email:', detailsError);
            }
        }

        // 4. Executar Lógica de Criação da Academia (Upsert Robusto)
        try {
            console.log('Iniciando operação de banco para User ID:', metadata.user_id_auth);

            // A. Inserir/Atualizar Academia (Upsert)
            // Usamos upsert para garantir que se o usuario ja existe (ex: auth trigger), atualizamos os dados
            // Nota: users_adm geralmente tem id como Primary Key referenciando auth.users.id

            // TENTATIVA 1: Payload Completo
            const dbPayload = {
                id: metadata.user_id_auth,
                nome: metadata.nome,
                email: session.customer_details?.email || metadata.userEmail,
                telefone: metadata.telefone,
                cnpj_academia: metadata.cnpj_academia,
                cpf: metadata.cpf_responsavel,
                academia: metadata.academia,
                endereco: metadata.endereco,
                plano_mensal: metadata.plano_selecionado,
                email_verified: true,
                is_blocked: false,
                updated_at: new Date().toISOString()
            };

            console.log('Dados a inserir (TENTATIVA 1):', JSON.stringify(dbPayload));

            let { data: adminUser, error: adminError } = await supabaseAdmin
                .from('users_adm')
                .upsert(dbPayload)
                .select()
                .single();

            if (adminError) {
                console.error("ERRO TENTATIVA 1:", adminError);

                // TENTATIVA 2: Payload Mínimo (Salva-Vidas)
                console.log("Tentando Payload Mínimo para não travar cadastro...");
                const minimalPayload = {
                    id: metadata.user_id_auth,
                    nome: metadata.nome || 'Admin',
                    email: session.customer_details?.email || metadata.userEmail,
                    // Preencher campos not-null com placeholders se necessario
                    telefone: metadata.telefone || '00',
                    cnpj_academia: metadata.cnpj_academia || '00',
                    cpf: metadata.cpf_responsavel || '00',
                    academia: metadata.academia || 'Academia',
                    endereco: metadata.endereco || 'Endereço',
                    plano_mensal: metadata.plano_selecionado || 'padrao',
                    email_verified: true,
                    is_blocked: false
                };

                const { error: error2 } = await supabaseAdmin
                    .from('users_adm')
                    .upsert(minimalPayload);

                if (error2) {
                    console.error("ERRO TENTATIVA 2 (FATAL):", error2);
                    throw error2; // Desiste
                }
            }

            console.log('✅ SUCESSO! Usuário salvo na tabela users_adm:', adminUser.id);


            // B. Registrar Pagamento (Opcional, mas bom para histórico)
            // await supabaseAdmin.from('financial_transactions').insert(...)

        } catch (dbError) {
            console.error('Erro ao salvar no banco:', dbError)
            return new Response('Database Error', { status: 500 })
        }
    }

    return new Response(JSON.stringify({ received: true }), {
        headers: { 'Content-Type': 'application/json' },
    })
})
