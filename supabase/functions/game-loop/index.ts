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

    // 0. Repair dead progression before simulating. If a season reached the
    // final round with no scheduled matches, this closes it and creates the
    // next playable table instead of leaving time/economy frozen.
    await supabase.rpc("repair_game_progression");

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

    // 2e. Auto-fill open cups with rule-following teams, then advance any cup.
    // National cups draw the strongest clubs; U20 cups are scored using only
    // players up to 20 years old (handled inside cup_team_strength).
    const { data: activeCups } = await supabase
      .from("cups")
      .select("id, status")
      .in("status", ["open", "in_progress"]);
    for (const cup of activeCups ?? []) {
      if (cup.status === "open") {
        await supabase.rpc("populate_cup", { p_cup_id: cup.id });
      }
      await supabase.rpc("advance_cup_phase", { p_cup_id: cup.id });
    }

    // 2f. Auto end-season when every round has been played.
    // A season completes once it reaches the final round AND has no scheduled
    // matches left. end_season marks it 'completed' and starts a fresh single
    // season for the club, so a club is only ever in ONE active season at a time.
    const { data: finishedSeasons } = await supabase
      .from("seasons")
      .select("id, current_round, total_rounds")
      .eq("status", "active");
    for (const s of finishedSeasons ?? []) {
      if (s.current_round >= s.total_rounds) {
        const { count } = await supabase
          .from("matches")
          .select("id", { count: "exact", head: true })
          .eq("season_id", s.id)
          .eq("status", "scheduled");
        if (!count) {
          await supabase.rpc("end_season", { p_season_id: s.id });
        }
      }
    }

    // 3. Process weekly tasks (salaries, maintenance, income, training) ONLY
    // when matches were actually played this tick. This ties the economy to
    // real game progression (one processed week per round) instead of firing
    // every 60s, which previously caused runaway/infinite income.
    const matchesPlayed = (matchResult as { matches_played?: number } | null)?.matches_played ?? 0;
    const shouldProcessWeek = matchesPlayed > 0;

    let weekResult = null;
    let weekError = null;

    if (shouldProcessWeek) {
      const res = await supabase.rpc("process_game_week");
      weekResult = res.data;
      weekError = res.error;
    }

    // 4. Automatic housekeeping: purge irrelevant history (old seasons, their
    // matches/standings/NPCs, stale transactions & disciplinary records) and
    // recycle finished cups. Trophies are kept permanently. Keeps the game light.
    await supabase.rpc("cleanup_old_data");

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
