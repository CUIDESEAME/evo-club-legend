import { Navigate } from "react-router-dom";
import { useAuth } from "@/lib/auth";
import { useClub } from "@/hooks/useClub";
import GameLayout from "@/components/GameLayout";
import { formatMoney } from "@/lib/gameUtils";
import { supabase } from "@/integrations/supabase/client";
import { useQuery, useQueryClient } from "@tanstack/react-query";
import { useToast } from "@/hooks/use-toast";
import { Button } from "@/components/ui/button";
import { Award, Trophy, Users } from "lucide-react";
import { useState } from "react";

const Copas = () => {
  const { user, loading: authLoading } = useAuth();
  const { data: club, isLoading } = useClub();
  const queryClient = useQueryClient();
  const { toast } = useToast();
  const [registering, setRegistering] = useState<string | null>(null);

  const { data: cups } = useQuery({
    queryKey: ["cups"],
    queryFn: async () => {
      const { data } = await supabase.from("cups").select("*").order("starts_at");
      return data ?? [];
    },
  });

  const { data: entries } = useQuery({
    queryKey: ["cup_entries", club?.id],
    queryFn: async () => {
      if (!club) return [];
      const { data } = await supabase.from("cup_entries").select("*").eq("club_id", club.id);
      return data ?? [];
    },
    enabled: !!club,
  });

  const { data: cupMatches } = useQuery({
    queryKey: ["cup_matches", club?.id],
    queryFn: async () => {
      if (!club) return [];
      const { data } = await supabase
        .from("cup_matches")
        .select("*")
        .or(`home_club_id.eq.${club.id},away_club_id.eq.${club.id}`)
        .order("created_at", { ascending: false })
        .limit(10);
      return data ?? [];
    },
    enabled: !!club,
  });

  if (authLoading || isLoading) return <div className="min-h-screen bg-background flex items-center justify-center"><div className="w-8 h-8 border-2 border-primary border-t-transparent rounded-full animate-spin" /></div>;
  if (!user) return <Navigate to="/auth" replace />;
  if (!club) return <Navigate to="/criar-clube" replace />;

  const isRegistered = (cupId: string) => entries?.some(e => e.cup_id === cupId);

  const register = async (cupId: string, fee: number) => {
    if (club.balance < fee) { toast({ title: "Sem fundos", variant: "destructive" }); return; }
    setRegistering(cupId);
    const { error } = await supabase.rpc("register_cup", { p_club_id: club.id, p_cup_id: cupId });
    if (error) toast({ title: "Erro", description: error.message, variant: "destructive" });
    else {
      toast({ title: "Inscrito!" });
      queryClient.invalidateQueries({ queryKey: ["cup_entries"] });
      queryClient.invalidateQueries({ queryKey: ["club"] });
    }
    setRegistering(null);
  };

  return (
    <GameLayout>
      <div className="space-y-6">
        <h1 className="font-heading text-3xl font-bold text-foreground">Copas</h1>
        <p className="text-sm text-muted-foreground">Inscreva-se para disputar prêmios em dinheiro e troféus.</p>

        <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
          {cups?.map(cup => {
            const entry = entries?.find(e => e.cup_id === cup.id);
            return (
              <div key={cup.id} className="bg-glass rounded-xl p-6">
                <div className="flex items-center gap-3 mb-3">
                  <Award className="text-accent" size={32} />
                  <div className="flex-1">
                    <h3 className="font-heading text-lg font-bold text-foreground">{cup.name}</h3>
                    <p className="text-xs text-muted-foreground uppercase">{cup.cup_type === "u20" ? "Sub-20 (Juniores)" : "Profissional"}</p>
                  </div>
                </div>
                <div className="space-y-1 text-sm mb-4">
                  <div className="flex justify-between"><span className="text-muted-foreground">Inscrição:</span><span className="text-foreground">{formatMoney(cup.entry_fee)}</span></div>
                  <div className="flex justify-between"><span className="text-muted-foreground">🏆 Campeão:</span><span className="text-accent font-heading">{formatMoney(cup.champion_prize)}</span></div>
                  <div className="flex justify-between"><span className="text-muted-foreground">🥈 Vice:</span><span className="text-foreground">{formatMoney(cup.runner_up_prize)}</span></div>
                  <div className="flex justify-between"><span className="text-muted-foreground">Semifinal:</span><span className="text-foreground">{formatMoney(cup.semifinal_prize)}</span></div>
                </div>
                {entry ? (
                  <div className="bg-primary/10 border border-primary/20 rounded-lg p-2 text-center">
                    <Trophy size={14} className="inline text-primary mr-1" />
                    <span className="text-sm text-primary font-heading">Inscrito ({entry.status})</span>
                  </div>
                ) : (
                  <Button onClick={() => register(cup.id, cup.entry_fee)} disabled={registering === cup.id || club.balance < cup.entry_fee} className="w-full font-heading" size="sm">
                    <Users size={14} /> {registering === cup.id ? "Inscrevendo..." : "Inscrever"}
                  </Button>
                )}
              </div>
            );
          })}
        </div>

        {cupMatches && cupMatches.length > 0 && (
          <div className="bg-glass rounded-xl p-6">
            <h2 className="font-heading text-xl font-bold text-foreground mb-3">Seus jogos de copa</h2>
            <div className="space-y-2">
              {cupMatches.map(m => (
                <div key={m.id} className="flex justify-between items-center text-sm border-b border-border/40 pb-2">
                  <span className="text-muted-foreground uppercase text-xs">{m.phase}</span>
                  <span className="text-foreground font-heading">
                    {m.status === "played" ? `${m.home_score} x ${m.away_score}` : "Agendado"}
                  </span>
                </div>
              ))}
            </div>
          </div>
        )}
      </div>
    </GameLayout>
  );
};

export default Copas;