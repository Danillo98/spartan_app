import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
    // Handle CORS
    if (req.method === 'OPTIONS') {
        return new Response('ok', { headers: corsHeaders })
    }

    try {
        // 1. Get input
        const { target_user_id } = await req.json()

        if (!target_user_id) {
            throw new Error('target_user_id is required')
        }

        // 2. Initialize Supabase Admin Client
        const supabaseAdmin = createClient(
            Deno.env.get('SUPABASE_URL') ?? '',
            Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
            {
                auth: {
                    autoRefreshToken: false,
                    persistSession: false
                }
            }
        )

        console.log(`🗑️ Iniciando exclusão do usuário: ${target_user_id}`)

        // 3. Call the RPC 'delete_user_complete' using Service Role
        // This ensures we bypass RLS and have full privileges
        const { error: rpcError } = await supabaseAdmin
            .rpc('delete_user_complete', { target_user_id: target_user_id })

        if (rpcError) {
            console.error('❌ Erro na RPC delete_user_complete:', rpcError)
            throw rpcError
        }

        // If RPC includes "delete from auth.users", we are good.
        // If we want to be double sure, we can try deleting from auth.admin here too, 
        // but the RPC usually handles it transactionally.
        // Let's rely on the RPC for atomicity.

        console.log('✅ Usuário excluído com sucesso via RPC (Edge Function)')

        return new Response(
            JSON.stringify({ success: true, message: 'Usuário excluído com sucesso' }),
            {
                headers: { ...corsHeaders, 'Content-Type': 'application/json' },
                status: 200,
            }
        )

    } catch (error) {
        console.error('❌ Erro no Edge Function:', error.message)
        return new Response(
            JSON.stringify({ success: false, error: error.message }),
            {
                headers: { ...corsHeaders, 'Content-Type': 'application/json' },
                status: 400,
            }
        )
    }
})
