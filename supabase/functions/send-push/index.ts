import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.0.0";
// Import JWT to sign service account tokens manually if needed, or use a library.
// For simplicity and robustness with V1, we use 'firebase-admin' via CDN or Google Auth library.
// Deno + Firebase Admin is tricky. We'll use a direct REST call with a signed JWT.
import { crypto } from "https://deno.land/std@0.177.0/crypto/mod.ts";
import { encode as base64url } from "https://deno.land/std@0.177.0/encoding/base64url.ts";

const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

// 1. Load Service Account from Env Var
const SERVICE_ACCOUNT = JSON.parse(Deno.env.get('FIREBASE_SERVICE_ACCOUNT') || '{}');

async function getAccessToken() {
    const iat = Math.floor(Date.now() / 1000);
    const exp = iat + 3600;

    const header = { alg: "RS256", typ: "JWT" };
    const claimSet = {
        iss: SERVICE_ACCOUNT.client_email,
        scope: "https://www.googleapis.com/auth/firebase.messaging",
        aud: "https://oauth2.googleapis.com/token",
        exp: exp,
        iat: iat,
    };

    const encodedHeader = base64url(new TextEncoder().encode(JSON.stringify(header)));
    const encodedClaimSet = base64url(new TextEncoder().encode(JSON.stringify(claimSet)));

    // Sign with Private Key
    // Note: Deno Web Crypto API for RS256 requires importing the key first.

    // PEM to Binary
    const pemHeader = "-----BEGIN PRIVATE KEY-----";
    const pemFooter = "-----END PRIVATE KEY-----";
    const pemContents = SERVICE_ACCOUNT.private_key
        .substring(pemHeader.length, SERVICE_ACCOUNT.private_key.length - pemFooter.length)
        .replaceAll('\n', '');

    const binaryKey = Uint8Array.from(atob(pemContents), c => c.charCodeAt(0));

    const key = await crypto.subtle.importKey(
        "pkcs8",
        binaryKey,
        { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
        false,
        ["sign"]
    );

    const signature = await crypto.subtle.sign(
        "RSASSA-PKCS1-v1_5",
        key,
        new TextEncoder().encode(`${encodedHeader}.${encodedClaimSet}`)
    );

    const encodedSignature = base64url(new Uint8Array(signature));
    const jwt = `${encodedHeader}.${encodedClaimSet}.${encodedSignature}`;

    // Exchange JWT for Access Token
    const res = await fetch("https://oauth2.googleapis.com/token", {
        method: "POST",
        headers: { "Content-Type": "application/x-www-form-urlencoded" },
        body: `grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer&assertion=${jwt}`,
    });

    const data = await res.json();
    return data.access_token;
}

serve(async (req) => {
    if (req.method === 'OPTIONS') {
        return new Response('ok', { headers: corsHeaders });
    }

    try {
        const { title, body, userIds, topic, data } = await req.json();
        const supabase = createClient(
            Deno.env.get('SUPABASE_URL') ?? '',
            Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
        );

        const accessToken = await getAccessToken();

        // Determine Targets (Tokens or Topic)
        let tokens = [];
        if (userIds && userIds.length > 0) {
            const { data: userTokens } = await supabase
                .from('user_fcm_tokens')
                .select('fcm_token')
                .in('user_id', userIds);

            if (userTokens) tokens = userTokens.map(t => t.fcm_token);
        }

        // Send Logic (V1 HTTP API)
        const projectId = SERVICE_ACCOUNT.project_id;
        const fcmUrl = `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`;

        const sendToTarget = async (targetParam) => {
            const message = {
                message: {
                    notification: { title, body },
                    data: data || {},
                    ...targetParam
                }
            };

            await fetch(fcmUrl, {
                method: 'POST',
                headers: {
                    'Authorization': `Bearer ${accessToken}`,
                    'Content-Type': 'application/json',
                },
                body: JSON.stringify(message)
            });
        };

        if (topic) {
            await sendToTarget({ topic: topic });
        } else {
            // Send to each token individually (V1 doesn't support multicast natively like legacy)
            // For mass sending, use batch methods or topic.
            const promises = tokens.map(token => sendToTarget({ token: token }));
            await Promise.all(promises);
        }

        return new Response(JSON.stringify({ status: 'sent' }), {
            headers: { ...corsHeaders, 'Content-Type': 'application/json' },
            status: 200,
        });

    } catch (error) {
        return new Response(JSON.stringify({ error: error.message }), {
            headers: { ...corsHeaders, 'Content-Type': 'application/json' },
            status: 400,
        });
    }
});
