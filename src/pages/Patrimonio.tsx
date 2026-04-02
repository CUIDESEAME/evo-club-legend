import { Navigate } from "react-router-dom";
import { useAuth } from "@/lib/auth";
import { useClub, usePatrimony } from "@/hooks/useClub";
import GameLayout from "@/components/GameLayout";
import { PATRIMONY_LABELS, PATRIMONY_ICONS, formatMoney } from "@/lib/gameUtils";
import { supabase } from "@/integrations/supabase/client";
import { useQueryClient } from "@tanstack/react-query";
import { useToast } from "@/hooks/use-toast";
import { Button } from "@/components/ui/button";
import { useState } from "react";
import { ArrowUp, Clock, Coins } from "lucide-react";

const UPGRADE_COSTS: Record<string, number[]> = {
  estadio: [0, 50000, 120000, 250000, 500000, 1000000, 2000000, 4000000, 7000000, 12000000],
  ct: [0, 30000, 80000, 180000, 400000, 800000, 1500000, 3000000, 5000000, 9000000],
  academia: [0, 20000, 50000, 120000, 250000, 500000, 1000000, 2000000, 3500000, 6000000],
  alojamento: [0, 15000, 40000, 90000, 200000, 400000, 800000, 1500000, 2500000, 4500000],
  marketing: [0, 10000, 30000, 70000, 150000, 300000, 600000, 1200000, 2000000, 3500000],
  clube_social: [0, 10000, 25000, 60000, 130000, 260000, 520000, 1000000, 1800000, 3000000],
  lojas: [0, 8000, 20000, 50000, 110000, 220000, 440000, 880000, 1500000, 2500000],
};

const UPGRADE_WEEKS: Record<string, number[]> = {
  estadio: [0, 2, 3, 4, 6, 8, 10, 14, 18, 24],
  ct: [0, 1, 2, 3, 4, 6, 8, 10, 14, 18],
  academia: [0, 1, 2, 3, 4, 5, 6, 8, 10, 14],
  alojamento: [0, 1, 2, 2, 3, 4, 5, 6, 8, 10],
  marketing: [0, 1, 1, 2, 2, 3, 4, 5, 6, 8],
  clube_social: [0, 1, 1, 2, 2, 3, 4, 5, 6, 8],
  lojas: [0, 1, 1, 2, 2, 3, 3, 4, 5, 6],
};

const MAINTENANCE_PER_LEVEL = 2000;

