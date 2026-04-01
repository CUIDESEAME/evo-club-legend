import { Navigate } from "react-router-dom";
import { useAuth } from "@/lib/auth";
import { useClub, useTrainingConfig } from "@/hooks/useClub";
import GameLayout from "@/components/GameLayout";
import { supabase } from "@/integrations/supabase/client";
import { useState } from "react";
import { useQueryClient } from "@tanstack/react-query";
import { useToast } from "@/hooks/use-toast";
import { Button } from "@/components/ui/button";
import { Slider } from "@/components/ui/slider";

const PHYS_TYPES: Record<string, string> = {
  geral: "Geral",
  forca: "Força",
  velocidade: "Velocidade",
  resistencia: "Resistência",
  forma: "Forma",
};

const TECH_TYPES: Record<string, string> = {
  defesa: "Defesa",
  meio: "Meio-Campo",
  ataque: "Ataque",
};

const Treino = () => {
  const { user, loading: authLoading } = useAuth();
  const { data: club, isLoading } = useClub();
  const { data: config } = useTrainingConfig(club?.id);
  const queryClient = useQueryClient();
  const { toast } = useToast();
  const [saving, setSaving] = useState(false);

  const [physType, setPhysType] = useState<string | null>(null);
  const [techType, setTechType] = useState<string | null>(null);
  const [intensity, setIntensity] = useState<number | null>(null);

  if (authLoading || isLoading) return <div className="min-h-screen bg-background flex items-center justify-center"><div className="w-8 h-8 border-2 border-primary border-t-transparent rounded-full animate-spin" /></div>;
  if (!user) return <Navigate to="/auth" replace />;
  if (!club) return <Navigate to="/criar-clube" replace />;

  const currentPhys = physType ?? config?.physical_type ?? "geral";
  const currentTech = techType ?? config?.technical_type ?? "defesa";
  const currentIntensity = intensity ?? config?.physical_intensity ?? 50;

  const hasChanges =
    (physType !== null && physType !== config?.physical_type) ||
    (techType !== null && techType !== config?.technical_type) ||
    (intensity !== null && intensity !== config?.physical_intensity);

  const handleSave = async () => {
    if (!config) return;
    setSaving(true);
    const { error } = await supabase
      .from("training_config")
      .update({
        physical_type: currentPhys,
        technical_type: currentTech,
        physical_intensity: currentIntensity,
      })
      .eq("id", config.id);

    if (error) {
      toast({ title: "Erro", description: error.message, variant: "destructive" });
    } else {
      toast({ title: "Treino atualizado!", description: "As configurações foram salvas." });
      queryClient.invalidateQueries({ queryKey: ["training_config"] });
      setPhysType(null);
      setTechType(null);
      setIntensity(null);
    }
    setSaving(false);
  };

  return (
    <GameLayout>
      <div className="space-y-6">
        <div className="flex items-center justify-between">
          <div>
            <h1 className="font-heading text-3xl font-bold text-foreground">Treino</h1>
            <p className="text-muted-foreground">Configure os treinos do seu time</p>
          </div>
          {hasChanges && (
            <Button onClick={handleSave} disabled={saving} className="font-heading">
              {saving ? "Salvando..." : "Salvar Alterações"}
            </Button>
          )}
        </div>

        {config && (
          <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
            {/* Physical training */}
            <div className="bg-glass rounded-xl p-6 space-y-5">
              <h2 className="font-heading text-xl font-bold text-foreground">🏋️ Treino Físico</h2>
              <p className="text-xs text-muted-foreground">Todos os jogadores recebem treino físico</p>

              <div>
                <p className="text-sm text-muted-foreground mb-3">Tipo de treino:</p>
                <div className="grid grid-cols-2 sm:grid-cols-3 gap-2">
                  {Object.entries(PHYS_TYPES).map(([key, label]) => (
                    <button
                      key={key}
                      onClick={() => setPhysType(key)}
                      className={`px-3 py-2 rounded-lg text-sm font-heading transition-all border
                        ${currentPhys === key
                          ? "bg-primary/20 border-primary/40 text-primary"
                          : "bg-secondary/50 border-border text-muted-foreground hover:text-foreground hover:bg-secondary"
                        }`}
                    >
                      {label}
                    </button>
                  ))}
                </div>
              </div>

              <div>
                <div className="flex justify-between mb-2">
                  <p className="text-sm text-muted-foreground">Intensidade:</p>
                  <span className={`font-heading text-sm ${currentIntensity > 70 ? "text-destructive" : "text-foreground"}`}>
                    {currentIntensity}%
                  </span>
                </div>
                <Slider
                  value={[currentIntensity]}
                  onValueChange={([v]) => setIntensity(v)}
                  min={10}
                  max={100}
                  step={5}
                  className="w-full"
                />
                {currentIntensity > 70 && (
                  <p className="text-xs text-destructive mt-2">⚠️ Intensidade alta aumenta risco de lesão!</p>
                )}
                {currentIntensity < 30 && (
                  <p className="text-xs text-accent mt-2">💤 Intensidade baixa = pouco progresso</p>
                )}
              </div>

              <div className="pt-2 border-t border-border">
                <p className="text-sm text-muted-foreground">
                  Preparador Físico: Nível <span className="text-foreground font-heading">{config.fitness_coach_level}</span>
                </p>
              </div>
            </div>

            {/* Technical training */}
            <div className="bg-glass rounded-xl p-6 space-y-5">
              <h2 className="font-heading text-xl font-bold text-foreground">⚽ Treino Técnico</h2>
              <p className="text-xs text-muted-foreground">Apenas quem jogou na semana recebe</p>

              <div>
                <p className="text-sm text-muted-foreground mb-3">Foco tático:</p>
                <div className="grid grid-cols-3 gap-2">
                  {Object.entries(TECH_TYPES).map(([key, label]) => (
                    <button
                      key={key}
                      onClick={() => setTechType(key)}
                      className={`px-3 py-2 rounded-lg text-sm font-heading transition-all border
                        ${currentTech === key
                          ? "bg-accent/20 border-accent/40 text-accent"
                          : "bg-secondary/50 border-border text-muted-foreground hover:text-foreground hover:bg-secondary"
                        }`}
                    >
                      {label}
                    </button>
                  ))}
                </div>
              </div>

              <div className="bg-secondary/50 rounded-lg p-4 text-xs text-muted-foreground space-y-1">
                <p className="font-heading text-foreground text-sm mb-2">Como funciona:</p>
                <p>• Defesa → melhora desarme, posicionamento, jogo aéreo</p>
                <p>• Meio → melhora armação, passe, técnica</p>
                <p>• Ataque → melhora chute, técnica, posicionamento</p>
              </div>

              <div className="pt-2 border-t border-border">
                <p className="text-sm text-muted-foreground">
                  Treinador: Nível <span className="text-foreground font-heading">{config.coach_level}</span>
                </p>
              </div>

              <div className="bg-primary/5 border border-primary/20 rounded-lg p-3 text-xs text-muted-foreground">
                <p>💡 O treino atualiza a cada <span className="text-foreground font-heading">30 minutos</span>.</p>
                <p>Jogadores sem atuação na semana NÃO evoluem tecnicamente.</p>
              </div>
            </div>
          </div>
        )}
      </div>
    </GameLayout>
  );
};

export default Treino;
