import { useQuery } from "@tanstack/react-query";
import { supabase } from "@/integrations/supabase/client";
import { useAuth } from "@/lib/auth";

export function useClub() {
  const { user } = useAuth();

  return useQuery({
    queryKey: ["club", user?.id],
    queryFn: async () => {
      if (!user) return null;
      const { data, error } = await supabase
        .from("clubs")
        .select("*")
        .eq("user_id", user.id)
        .maybeSingle();
      if (error) throw error;
      return data;
    },
    enabled: !!user,
  });
}

export function usePlayers(clubId: string | undefined) {
  return useQuery({
    queryKey: ["players", clubId],
    queryFn: async () => {
      if (!clubId) return [];
      const { data, error } = await supabase
        .from("players")
        .select("*")
        .eq("club_id", clubId)
        .order("position");
      if (error) throw error;
      return data ?? [];
    },
    enabled: !!clubId,
  });
}

export function usePatrimony(clubId: string | undefined) {
  return useQuery({
    queryKey: ["patrimony", clubId],
    queryFn: async () => {
      if (!clubId) return [];
      const { data, error } = await supabase
        .from("patrimony")
        .select("*")
        .eq("club_id", clubId);
      if (error) throw error;
      return data ?? [];
    },
    enabled: !!clubId,
  });
}

export function useTrainingConfig(clubId: string | undefined) {
  return useQuery({
    queryKey: ["training_config", clubId],
    queryFn: async () => {
      if (!clubId) return null;
      const { data, error } = await supabase
        .from("training_config")
        .select("*")
        .eq("club_id", clubId)
        .maybeSingle();
      if (error) throw error;
      return data;
    },
    enabled: !!clubId,
  });
}

export function useFinancialTransactions(clubId: string | undefined) {
  return useQuery({
    queryKey: ["transactions", clubId],
    queryFn: async () => {
      if (!clubId) return [];
      const { data, error } = await supabase
        .from("financial_transactions")
        .select("*")
        .eq("club_id", clubId)
        .order("created_at", { ascending: false })
        .limit(50);
      if (error) throw error;
      return data ?? [];
    },
    enabled: !!clubId,
  });
}

export function useStadiumSectors(clubId: string | undefined) {
  return useQuery({
    queryKey: ["stadium_sectors", clubId],
    queryFn: async () => {
      if (!clubId) return [];
      const { data, error } = await supabase
        .from("stadium_sectors")
        .select("*")
        .eq("club_id", clubId);
      if (error) throw error;
      return data ?? [];
    },
    enabled: !!clubId,
  });
}
