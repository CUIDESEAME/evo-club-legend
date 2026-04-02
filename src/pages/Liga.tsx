import { Navigate } from "react-router-dom";
import { useAuth } from "@/lib/auth";
import { useClub } from "@/hooks/useClub";
import { useLeagueStandings, useSeasons, useNpcClubs } from "@/hooks/useLeague";
import GameLayout from "@/components/GameLayout";
import { Trophy, ArrowUp, ArrowDown, Minus } from "lucide-react";

const Liga = () => {
  const { user, loading: authLoading } = useAuth();
  const { data: club, isLoading } = useClub();
  const { data: seasons } = useSeasons(club?.league);
  const season = seasons?.[0];
  const { data: standings } = useLeagueStandings(season?.id);
  const { data: npcClubs } = useNpcClubs(season?.id);

  if (authLoading || isLoading) {
    return (
      <div className="min-h-screen bg-background flex items-center justify-center">
        <div className="w-8 h-8 border-2 border-primary border-t-transparent rounded-full animate-spin" />
      </div>
    );
  }

  if (!user) return <Navigate to="/auth" replace />;
  if (!club) return <Navigate to="/criar-clube" replace />;

  const getTeamName = (standing: { club_id: string | null; npc_club_id: string | null }) => {
    if (standing.club_id === club.id) return club.name;
    const npc = npcClubs?.find(n => n.id === standing.npc_club_id);
    return npc?.name ?? "—";
  };

  const getTeamAbbrev = (standing: { club_id: string | null; npc_club_id: string | null }) => {
    if (standing.club_id === club.id) return club.abbreviation;
    const npc = npcClubs?.find(n => n.id === standing.npc_club_id);
    return npc?.abbreviation ?? "—";
  };

  const isMyClub = (standing: { club_id: string | null }) => standing.club_id === club.id;

  const sortedStandings = [...(standings ?? [])].sort((a, b) => {
    if (b.points !== a.points) return b.points - a.points;
    const gdA = a.goals_for - a.goals_against;
    const gdB = b.goals_for - b.goals_against;
    if (gdB !== gdA) return gdB - gdA;
    return b.goals_for - a.goals_for;
  });

  return (
    <GameLayout>
      <div className="space-y-6">
        <div>
          <h1 className="font-heading text-3xl font-bold text-foreground">
            <Trophy className="inline mr-2 text-accent" size={28} />
            Liga — Série {club.league}
          </h1>
          <p className="text-muted-foreground">
            {season ? `Temporada ${season.season_number} • Rodada ${season.current_round}/${season.total_rounds}` : "Carregando..."}
          </p>
        </div>

        {/* Standings table */}
        <div className="bg-glass rounded-xl p-4 overflow-x-auto">
          <table className="w-full text-sm">
            <thead>
              <tr className="text-muted-foreground text-xs border-b border-border">
                <th className="text-center pb-2 w-8">#</th>
                <th className="text-left pb-2">Clube</th>
                <th className="text-center pb-2">J</th>
                <th className="text-center pb-2">V</th>
                <th className="text-center pb-2">E</th>
                <th className="text-center pb-2">D</th>
                <th className="text-center pb-2">GP</th>
                <th className="text-center pb-2">GC</th>
                <th className="text-center pb-2">SG</th>
                <th className="text-center pb-2 font-bold">Pts</th>
              </tr>
            </thead>
            <tbody>
              {sortedStandings.map((s, idx) => {
                const mine = isMyClub(s);
                const gd = s.goals_for - s.goals_against;
                return (
                  <tr
                    key={s.id}
                    className={`border-b border-border/30 transition-colors ${
                      mine ? "bg-primary/10 font-bold" : "hover:bg-secondary/30"
                    } ${idx < 2 ? "text-primary" : idx >= sortedStandings.length - 2 ? "text-destructive" : ""}`}
                  >
                    <td className="text-center py-2">
                      <span className={`inline-flex items-center justify-center w-6 h-6 rounded-full text-xs font-heading ${
                        idx < 2 ? "bg-primary/20 text-primary" : idx >= sortedStandings.length - 2 ? "bg-destructive/20 text-destructive" : "text-muted-foreground"
                      }`}>
                        {idx + 1}
                      </span>
                    </td>
                    <td className="py-2 text-foreground">
                      <span className="font-heading mr-2 text-xs text-muted-foreground">{getTeamAbbrev(s)}</span>
                      {getTeamName(s)}
                      {mine && <span className="ml-1 text-accent text-xs">★</span>}
                    </td>
                    <td className="text-center text-muted-foreground">{s.played}</td>
                    <td className="text-center text-primary">{s.wins}</td>
                    <td className="text-center text-muted-foreground">{s.draws}</td>
                    <td className="text-center text-destructive">{s.losses}</td>
                    <td className="text-center text-muted-foreground">{s.goals_for}</td>
                    <td className="text-center text-muted-foreground">{s.goals_against}</td>
                    <td className="text-center">
                      <span className={`font-mono ${gd > 0 ? "text-primary" : gd < 0 ? "text-destructive" : "text-muted-foreground"}`}>
                        {gd > 0 ? `+${gd}` : gd}
                      </span>
                    </td>
                    <td className="text-center font-heading font-bold text-foreground">{s.points}</td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        </div>

        {/* Legend */}
        <div className="flex gap-6 text-xs text-muted-foreground">
          <span className="flex items-center gap-1">
            <ArrowUp size={12} className="text-primary" /> Promoção
          </span>
          <span className="flex items-center gap-1">
            <ArrowDown size={12} className="text-destructive" /> Rebaixamento
          </span>
        </div>
      </div>
    </GameLayout>
  );
};

export default Liga;
