import { Navigate } from "react-router-dom";
import { useAuth } from "@/lib/auth";
import { useClub } from "@/hooks/useClub";
import { useMatches, useNpcClubs, useSeasons } from "@/hooks/useLeague";
import GameLayout from "@/components/GameLayout";
import { formatMoney } from "@/lib/gameUtils";
import { Swords, Calendar, Trophy } from "lucide-react";

const Partidas = () => {
  const { user, loading: authLoading } = useAuth();
  const { data: club, isLoading } = useClub();
  const { data: seasons } = useSeasons(club?.league);
  const season = seasons?.[0];
  const { data: matches } = useMatches(season?.id, club?.id);
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

  const getNpcName = (id: string | null) => {
    if (!id) return null;
    return npcClubs?.find(n => n.id === id)?.name ?? "NPC";
  };

  const getOpponent = (match: { home_club_id: string | null; away_club_id: string | null; home_npc_id: string | null; away_npc_id: string | null }) => {
    if (match.home_club_id === club.id) return getNpcName(match.away_npc_id) ?? "—";
    if (match.away_club_id === club.id) return getNpcName(match.home_npc_id) ?? "—";
    return "—";
  };

  const isHome = (match: { home_club_id: string | null }) => match.home_club_id === club.id;

  const getResult = (match: { home_club_id: string | null; home_score: number | null; away_score: number | null }) => {
    if (match.home_score === null || match.away_score === null) return null;
    const myScore = match.home_club_id === club.id ? match.home_score : match.away_score;
    const theirScore = match.home_club_id === club.id ? match.away_score : match.home_score;
    if (myScore > theirScore) return "V";
    if (myScore < theirScore) return "D";
    return "E";
  };

  const resultColor = (r: string | null) => {
    if (r === "V") return "text-primary bg-primary/10";
    if (r === "D") return "text-destructive bg-destructive/10";
    if (r === "E") return "text-accent bg-accent/10";
    return "text-muted-foreground bg-secondary/50";
  };

  const playedMatches = matches?.filter(m => m.status === "played") ?? [];
  const scheduledMatches = matches?.filter(m => m.status === "scheduled") ?? [];

  return (
    <GameLayout>
      <div className="space-y-6">
        <div>
          <h1 className="font-heading text-3xl font-bold text-foreground">
            <Swords className="inline mr-2 text-accent" size={28} />
            Partidas
          </h1>
          <p className="text-muted-foreground">
            {season ? `Temporada ${season.season_number} • Rodada ${season.current_round}` : "Carregando..."}
          </p>
        </div>

        {/* Match history (played first) */}
        <div className="bg-glass rounded-xl p-6">
          <h2 className="font-heading text-xl font-bold text-foreground mb-4 flex items-center gap-2">
            <Trophy size={18} className="text-accent" />
            Partidas Jogadas
          </h2>

          {playedMatches.length > 0 ? (
            <div className="space-y-2">
              {playedMatches.map(m => {
                const result = getResult(m);
                const myScore = m.home_club_id === club.id ? m.home_score : m.away_score;
                const theirScore = m.home_club_id === club.id ? m.away_score : m.home_score;

                return (
                  <div key={m.id} className="flex items-center justify-between py-3 border-b border-border/30">
                    <div className="flex items-center gap-3">
                      <span className={`w-7 h-7 rounded-full flex items-center justify-center text-xs font-heading font-bold ${resultColor(result)}`}>
                        {result}
                      </span>
                      <div>
                        <p className="text-sm text-foreground">
                          {isHome(m) ? "vs" : "@"} {getOpponent(m)}
                        </p>
                        <p className="text-xs text-muted-foreground">
                          Rodada {m.round} • {m.played_at ? new Date(m.played_at).toLocaleDateString("pt-BR") : ""}
                        </p>
                      </div>
                    </div>
                    <div className="text-right">
                      <p className="font-heading text-lg text-foreground">
                        {myScore} × {theirScore}
                      </p>
                      {m.revenue > 0 && (
                        <p className="text-xs text-primary">+{formatMoney(m.revenue)}</p>
                      )}
                    </div>
                  </div>
                );
              })}
            </div>
          ) : (
            <p className="text-sm text-muted-foreground text-center py-8">
              Nenhuma partida disputada ainda. Aguarde o processamento da rodada.
            </p>
          )}
        </div>

        {/* Scheduled matches */}
        {scheduledMatches.length > 0 && (
          <div className="bg-glass rounded-xl p-6">
            <h2 className="font-heading text-xl font-bold text-foreground mb-4 flex items-center gap-2">
              <Calendar size={18} className="text-accent" />
              Próximas Partidas
            </h2>
            {scheduledMatches.map(m => (
              <div key={m.id} className="bg-secondary/30 rounded-lg p-4 flex items-center justify-between mb-2">
                <div>
                  <p className="font-heading text-lg text-foreground">
                    {isHome(m) ? (
                      <><span className="text-primary">{club.name}</span> vs {getOpponent(m)}</>
                    ) : (
                      <>{getOpponent(m)} vs <span className="text-primary">{club.name}</span></>
                    )}
                  </p>
                  <p className="text-xs text-muted-foreground">
                    Rodada {m.round} • {isHome(m) ? "🏠 Em casa" : "✈️ Fora"}
                  </p>
                </div>
                <div className="text-xs px-3 py-1 rounded-full bg-accent/10 text-accent font-heading">
                  AGENDADO
                </div>
              </div>
            ))}
          </div>
        )}

          {playedMatches.length > 0 ? (
            <div className="space-y-2">
              {playedMatches.map(m => {
                const result = getResult(m);
                const myScore = m.home_club_id === club.id ? m.home_score : m.away_score;
                const theirScore = m.home_club_id === club.id ? m.away_score : m.home_score;

                return (
                  <div key={m.id} className="flex items-center justify-between py-3 border-b border-border/30">
                    <div className="flex items-center gap-3">
                      <span className={`w-7 h-7 rounded-full flex items-center justify-center text-xs font-heading font-bold ${resultColor(result)}`}>
                        {result}
                      </span>
                      <div>
                        <p className="text-sm text-foreground">
                          {isHome(m) ? "vs" : "@"} {getOpponent(m)}
                        </p>
                        <p className="text-xs text-muted-foreground">
                          Rodada {m.round} • {m.played_at ? new Date(m.played_at).toLocaleDateString("pt-BR") : ""}
                        </p>
                      </div>
                    </div>
                    <div className="text-right">
                      <p className="font-heading text-lg text-foreground">
                        {myScore} × {theirScore}
                      </p>
                      {m.revenue > 0 && (
                        <p className="text-xs text-primary">+{formatMoney(m.revenue)}</p>
                      )}
                    </div>
                  </div>
                );
              })}
            </div>
          ) : (
            <p className="text-sm text-muted-foreground text-center py-8">
              Nenhuma partida disputada ainda. Aguarde o processamento da rodada.
            </p>
          )}
        </div>
      </div>
    </GameLayout>
  );
};

export default Partidas;
