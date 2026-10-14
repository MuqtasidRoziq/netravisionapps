import { AccessToken } from "npm:livekit-server-sdk@1.2.7";

const corsHeaders = {
  // Atur daftar origin produksi melalui CORS_ALLOWED_ORIGIN. Aplikasi native
  // tidak mengirim Origin sehingga tetap dapat memanggil fungsi ini.
  "Access-Control-Allow-Origin": Deno.env.get("CORS_ALLOWED_ORIGIN") || "null",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

export default {
  async fetch(req: Request) {
    if (req.method === "OPTIONS") {
      return new Response("ok", { headers: corsHeaders });
    }

    try {
      const authorization = req.headers.get("Authorization") || "";
      const supabaseUrl = Deno.env.get("SUPABASE_URL");
      const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY");
      if (!authorization.startsWith("Bearer ") || !supabaseUrl || !supabaseAnonKey) {
        return new Response(
          JSON.stringify({ error: "Autentikasi pengguna diperlukan" }),
          { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } },
        );
      }

      // Anon key adalah JWT publik yang valid secara teknis, tetapi bukan
      // identitas pengguna. Verifikasi ke Auth dan tolak role anon.
      const userResponse = await fetch(`${supabaseUrl}/auth/v1/user`, {
        headers: {
          "apikey": supabaseAnonKey,
          "Authorization": authorization,
        },
      });
      const user = userResponse.ok ? await userResponse.json() : null;
      if (!user?.id || user?.role === "anon") {
        return new Response(
          JSON.stringify({ error: "Sesi pengguna tidak valid" }),
          { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } },
        );
      }

      const { roomName, identity, name } = await req.json();

      // Membatasi format agar token tidak dapat dipakai untuk room sistem atau
      // room arbitrer di proyek LiveKit yang sama.
      if (
        typeof roomName !== "string" ||
        !/^room_req_[A-Za-z0-9_-]{8,128}$/.test(roomName) ||
        typeof identity !== "string" ||
        identity.length < 3 ||
        identity.length > 128
      ) {
        return new Response(
          JSON.stringify({ error: "Parameter room atau identitas tidak valid" }),
          { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }

      const apiKey = Deno.env.get("LIVEKIT_API_KEY");
      const apiSecret = Deno.env.get("LIVEKIT_API_SECRET");
      const livekitUrl = Deno.env.get("LIVEKIT_URL") || "wss://netravision-ibcqale8.livekit.cloud";

      if (!apiKey || !apiSecret) {
        return new Response(
          JSON.stringify({ error: "Secret LIVEKIT_API_KEY / LIVEKIT_API_SECRET belum tersedia" }),
          { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }

      const at = new AccessToken(apiKey, apiSecret, {
        identity,
        name: name || identity,
        ttl: "10m",
      });

      at.addGrant({
        roomJoin: true,
        room: roomName,
        canPublish: true,
        canSubscribe: true,
        canPublishData: true,
      });

      const token = await at.toJwt();

      return new Response(
        JSON.stringify({ token, livekitUrl }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    } catch (error) {
      return new Response(
        JSON.stringify({ error: (error as Error).message }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }
  },
};
