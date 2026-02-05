import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

console.log("Check Payment Status Function Initialized")

serve(async (req) => {
    const corsHeaders = {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
    }

    if (req.method === 'OPTIONS') {
        return new Response('ok', { headers: corsHeaders })
    }

    try {
        const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? ''
        const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''

        if (!supabaseUrl || !supabaseServiceKey) {
            throw new Error('Variáveis de ambiente ausentes.')
        }

        // Cliente Admin para ignorar RLS
        const supabaseAdmin = createClient(supabaseUrl, supabaseServiceKey)

        // Tentar ler o body com segurança
        let userId;
        try {
            const body = await req.json();
            userId = body.userId;
        } catch (e) {
            throw new Error('Corpo da requisição inválido ou vazio.');
        }

        if (!userId) {
            throw new Error('UserId obrigatório.');
        }

        // Verificar na tabela users_adm
        const { data, error } = await supabaseAdmin
            .from('users_adm')
            .select('id')
            .eq('id', userId)
            .maybeSingle()

        if (error) {
            throw error
        }

        const exists = !!data;
        console.log(`Check Status User ${userId}: ${exists ? 'ENCONTRADO' : 'NÃO ENCONTRADO'}`);

        return new Response(
            JSON.stringify({ confirmed: exists }),
            {
                headers: { ...corsHeaders, 'Content-Type': 'application/json' },
                status: 200,
            },
        )

    } catch (error) {
        console.error('Erro no check-status:', error)
        return new Response(
            JSON.stringify({ error: error.message }),
            {
                headers: { ...corsHeaders, 'Content-Type': 'application/json' },
                status: 200, // Retornamos 200 para o polling saber que a função respondeu (o erro vem no JSON)
            },
        )
    }
})
