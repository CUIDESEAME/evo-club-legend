import { useQuery } from "@tanstack/react-query";
import { supabase } from "@/integrations/supabase/client";

export function useLineup(clubId: string | undefined) {
  return useQuery({
    queryKey: ["lineup", clubId],
    queryFn: async () => {
      if (!clubId) return null;
      const { data: lineup, error } = await supabase
        .from("lineups")
        .select("*, lineup_players(*)")
        .eq("club_id", clubId)
        .maybeSingle();
      if (error) throw error;
      if (!lineup) return null;
      return {
        ...lineup,
        players: (lineup as any).lineup_players ?? [],
      };
    },
    enabled: !!clubId,
  });
}

export function useClosedMarket(league: string | undefined) {
  return useQuery({
    queryKey: ["market_closed", league],
    queryFn: async () => {
      if (!league) return [];
      const { data, error } = await supabase
        .from("market_closed")
        .select("*")
        .eq("league", league)
        .is("purchased_by", null)
        .order("overall", { ascending: false });
      if (error) throw error;
      return data ?? [];
    },
    enabled: !!league,
  });
}

export function useOpenMarket() {
  return useQuery({
    queryKey: ["market_open"],
    queryFn: async () => {
      const { data, error } = await supabase
        .from("market_open")
        .select("*, players(name, position, age), clubs!market_open_seller_club_id_fkey(name)")
        .eq("status", "active")
        .order("ends_at", { ascending: true });
      if (error) throw error;
      return data ?? [];
    },
  });
}
