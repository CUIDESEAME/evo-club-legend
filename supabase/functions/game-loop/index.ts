import { createClient } from "https://esm.sh/@supabase/supabase-js@2.49.1";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const supabase = createClient(supabaseUrl, serviceRoleKey);

    // 1. Always simulate matches (1 round per call, every 60s)
    const { data: matchResult, error: matchError } = await supabase.rpc("simulate_matches");

    // 2. Check if we should process weekly tasks (training, salaries, etc.)
    // A "game week" = every 2 rounds. Process when current_round is even.
    const { data: seasons } = await supabase
      .from("seasons")
      .select("id, current_round")
      .eq("status", "active");

    let weekResult = null;
    let weekError = null;
    const shouldProcessWeek = seasons?.some(s => s.current_round % 2 === 0);

    if (shouldProcessWeek) {
      const res = await supabase.rpc("process_game_week");
      weekResult = res.data;
      weekError = res.error;
    }

    const errors = [];
    if (matchError) errors.push(matchError.message);
    if (weekError) errors.push(weekError.message);

    if (errors.length > 0) {
      return new Response(JSON.stringify({ errors, weekResult, matchResult }), {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    return new Response(
      JSON.stringify({
        success: true,
        matches: matchResult,
        week: weekResult,
        weekProcessed: shouldProcessWeek,
      }),
      {
        status: 200,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    );
  } catch (err) {
    return new Response(JSON.stringify({ error: String(err) }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
