import { Navigate } from "react-router-dom";
import { useAuth } from "@/lib/auth";
import { useClub, usePatrimony } from "@/hooks/useClub";
import GameLayout from "@/components/GameLayout";
import { PATRIMONY_LABELS, PATRIMONY_ICONS, formatMoney } from "@/lib/gameUtils";

const Patrimonio = () => {
  const { user, loading: authLoading } = useAuth();
  const { data: club, isLoading } = useClub();
  const { data: patrimony } = usePatrimony(club?.id);

  if (authLoading || isLoading) return <div className="min-h-screen bg-background flex items-center justify-center"><div className="w-8 h-8 border-2 border-primary border-t-transparent rounded-full animate-spin" /></div>;
  if (!user) return <Navigate to="/auth" replace />;
  if (!club) return <Navigate to="/criar-clube" replace />;

  return (
    <GameLayout>
      <div className="space-y-6">
        <h1 className="font-heading text-3xl font-bold text-foreground">Patrimônio</h1>
        <p className="text-muted-foreground">Gerencie as instalações do seu clube</p>

        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
          {patrimony?.map(p => (
            <div key={p.id} className="bg-glass rounded-xl p-6 hover:glow-green transition-all">
              <div className="flex items-center gap-3 mb-4">
                <span className="text-3xl">{PATRIMONY_ICONS[p.type] ?? "🏢"}</span>
                <div>
                  <h3 className="font-heading text-lg font-bold text-foreground">
                    {PATRIMONY_LABELS[p.type] ?? p.type}
                  </h3>
                  <p className="text-xs text-muted-foreground">Nível {p.level} / {p.max_level}</p>
                </div>
              </div>

              {/* Level bar */}
              <div className="w-full h-2 bg-secondary rounded-full mb-3">
                <div
                  className="h-full bg-primary rounded-full transition-all"
                  style={{ width: `${(p.level / p.max_level) * 100}%` }}
                />
              </div>

              <div className="flex justify-between text-xs text-muted-foreground">
                <span>Manutenção: {formatMoney(p.maintenance_cost)}/sem</span>
                {p.construction_weeks_remaining > 0 && (
                  <span className="text-accent">🔨 {p.construction_weeks_remaining} sem</span>
                )}
              </div>
            </div>
          ))}
        </div>
      </div>
    </GameLayout>
  );
};

export default Patrimonio;
