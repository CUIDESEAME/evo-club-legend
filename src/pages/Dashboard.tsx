import { Navigate } from "react-router-dom";
import { useAuth } from "@/lib/auth";
import { useClub } from "@/hooks/useClub";
import { usePlayers, usePatrimony, useStadiumSectors } from "@/hooks/useClub";
import GameLayout from "@/components/GameLayout";
import { formatMoney, POSITION_ABBREVIATIONS, PATRIMONY_LABELS, PATRIMONY_ICONS, getOverallRating } from "@/lib/gameUtils";
import { Users, Building2, Coins, Trophy, Dumbbell } from "lucide-react";

function StatCard({ icon: Icon, label, value, sub, color = "text-foreground" }: any) {
  return (
    <div className="bg-glass rounded-xl p-5 flex items-start gap-4">
      <div className="w-10 h-10 rounded-lg bg-primary/10 flex items-center justify-center shrink-0">
        <Icon size={20} className="text-primary" />
      </div>
      <div>
        <p className="text-xs text-muted-foreground">{label}</p>
        <p className={`font-heading text-xl font-bold ${color}`}>{value}</p>
        {sub && <p className="text-xs text-muted-foreground mt-0.5">{sub}</p>}
      </div>
    </div>
  );
}

const Dashboard = () => {
  const { user, loading: authLoading } = useAuth();
  const { data: club, isLoading: clubLoading } = useClub();
  const { data: players } = usePlayers(club?.id);
  const { data: patrimony } = usePatrimony(club?.id);

  if (authLoading || clubLoading) {
    return (
      <div className="min-h-screen bg-background flex items-center justify-center">
        <div className="w-8 h-8 border-2 border-primary border-t-transparent rounded-full animate-spin" />
      </div>
    );
  }

  if (!user) return <Navigate to="/auth" replace />;
  if (!club) return <Navigate to="/criar-clube" replace />;

  const totalSalary = players?.reduce((sum, p) => sum + p.salary, 0) ?? 0;
  const avgRating = players?.length
    ? (players.reduce((sum, p) => sum + getOverallRating(p), 0) / players.length).toFixed(1)
    : "0";
  const captain = players?.find(p => p.is_captain);

  const totalCapacity = 800; // default for geral
  const stadiumLevel = patrimony?.find(p => p.type === "estadio")?.level ?? 0;

  return (
    <GameLayout>
      <div className="space-y-6">
        {/* Header */}
        <div>
          <h1 className="font-heading text-3xl font-bold text-foreground">{club.name}</h1>
          <p className="text-muted-foreground">
            Série {club.league} • {club.fans} torcedores • {club.members} sócios
          </p>
        </div>

        {/* Stats Grid */}
        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
          <StatCard
            icon={Coins}
            label="Caixa"
            value={formatMoney(club.balance)}
            color={club.balance >= 0 ? "text-primary" : "text-destructive"}
            sub={`Salários: ${formatMoney(totalSalary)}/sem`}
          />
          <StatCard
            icon={Users}
            label="Elenco"
            value={`${players?.length ?? 0}/50`}
            sub={`Média: ${avgRating}`}
          />
          <StatCard
            icon={Building2}
            label="Estádio"
            value={`${totalCapacity} lugares`}
            sub={`Nível ${stadiumLevel}`}
          />
          <StatCard
            icon={Trophy}
            label="Liga"
            value={`Série ${club.league}`}
            sub={`Divisão ${club.division}`}
          />
        </div>

        {/* Players preview */}
        <div className="bg-glass rounded-xl p-6">
          <div className="flex items-center justify-between mb-4">
            <h2 className="font-heading text-xl font-bold text-foreground">Elenco</h2>
            <a href="/elenco" className="text-sm text-accent hover:underline">Ver todos →</a>
          </div>

          {players && players.length > 0 ? (
            <div className="overflow-x-auto">
              <table className="w-full text-sm">
                <thead>
                  <tr className="text-muted-foreground text-xs border-b border-border">
                    <th className="text-left pb-2">Jogador</th>
                    <th className="text-center pb-2">Pos</th>
                    <th className="text-center pb-2">Idade</th>
                    <th className="text-center pb-2">Geral</th>
                    <th className="text-right pb-2">Salário</th>
                  </tr>
                </thead>
                <tbody>
                  {players.slice(0, 8).map(p => (
                    <tr key={p.id} className="border-b border-border/50">
                      <td className="py-2 text-foreground">
                        {p.is_captain && <span className="text-accent mr-1">©</span>}
                        {p.name}
                      </td>
                      <td className="text-center">
                        <span className="text-xs px-2 py-0.5 rounded bg-secondary text-foreground font-heading">
                          {POSITION_ABBREVIATIONS[p.position] ?? p.position}
                        </span>
                      </td>
                      <td className="text-center text-muted-foreground">{p.age}</td>
                      <td className="text-center font-heading text-primary">{getOverallRating(p)}</td>
                      <td className="text-right text-muted-foreground">{formatMoney(p.salary)}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          ) : (
            <p className="text-muted-foreground text-sm">Nenhum jogador no elenco.</p>
          )}
        </div>

        {/* Patrimony preview */}
        <div className="bg-glass rounded-xl p-6">
          <div className="flex items-center justify-between mb-4">
            <h2 className="font-heading text-xl font-bold text-foreground">Patrimônio</h2>
            <a href="/patrimonio" className="text-sm text-accent hover:underline">Gerenciar →</a>
          </div>

          <div className="grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-4 gap-3">
            {patrimony?.map(p => (
              <div key={p.id} className="bg-secondary/50 rounded-lg p-3 text-center">
                <span className="text-2xl">{PATRIMONY_ICONS[p.type] ?? "🏢"}</span>
                <p className="text-xs text-foreground font-medium mt-1">{PATRIMONY_LABELS[p.type] ?? p.type}</p>
                <p className="text-xs text-muted-foreground">Nível {p.level}</p>
              </div>
            ))}
          </div>
        </div>
      </div>
    </GameLayout>
  );
};

export default Dashboard;
