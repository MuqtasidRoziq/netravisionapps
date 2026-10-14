import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": Deno.env.get("CORS_ALLOWED_ORIGIN") || "null",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const authorization = req.headers.get("Authorization") || "";
    const expectedSecret = Deno.env.get("ALERT_FUNCTION_SECRET");
    if (!expectedSecret || authorization !== `Bearer ${expectedSecret}`) {
      return new Response(
        JSON.stringify({ error: "Tidak terautorisasi" }),
        { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    const { requestId, userName, description } = await req.json();

    const fonnteToken = Deno.env.get("FONNTE_TOKEN");
    const targetGroup = Deno.env.get("WHATSAPP_TARGET_GROUP_ID") || "";

    const message = `🚨 *PANGGILAN BANTUAN NETRAVISION*\n` +
      `👤 *Pengguna:* ${userName || 'Pengguna Netra'}\n` +
      `🎯 *Kebutuhan:* ${description || 'Bantuan Visual'}\n` +
      `⏰ *Waktu:* ${new Date().toLocaleTimeString('id-ID')}\n\n` +
      `👉 *Klik tautan ini untuk menjawab panggilan:*\n` +
      `https://netravision-portal.vercel.app/?session=${requestId}`;

    let gatewayResult = null;

    if (fonnteToken && targetGroup) {
      // Kirim via Fonnte WhatsApp API Gateway
      const fonnteRes = await fetch("https://api.fonnte.com/send", {
        method: "POST",
        headers: {
          "Authorization": fonnteToken,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          target: targetGroup,
          message: message,
        }),
      });
      gatewayResult = await fonnteRes.json();
    }

    return new Response(
      JSON.stringify({
        success: true,
        message,
        joinUrl: `https://netravision-portal.vercel.app/?session=${requestId}`,
        gatewayResult,
      }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  } catch (error) {
    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
