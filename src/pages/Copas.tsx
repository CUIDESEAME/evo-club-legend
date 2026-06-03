import { Navigate } from "react-router-dom";
import { useAuth } from "@/lib/auth";
import { useClub } from "@/hooks/useClub";
import GameLayout from "@/components/GameLayout";
import { formatMoney } from "@/lib/gameUtils";
import { supabase } from "@/integrations/supabase/client";
import { useQuery, useQueryClient } from "@tanstack/react-query";
import { useToast } from "@/hooks/use-toast";
import { Button } from "@/components/ui/button";
import { Award, Trophy, Users, Map, Swords, ListChecks } from "lucide-react";
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

  // ===== Dados globais para o "Mapa da Copa" =====
  const { data: allEntries } = useQuery({
    queryKey: ["all_cup_entries"],
    queryFn: async () => {
      const { data } = await supabase.from("cup_entries").select("*");
      return data ?? [];
    },
  });

  const { data: allCupMatches } = useQuery({
    queryKey: ["all_cup_matches"],
    queryFn: async () => {
      const { data } = await supabase
        .from("cup_matches")
        .select("*")
        .order("created_at", { ascending: true });
      return data ?? [];
    },
  });

  const { data: allClubs } = useQuery({
    queryKey: ["all_clubs_names"],
    queryFn: async () => {
      const { data } = await supabase.from("clubs").select("id, name, abbreviation");
      return data ?? [];
    },
  });

  if (authLoading || isLoading) return <div className="min-h-screen bg-background flex items-center justify-center"><div className="w-8 h-8 border-2 border-primary border-t-transparent rounded-full animate-spin" /></div>;
  if (!user) return <Navigate to="/auth" replace />;
  if (!club) return <Navigate to="/criar-clube" replace />;

  const isRegistered = (cupId: string) => entries?.some(e => e.cup_id === cupId);

  const clubName = (id: string | null) => {
    if (!id) return "—";
    const c = allClubs?.find(x => x.id === id);
    return c?.name ?? "Clube";
  };

  // Computa classificação (pontos/vitórias) a partir das partidas jogadas de uma copa
  const computeStandings = (cupId: string) => {
    const table: Record<string, { id: string; pts: number; v: number; e: number; d: number; gp: number; gc: number; j: number }> = {};
    const ensure = (id: string) => {
      if (!table[id]) table[id] = { id, pts: 0, v: 0, e: 0, d: 0, gp: 0, gc: 0, j: 0 };
      return table[id];
    };
    (allCupMatches ?? [])
      .filter(m => m.cup_id === cupId && m.status === "played" && m.home_club_id && m.away_club_id)
      .forEach(m => {
        const h = ensure(m.home_club_id!);
        const a = ensure(m.away_club_id!);
        const hs = m.home_score ?? 0;
        const as = m.away_score ?? 0;
        h.j++; a.j++; h.gp += hs; h.gc += as; a.gp += as; a.gc += hs;
        if (hs > as) { h.v++; h.pts += 3; a.d++; }
        else if (hs < as) { a.v++; a.pts += 3; h.d++; }
        else { h.e++; a.e++; h.pts++; a.pts++; }
      });
    return Object.values(table).sort((x, y) => y.pts - x.pts || (y.gp - y.gc) - (x.gp - x.gc) || y.gp - x.gp);
  };

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

        {/* ===== MAPA DA COPA ===== */}
        <div className="space-y-6">
          <h2 className="font-heading text-2xl font-bold text-foreground flex items-center gap-2">
            <Map className="text-accent" size={24} /> Mapa da Copa
          </h2>
          <p className="text-sm text-muted-foreground -mt-4">Acompanhe inscrições, partidas, pontos e vitórias de cada competição.</p>

          {cups?.map(cup => {
            const cupEntries = allEntries?.filter(e => e.cup_id === cup.id) ?? [];
            const cupGames = allCupMatches?.filter(m => m.cup_id === cup.id) ?? [];
            const standings = computeStandings(cup.id);
            return (
              <div key={cup.id} className="bg-glass rounded-xl p-6 space-y-5">
                <div className="flex items-center gap-2">
                  <Trophy className="text-accent" size={20} />
                  <h3 className="font-heading text-lg font-bold text-foreground">{cup.name}</h3>
                  <span className="text-xs px-2 py-0.5 rounded-full bg-secondary/50 text-muted-foreground uppercase ml-auto">{cup.status}</span>
                </div>

                {/* Inscrições */}
                <div>
                  <h4 className="font-heading text-sm font-bold text-foreground mb-2 flex items-center gap-1">
                    <ListChecks size={14} className="text-primary" /> Inscritos ({cupEntries.length})
                  </h4>
                  {cupEntries.length > 0 ? (
                    <div className="flex flex-wrap gap-2">
                      {cupEntries.map(e => (
                        <span key={e.id} className={`text-xs px-2 py-1 rounded-lg ${e.club_id === club.id ? "bg-primary/15 text-primary font-bold" : "bg-secondary/40 text-foreground"}`}>
                          {clubName(e.club_id)}{e.reached_phase ? ` • ${e.reached_phase}` : ""}
                        </span>
                      ))}
                    </div>
                  ) : <p className="text-xs text-muted-foreground">Nenhum clube inscrito ainda.</p>}
                </div>

                {/* Classificação (pontos/vitórias) */}
                {standings.length > 0 && (
                  <div className="overflow-x-auto">
                    <h4 className="font-heading text-sm font-bold text-foreground mb-2 flex items-center gap-1">
                      <Trophy size={14} className="text-accent" /> Pontos & Vitórias
                    </h4>
                    <table className="w-full text-sm">
                      <thead>
                        <tr className="text-muted-foreground text-xs border-b border-border">
                          <th className="text-left pb-2">Clube</th>
                          <th className="text-center pb-2">J</th>
                          <th className="text-center pb-2">V</th>
                          <th className="text-center pb-2">E</th>
                          <th className="text-center pb-2">D</th>
                          <th className="text-center pb-2">SG</th>
                          <th className="text-center pb-2 font-bold">Pts</th>
                        </tr>
                      </thead>
                      <tbody>
                        {standings.map(s => (
                          <tr key={s.id} className={`border-b border-border/30 ${s.id === club.id ? "bg-primary/10 font-bold" : ""}`}>
                            <td className="py-2 text-foreground">{clubName(s.id)}{s.id === club.id && <span className="ml-1 text-accent">★</span>}</td>
                            <td className="text-center text-muted-foreground">{s.j}</td>
                            <td className="text-center text-primary">{s.v}</td>
                            <td className="text-center text-muted-foreground">{s.e}</td>
                            <td className="text-center text-destructive">{s.d}</td>
                            <td className="text-center font-mono">{s.gp - s.gc > 0 ? `+${s.gp - s.gc}` : s.gp - s.gc}</td>
                            <td className="text-center font-heading font-bold text-foreground">{s.pts}</td>
                          </tr>
                        ))}
                      </tbody>
                    </table>
                  </div>
                )}

                {/* Partidas */}
                <div>
                  <h4 className="font-heading text-sm font-bold text-foreground mb-2 flex items-center gap-1">
                    <Swords size={14} className="text-accent" /> Partidas ({cupGames.length})
                  </h4>
                  {cupGames.length > 0 ? (
                    <div className="space-y-2">
                      {cupGames.map(m => (
                        <div key={m.id} className="flex items-center justify-between text-sm border-b border-border/30 pb-2">
                          <span className="text-xs text-muted-foreground uppercase w-24">{m.phase}</span>
                          <span className="flex-1 text-right text-foreground">{clubName(m.home_club_id)}</span>
                          <span className="font-heading mx-3 text-foreground">
                            {m.status === "played" ? `${m.home_score} × ${m.away_score}` : "vs"}
                          </span>
                          <span className="flex-1 text-left text-foreground">{clubName(m.away_club_id)}</span>
                        </div>
                      ))}
                    </div>
                  ) : <p className="text-xs text-muted-foreground">Nenhuma partida gerada ainda.</p>}
                </div>
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