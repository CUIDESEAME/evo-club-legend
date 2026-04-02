import { useQuery } from "@tanstack/react-query";
import { supabase } from "@/integrations/supabase/client";

export function useSeasons(league: string | undefined) {
  return useQuery({
    queryKey: ["seasons", league],
    queryFn: async () => {
      if (!league) return [];
      const { data, error } = await supabase
        .from("seasons")
        .select("*")
        .eq("league", league)
        .eq("status", "active")
        .order("created_at", { ascending: false })
        .limit(1);
      if (error) throw error;
      return data ?? [];
    },
    enabled: !!league,
  });
}

export function useNpcClubs(seasonId: string | undefined) {
  return useQuery({
    queryKey: ["npc_clubs", seasonId],
    queryFn: async () => {
      if (!seasonId) return [];
      const { data, error } = await supabase
        .from("npc_clubs")
        .select("*")
        .eq("season_id", seasonId);
      if (error) throw error;
      return data ?? [];
    },
    enabled: !!seasonId,
  });
}

export function useLeagueStandings(seasonId: string | undefined) {
  return useQuery({
    queryKey: ["league_standings", seasonId],
    queryFn: async () => {
      if (!seasonId) return [];
      const { data, error } = await supabase
        .from("league_standings")
        .select("*")
        .eq("season_id", seasonId);
      if (error) throw error;
      return data ?? [];
    },
    enabled: !!seasonId,
  });
}

export function useMatches(seasonId: string | undefined, clubId: string | undefined) {
  return useQuery({
    queryKey: ["matches", seasonId, clubId],
    queryFn: async () => {
      if (!seasonId || !clubId) return [];
      const { data, error } = await supabase
        .from("matches")
        .select("*")
        .eq("season_id", seasonId)
        .or(`home_club_id.eq.${clubId},away_club_id.eq.${clubId}`)
        .order("round", { ascending: false });
      if (error) throw error;
      return data ?? [];
    },
    enabled: !!seasonId && !!clubId,
  });
}