const Patrimonio = () => {
  const { user, loading: authLoading } = useAuth();
  const { data: club, isLoading } = useClub();
  const { data: patrimony } = usePatrimony(club?.id);
  const queryClient = useQueryClient();
  const { toast } = useToast();
  const [upgrading, setUpgrading] = useState<string | null>(null);

  if (authLoading || isLoading) return <div className="min-h-screen bg-background flex items-center justify-center"><div className="w-8 h-8 border-2 border-primary border-t-transparent rounded-full animate-spin" /></div>;
  if (!user) return <Navigate to="/auth" replace />;
  if (!club) return <Navigate to="/criar-clube" replace />;

  const handleUpgrade = async (item: { id: string; type: string; level: number; max_level: number; construction_weeks_remaining: number }) => {
    if (item.level >= item.max_level) return;
    if (item.construction_weeks_remaining > 0) return;

    const costs = UPGRADE_COSTS[item.type] ?? [];
    const weeks = UPGRADE_WEEKS[item.type] ?? [];
    const cost = costs[item.level] ?? 100000;
    const buildWeeks = weeks[item.level] ?? 2;
    const newMaintenance = (item.level + 1) * MAINTENANCE_PER_LEVEL;

    if (club.balance < cost) {
      toast({ title: "Sem fundos", description: `Você precisa de ${formatMoney(cost)} para esta melhoria.`, variant: "destructive" });
      return;
    }

    setUpgrading(item.id);

    const { error } = await supabase.rpc("upgrade_patrimony", {
      p_patrimony_id: item.id,
      p_club_id: club.id,
      p_cost: cost,
      p_build_weeks: buildWeeks,
      p_new_level: item.level + 1,
      p_new_maintenance: newMaintenance,
      p_description: `Melhoria: ${PATRIMONY_LABELS[item.type] ?? item.type} → Nível ${item.level + 1}`,
    });

    if (error) {
      toast({ title: "Erro", description: error.message, variant: "destructive" });
    } else {
      toast({ title: "Obra iniciada!", description: `${PATRIMONY_LABELS[item.type]} → Nível ${item.level + 1} (${buildWeeks} semanas)` });
      queryClient.invalidateQueries({ queryKey: ["patrimony"] });
      queryClient.invalidateQueries({ queryKey: ["club"] });
      queryClient.invalidateQueries({ queryKey: ["transactions"] });
    }
    setUpgrading(null);
  };

  const totalMaintenance = patrimony?.reduce((sum, p) => sum + p.maintenance_cost, 0) ?? 0;

  return (
    <GameLayout>
      <div className="space-y-6">
        <div>
          <h1 className="font-heading text-3xl font-bold text-foreground">Patrimônio</h1>
          <p className="text-muted-foreground">
            Manutenção total: <span className="text-foreground font-heading">{formatMoney(totalMaintenance)}/sem</span>
          </p>
        </div>

        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
          {patrimony?.map(p => {
            const costs = UPGRADE_COSTS[p.type] ?? [];
            const weeks = UPGRADE_WEEKS[p.type] ?? [];
            const nextCost = costs[p.level] ?? 0;
            const nextWeeks = weeks[p.level] ?? 0;
            const canUpgrade = p.level < p.max_level && p.construction_weeks_remaining === 0;
            const canAfford = club.balance >= nextCost;
            const isBuilding = p.construction_weeks_remaining > 0;

            return (
              <div key={p.id} className={`bg-glass rounded-xl p-6 transition-all ${isBuilding ? "border-accent/30 border" : "hover:glow-green"}`}>
                <div className="flex items-center gap-3 mb-4">
                  <span className="text-3xl">{PATRIMONY_ICONS[p.type] ?? "🏢"}</span>
                  <div className="flex-1">
                    <h3 className="font-heading text-lg font-bold text-foreground">
                      {PATRIMONY_LABELS[p.type] ?? p.type}
                    </h3>
                    <p className="text-xs text-muted-foreground">Nível {p.level} / {p.max_level}</p>
                  </div>
                </div>

                <div className="w-full h-2 bg-secondary rounded-full mb-3">
                  <div
                    className="h-full bg-primary rounded-full transition-all"
                    style={{ width: `${(p.level / p.max_level) * 100}%` }}
                  />
                </div>

                <div className="flex items-center gap-2 text-xs text-muted-foreground mb-4">
                  <Coins size={12} />
                  <span>Manutenção: {formatMoney(p.maintenance_cost)}/sem</span>
                </div>

                {isBuilding ? (
                  <div className="bg-accent/10 border border-accent/20 rounded-lg p-3 text-center">
                    <Clock size={16} className="text-accent mx-auto mb-1" />
                    <p className="text-sm font-heading text-accent">Em construção</p>
                    <p className="text-xs text-muted-foreground">{p.construction_weeks_remaining} semanas restantes</p>
                  </div>
                ) : canUpgrade ? (
                  <Button
                    onClick={() => handleUpgrade(p)}
                    disabled={!canAfford || upgrading === p.id}
                    variant={canAfford ? "default" : "outline"}
                    className="w-full font-heading"
                    size="sm"
                  >
                    <ArrowUp size={14} />
                    {upgrading === p.id ? "Melhorando..." : `Nível ${p.level + 1} • ${formatMoney(nextCost)} • ${nextWeeks}sem`}
                  </Button>
                ) : (
                  <p className="text-xs text-center text-accent font-heading">NÍVEL MÁXIMO ✨</p>
                )}
              </div>
            );
          })}
        </div>
      </div>
    </GameLayout>
  );
};

export default Patrimonio;
