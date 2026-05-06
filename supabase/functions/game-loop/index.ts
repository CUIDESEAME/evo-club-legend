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

    // 1. Simulate matches (1 round per call, every 60s)
    const { data: matchResult, error: matchError } = await supabase.rpc("simulate_matches");

    // 2. Finalize expired auctions
    const { data: auctionResult, error: auctionError } = await supabase.rpc("finalize_auctions");

    // 2b. NPC auto-bidding to keep auctions lively
    await supabase.rpc("npc_auto_bid");

    // 2c. Refill closed market with players for each league
    await supabase.rpc("refill_closed_market");

    // 2d. Disciplinary events + agent renegotiations
    await supabase.rpc("process_disciplinary_events");
    await supabase.rpc("process_agent_negotiations");
    await supabase.rpc("process_sporadic_events");
    await supabase.rpc("process_bank_deposits");

    // 2e. Advance any in-progress cups
    const { data: activeCups } = await supabase
      .from("cups")
      .select("id")
      .in("status", ["open", "in_progress"]);
    for (const cup of activeCups ?? []) {
      await supabase.rpc("advance_cup_phase", { p_cup_id: cup.id });
    }

    // 3. Check if we should process weekly tasks (training, salaries, etc.)
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
    if (auctionError) errors.push(auctionError.message);

    if (errors.length > 0) {
      return new Response(JSON.stringify({ errors, weekResult, matchResult, auctionResult }), {
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
        auctions: auctionResult,
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
