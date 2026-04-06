import { Navigate } from "react-router-dom";
import { useAuth } from "@/lib/auth";
import { useClub } from "@/hooks/useClub";
import { usePlayers, usePatrimony, useStadiumSectors, useFinancialTransactions } from "@/hooks/useClub";
import GameLayout from "@/components/GameLayout";
import { formatMoney, POSITION_ABBREVIATIONS, PATRIMONY_LABELS, PATRIMONY_ICONS, getOverallRating } from "@/lib/gameUtils";
import { Users, Building2, Coins, Trophy, TrendingUp, TrendingDown, Newspaper } from "lucide-react";
import { type LucideIcon } from "lucide-react";
import { useMemo } from "react";

function StatCard({ icon: Icon, label, value, sub, color = "text-foreground" }: {
  icon: LucideIcon; label: string; value: string; sub?: string; color?: string;
}) {
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

const INCOME_TYPES = ['partida', 'socios', 'lojas', 'clube_social', 'patrocinio', 'premio', 'mercado'];
const EXPENSE_TYPES = ['salarios', 'manutencao', 'marketing', 'juniores', 'patrimonio', 'juros', 'multa', 'despesas', 'emprestimo', 'mercado'];

const TYPE_LABELS: Record<string, string> = {
  partida: "Jogos (renda + prêmios)",
  socios: "Sócios",
  lojas: "Lojas",
  clube_social: "Clube Social",
  patrocinio: "Patrocínio/Marketing",
  premio: "Prêmios de liga",
  mercado: "Mercado (compra/venda)",
  salarios: "Salários",
  manutencao: "Manutenção",
  marketing: "Investimento em marketing",
  juniores: "Juniores",
  patrimonio: "Obras/Patrimônio",
  juros: "Juros e encargos",
  multa: "Multas",
  despesas: "Despesas administrativas",
  emprestimo: "Empréstimos",
};

const SYSTEM_NEWS = [
  "💡 Dica: Evolua as Lojas e o Clube Social para gerar receita passiva semanal!",
  "📢 O nível de Marketing aumenta patrocínios e atrai mais sócios e torcedores.",
  "⚽ Jogadores que jogam ganham entrosamento (+12.5%) e experiência (+0.5%) por jogo.",
  "🏋️ O Centro de Treinamento melhora a eficácia dos treinos em +5% por nível.",
  "🤕 Intensidade de treino acima de 70% aumenta risco de lesões.",
  "📊 Fadiga acumula com jogos (+15%) e recupera semanalmente (-10%).",
  "👴 Jogadores com 28+ anos perdem atributos físicos no fim da temporada.",
  "💰 Salário dos jogadores é ajustado para 1% do valor de mercado a cada temporada.",
  "🏆 Prêmios de final de temporada: 1º R$500k, 2º R$300k, 3º R$150k.",
];

const Dashboard = () => {
  const { user, loading: authLoading } = useAuth();
  const { data: club, isLoading: clubLoading } = useClub();
  const { data: players } = usePlayers(club?.id);
  const { data: patrimony } = usePatrimony(club?.id);
  const { data: stadiumSectors } = useStadiumSectors(club?.id);
  const { data: transactions } = useFinancialTransactions(club?.id);

  // Mini balance sheet from last 50 transactions
  const balanceSheet = useMemo(() => {
    if (!transactions?.length) return { income: {} as Record<string, number>, expenses: {} as Record<string, number>, totalIncome: 0, totalExpenses: 0 };
    const income: Record<string, number> = {};
    const expenses: Record<string, number> = {};
    let totalIncome = 0;
    let totalExpenses = 0;

    for (const t of transactions) {
      if (t.amount > 0) {
        income[t.type] = (income[t.type] ?? 0) + t.amount;
        totalIncome += t.amount;
      } else {
        expenses[t.type] = (expenses[t.type] ?? 0) + Math.abs(t.amount);
        totalExpenses += Math.abs(t.amount);
      }
    }
    return { income, expenses, totalIncome, totalExpenses };
  }, [transactions]);

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

  const totalCapacity = stadiumSectors?.reduce((sum, s) => sum + s.capacity, 0) ?? 0;
  const stadiumLevel = patrimony?.find(p => p.type === "estadio")?.level ?? 0;

  const randomNews = SYSTEM_NEWS[Math.floor(Date.now() / 60000) % SYSTEM_NEWS.length];

  return (
    <GameLayout>
      <div className="space-y-6">
        {/* Header */}
        <div>
          <h1 className="font-heading text-3xl font-bold text-foreground">{club.name}</h1>
          <p className="text-muted-foreground">
            Série {club.league} • {club.members.toLocaleString("pt-BR")} sócios • {club.fans.toLocaleString("pt-BR")} torcedores
          </p>
        </div>

        {/* System News */}
        <div className="bg-accent/10 border border-accent/20 rounded-xl p-4 flex items-start gap-3">
          <Newspaper size={18} className="text-accent mt-0.5 shrink-0" />
          <p className="text-sm text-foreground">{randomNews}</p>
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
            value={`${totalCapacity.toLocaleString("pt-BR")} lugares`}
            sub={`Nível ${stadiumLevel} / 10`}
          />
          <StatCard
            icon={Trophy}
            label="Liga"
            value={`Série ${club.league}`}
            sub={`Semana ${club.game_week}`}
          />
        </div>

        {/* Mini Balance Sheet */}
        <div className="bg-glass rounded-xl p-6">
          <h2 className="font-heading text-xl font-bold text-foreground mb-4">📊 Resumo Financeiro (últimas transações)</h2>
          <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
            {/* Income */}
            <div>
              <div className="flex items-center gap-2 mb-3">
                <TrendingUp size={16} className="text-primary" />
                <h3 className="font-heading text-sm font-bold text-primary">RECEITAS</h3>
              </div>
              <div className="space-y-1.5">
                {Object.entries(balanceSheet.income)
                  .sort(([,a], [,b]) => b - a)
                  .map(([type, amount]) => (
                    <div key={type} className="flex justify-between text-sm">
                      <span className="text-muted-foreground">{TYPE_LABELS[type] ?? type}</span>
                      <span className="text-primary font-heading">+{formatMoney(amount)}</span>
                    </div>
                  ))}
                <div className="border-t border-border pt-1.5 flex justify-between text-sm font-bold">
                  <span className="text-foreground">Total</span>
                  <span className="text-primary font-heading">+{formatMoney(balanceSheet.totalIncome)}</span>
                </div>
              </div>
            </div>

            {/* Expenses */}
            <div>
              <div className="flex items-center gap-2 mb-3">
                <TrendingDown size={16} className="text-destructive" />
                <h3 className="font-heading text-sm font-bold text-destructive">DESPESAS</h3>
              </div>
              <div className="space-y-1.5">
                {Object.entries(balanceSheet.expenses)
                  .sort(([,a], [,b]) => b - a)
                  .map(([type, amount]) => (
                    <div key={type} className="flex justify-between text-sm">
                      <span className="text-muted-foreground">{TYPE_LABELS[type] ?? type}</span>
                      <span className="text-destructive font-heading">-{formatMoney(amount)}</span>
                    </div>
                  ))}
                <div className="border-t border-border pt-1.5 flex justify-between text-sm font-bold">
                  <span className="text-foreground">Total</span>
                  <span className="text-destructive font-heading">-{formatMoney(balanceSheet.totalExpenses)}</span>
                </div>
              </div>
            </div>
          </div>

          {/* Net */}
          <div className="mt-4 pt-3 border-t border-border flex justify-between items-center">
            <span className="font-heading text-sm font-bold text-foreground">RESULTADO LÍQUIDO</span>
            <span className={`font-heading text-lg font-bold ${balanceSheet.totalIncome - balanceSheet.totalExpenses >= 0 ? "text-primary" : "text-destructive"}`}>
              {formatMoney(balanceSheet.totalIncome - balanceSheet.totalExpenses)}
            </span>
          </div>
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
                    <th className="text-center pb-2">Fadiga</th>
                    <th className="text-right pb-2">Salário</th>
                  </tr>
                </thead>
                <tbody>
                  {players.slice(0, 8).map(p => (
                    <tr key={p.id} className="border-b border-border/50">
                      <td className="py-2 text-foreground">
                        {p.name}
                        {p.is_captain && <span className="text-accent ml-1">©</span>}
                        {p.is_for_sale && <span className="text-primary ml-1">💰</span>}
                        {p.is_injured && <span className="text-destructive ml-1">🤕</span>}
                      </td>
                      <td className="text-center">
                        <span className="text-xs px-2 py-0.5 rounded bg-secondary text-foreground font-heading">
                          {POSITION_ABBREVIATIONS[p.position] ?? p.position}
                        </span>
                      </td>
                      <td className="text-center text-muted-foreground">{p.age}</td>
                      <td className="text-center font-heading text-primary">{getOverallRating(p)}</td>
                      <td className="text-center">
                        <span className={`text-xs font-heading ${(p as any).fadiga > 60 ? "text-destructive" : (p as any).fadiga > 30 ? "text-accent" : "text-primary"}`}>
                          {(p as any).fadiga ?? 0}%
                        </span>
                      </td>
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
                {p.construction_weeks_remaining > 0 && (
                  <p className="text-xs text-accent">🔨 {p.construction_weeks_remaining}sem</p>
                )}
              </div>
            ))}
          </div>
        </div>
      </div>
    </GameLayout>
  );
};

export default Dashboard;
