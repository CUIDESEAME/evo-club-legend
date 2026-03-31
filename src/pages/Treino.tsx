import { Navigate } from "react-router-dom";
import { useAuth } from "@/lib/auth";
import { useClub, useTrainingConfig } from "@/hooks/useClub";
import GameLayout from "@/components/GameLayout";

const Treino = () => {
  const { user, loading: authLoading } = useAuth();
  const { data: club, isLoading } = useClub();
  const { data: config } = useTrainingConfig(club?.id);

  if (authLoading || isLoading) return <div className="min-h-screen bg-background flex items-center justify-center"><div className="w-8 h-8 border-2 border-primary border-t-transparent rounded-full animate-spin" /></div>;
  if (!user) return <Navigate to="/auth" replace />;
  if (!club) return <Navigate to="/criar-clube" replace />;

  const physTypes: Record<string, string> = { geral: "Geral", forca: "Força", velocidade: "Velocidade", resistencia: "Resistência", forma: "Forma" };
  const techTypes: Record<string, string> = { defesa: "Defesa", meio: "Meio", ataque: "Ataque" };

  return (
    <GameLayout>
      <div className="space-y-6">
        <h1 className="font-heading text-3xl font-bold text-foreground">Treino</h1>
        <p className="text-muted-foreground">Configure os treinos do seu time</p>

        {config && (
          <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
            {/* Physical training */}
            <div className="bg-glass rounded-xl p-6 space-y-4">
              <h2 className="font-heading text-xl font-bold text-foreground">🏋️ Treino Físico</h2>
              <p className="text-xs text-muted-foreground">Todos os jogadores recebem</p>

              <div>
                <p className="text-sm text-muted-foreground mb-2">Tipo: <span className="text-foreground font-medium">{physTypes[config.physical_type]}</span></p>
                <p className="text-sm text-muted-foreground mb-2">Intensidade: <span className="text-foreground font-medium">{config.physical_intensity}%</span></p>
                <div className="w-full h-2 bg-secondary rounded-full">
                  <div className="h-full bg-accent rounded-full" style={{ width: `${config.physical_intensity}%` }} />
                </div>
                {config.physical_intensity > 70 && (
                  <p className="text-xs text-destructive mt-1">⚠️ Intensidade alta = risco de lesão!</p>
                )}
              </div>

              <div>
                <p className="text-sm text-muted-foreground">Preparador Físico: Nível <span className="text-foreground font-heading">{config.fitness_coach_level}</span></p>
              </div>
            </div>

            {/* Technical training */}
            <div className="bg-glass rounded-xl p-6 space-y-4">
              <h2 className="font-heading text-xl font-bold text-foreground">⚽ Treino Técnico</h2>
              <p className="text-xs text-muted-foreground">Apenas quem jogou na semana</p>

              <div>
                <p className="text-sm text-muted-foreground mb-2">Foco: <span className="text-foreground font-medium">{techTypes[config.technical_type]}</span></p>
              </div>

              <div>
                <p className="text-sm text-muted-foreground">Treinador: Nível <span className="text-foreground font-heading">{config.coach_level}</span></p>
              </div>

              <div className="bg-secondary/50 rounded-lg p-3 text-xs text-muted-foreground">
                <p>💡 O treino atualiza a cada 30 minutos.</p>
                <p>Jogadores que não atuaram na semana NÃO recebem treino técnico.</p>
              </div>
            </div>
          </div>
        )}
      </div>
    </GameLayout>
  );
};

export default Treino;
