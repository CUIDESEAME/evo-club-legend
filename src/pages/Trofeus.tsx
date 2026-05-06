import { Navigate } from "react-router-dom";
import { useAuth } from "@/lib/auth";
import { useClub } from "@/hooks/useClub";
import GameLayout from "@/components/GameLayout";
import { supabase } from "@/integrations/supabase/client";
import { useQuery } from "@tanstack/react-query";
import { Trophy } from "lucide-react";
import { useState } from "react";

const Trofeus = () => {
  const { user, loading: authLoading } = useAuth();
  const { data: club, isLoading } = useClub();
  const [search, setSearch] = useState("");
  const [selectedClubId, setSelectedClubId] = useState<string | null>(null);

  const { data: clubs } = useQuery({
    queryKey: ["all_clubs"],
    queryFn: async () => {
      const { data } = await supabase.from("clubs").select("id,name,abbreviation").order("name");
      return data ?? [];
    },
  });

  const targetId = selectedClubId ?? club?.id;

  const { data: trophies } = useQuery({
    queryKey: ["trophies", targetId],
    queryFn: async () => {
      if (!targetId) return [];
      const { data } = await supabase.from("club_trophies").select("*").eq("club_id", targetId).order("created_at", { ascending: false });
      return data ?? [];
    },
    enabled: !!targetId,
  });

  if (authLoading || isLoading) return <div className="min-h-screen bg-background flex items-center justify-center"><div className="w-8 h-8 border-2 border-primary border-t-transparent rounded-full animate-spin" /></div>;
  if (!user) return <Navigate to="/auth" replace />;
  if (!club) return <Navigate to="/criar-clube" replace />;

  const filtered = clubs?.filter(c => c.name.toLowerCase().includes(search.toLowerCase())) ?? [];
  const targetClub = clubs?.find(c => c.id === targetId);

  return (
    <GameLayout>
      <div className="space-y-6">
        <div className="flex items-center gap-3">
          <Trophy size={32} className="text-accent" />
          <div>
            <h1 className="font-heading text-3xl font-bold text-foreground">Troféus</h1>
            <p className="text-sm text-muted-foreground">Histórico público de conquistas</p>
          </div>
        </div>

        <div className="grid grid-cols-1 lg:grid-cols-3 gap-4">
          <div className="bg-glass rounded-xl p-4">
            <input
              placeholder="Buscar clube..."
              value={search}
              onChange={e => setSearch(e.target.value)}
              className="w-full bg-secondary text-foreground rounded p-2 border border-border/30 text-sm mb-3"
            />
            <div className="space-y-1 max-h-96 overflow-y-auto">
              <button onClick={() => setSelectedClubId(club.id)}
                className={`w-full text-left text-sm p-2 rounded ${targetId === club.id ? "bg-primary/10 text-primary" : "hover:bg-secondary text-foreground"}`}>
                ⭐ {club.name} (você)
              </button>
              {filtered.filter(c => c.id !== club.id).map(c => (
                <button key={c.id} onClick={() => setSelectedClubId(c.id)}
                  className={`w-full text-left text-sm p-2 rounded ${targetId === c.id ? "bg-primary/10 text-primary" : "hover:bg-secondary text-foreground"}`}>
                  {c.name}
                </button>
              ))}
            </div>
          </div>

          <div className="lg:col-span-2 bg-glass rounded-xl p-6">
            <h2 className="font-heading text-xl font-bold text-foreground mb-4">
              {targetClub?.name ?? "Clube"}
            </h2>
            {trophies?.length === 0 && (
              <p className="text-sm text-muted-foreground text-center py-8">Nenhum troféu ainda.</p>
            )}
            <div className="space-y-2">
              {trophies?.map(t => (
                <div key={t.id} className="flex items-center justify-between p-3 bg-secondary/30 rounded-lg">
                  <div className="flex items-center gap-3">
                    <Trophy size={20} className={t.position === "champion" ? "text-accent" : "text-muted-foreground"} />
                    <div>
                      <p className="text-sm font-heading text-foreground">{t.competition_name}</p>
                      <p className="text-xs text-muted-foreground">Temporada {t.season_number} • {t.position}</p>
                    </div>
                  </div>
                  <span className="text-xs text-muted-foreground">{t.trophy_type}</span>
                </div>
              ))}
            </div>
          </div>
        </div>
      </div>
    </GameLayout>
  );
};

export default Trofeus;
