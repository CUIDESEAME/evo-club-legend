import { Navigate } from "react-router-dom";
import { useAuth } from "@/lib/auth";
import { useClub, usePlayers } from "@/hooks/useClub";
import GameLayout from "@/components/GameLayout";
import { POSITION_LABELS, POSITION_ABBREVIATIONS, formatMoney, getOverallRating } from "@/lib/gameUtils";
import { supabase } from "@/integrations/supabase/client";
import { useQueryClient } from "@tanstack/react-query";
import { useToast } from "@/hooks/use-toast";
import { Button } from "@/components/ui/button";
import { useState } from "react";
import { Save, ChevronDown, ChevronUp } from "lucide-react";

const EDITABLE_ATTRS = [
  "reflexos", "posicionamento", "jogo_aereo", "desarme", "armacao", "passe", "tecnica", "chute",
  "velocidade", "forca", "resistencia", "forma",
  "potencial_velocidade", "potencial_forca", "potencial_resistencia", "potencial_forma",
  "talento", "moral", "entrosamento", "experiencia", "lideranca", "inteligencia", "agressividade", "honestidade",
] as const;

const ATTR_LABELS: Record<string, string> = {
  reflexos: "Reflexos", posicionamento: "Posicionamento", jogo_aereo: "Jogo Aéreo",
  desarme: "Desarme", armacao: "Armação", passe: "Passe", tecnica: "Técnica", chute: "Chute",
  velocidade: "Velocidade", forca: "Força", resistencia: "Resistência", forma: "Forma",
  potencial_velocidade: "Pot. Veloc.", potencial_forca: "Pot. Força",
  potencial_resistencia: "Pot. Resist.", potencial_forma: "Pot. Forma",
  talento: "Talento", moral: "Moral", entrosamento: "Entrosamento",
  experiencia: "Experiência", lideranca: "Liderança", inteligencia: "Inteligência",
  agressividade: "Agressividade", honestidade: "Honestidade",
};

const POSITIONS = ["goleiro", "libero", "zagueiro", "lateral", "volante", "meia", "ala", "meia_atacante", "ponteiro", "atacante"];

const AdminEditor = () => {
  const { user, loading: authLoading } = useAuth();
  const { data: club, isLoading } = useClub();
  const { data: players } = usePlayers(club?.id);
  const queryClient = useQueryClient();
  const { toast } = useToast();
  const [selectedId, setSelectedId] = useState<string | null>(null);
  const [edits, setEdits] = useState<Record<string, any>>({});
  const [saving, setSaving] = useState(false);
  const [expanded, setExpanded] = useState<string | null>(null);

  if (authLoading || isLoading) return <div className="min-h-screen bg-background flex items-center justify-center"><div className="w-8 h-8 border-2 border-primary border-t-transparent rounded-full animate-spin" /></div>;
  if (!user) return <Navigate to="/auth" replace />;
  if (!club) return <Navigate to="/criar-clube" replace />;

  const selected = players?.find(p => p.id === selectedId);

  const startEdit = (player: any) => {
    setSelectedId(player.id);
    setEdits({
      name: player.name,
      age: player.age,
      position: player.position,
      salary: player.salary,
      market_value: player.market_value,
      ...Object.fromEntries(EDITABLE_ATTRS.map(a => [a, player[a]])),
    });
    setExpanded(player.id);
  };

  const updateEdit = (key: string, value: any) => {
    setEdits(prev => ({ ...prev, [key]: value }));
  };

  const savePlayer = async () => {
    if (!selectedId) return;
    setSaving(true);
    const { error } = await supabase
      .from("players")
      .update(edits)
      .eq("id", selectedId);
    if (error) {
      toast({ title: "Erro", description: error.message, variant: "destructive" });
    } else {
      toast({ title: "Jogador atualizado!" });
      queryClient.invalidateQueries({ queryKey: ["players"] });
    }
    setSaving(false);
  };

  return (
    <GameLayout>
      <div className="space-y-6">
        <h1 className="font-heading text-3xl font-bold text-foreground">Editor de Jogadores</h1>
        <p className="text-sm text-muted-foreground">Edite nomes, posições e atributos dos jogadores do seu elenco.</p>

        <div className="space-y-2">
          {players?.map(p => (
            <div key={p.id} className="bg-glass rounded-xl overflow-hidden">
              <button
                onClick={() => expanded === p.id ? setExpanded(null) : startEdit(p)}
                className="w-full flex items-center justify-between p-4 text-left"
              >
                <div className="flex items-center gap-3">
                  <span className="text-xs px-2 py-0.5 rounded bg-secondary text-foreground font-heading">
                    {POSITION_ABBREVIATIONS[p.position]}
                  </span>
                  <span className="text-sm font-medium text-foreground">{p.name}</span>
                  <span className="text-xs text-muted-foreground">{p.age} anos • OVR {getOverallRating(p)}</span>
                </div>
                {expanded === p.id ? <ChevronUp size={16} /> : <ChevronDown size={16} />}
              </button>

              {expanded === p.id && selectedId === p.id && (
                <div className="px-4 pb-4 space-y-4 border-t border-border/30 pt-4">
                  <div className="grid grid-cols-2 sm:grid-cols-3 gap-3">
                    <div>
                      <label className="text-xs text-muted-foreground">Nome</label>
                      <input
                        className="w-full bg-secondary text-foreground text-sm rounded p-1.5 border border-border/30"
                        value={edits.name ?? ""}
                        onChange={e => updateEdit("name", e.target.value)}
                      />
                    </div>
                    <div>
                      <label className="text-xs text-muted-foreground">Idade</label>
                      <input
                        type="number"
                        className="w-full bg-secondary text-foreground text-sm rounded p-1.5 border border-border/30"
                        value={edits.age ?? 0}
                        onChange={e => updateEdit("age", parseInt(e.target.value) || 0)}
                      />
                    </div>
                    <div>
                      <label className="text-xs text-muted-foreground">Posição</label>
                      <select
                        className="w-full bg-secondary text-foreground text-sm rounded p-1.5 border border-border/30"
                        value={edits.position ?? ""}
                        onChange={e => updateEdit("position", e.target.value)}
                      >
                        {POSITIONS.map(pos => (
                          <option key={pos} value={pos}>{POSITION_LABELS[pos]}</option>
                        ))}
                      </select>
                    </div>
                    <div>
                      <label className="text-xs text-muted-foreground">Salário/sem</label>
                      <input
                        type="number"
                        className="w-full bg-secondary text-foreground text-sm rounded p-1.5 border border-border/30"
                        value={edits.salary ?? 0}
                        onChange={e => updateEdit("salary", parseInt(e.target.value) || 0)}
                      />
                    </div>
                    <div>
                      <label className="text-xs text-muted-foreground">Valor Mercado</label>
                      <input
                        type="number"
                        className="w-full bg-secondary text-foreground text-sm rounded p-1.5 border border-border/30"
                        value={edits.market_value ?? 0}
                        onChange={e => updateEdit("market_value", parseInt(e.target.value) || 0)}
                      />
                    </div>
                  </div>

                  <div>
                    <h4 className="text-xs text-muted-foreground font-heading mb-2">ATRIBUTOS</h4>
                    <div className="grid grid-cols-3 sm:grid-cols-4 lg:grid-cols-6 gap-2">
                      {EDITABLE_ATTRS.map(attr => (
                        <div key={attr}>
                          <label className="text-xs text-muted-foreground truncate block">{ATTR_LABELS[attr]}</label>
                          <input
                            type="number"
                            min={0}
                            max={16}
                            className="w-full bg-secondary text-foreground text-sm rounded p-1 border border-border/30 text-center"
                            value={edits[attr] ?? 0}
                            onChange={e => updateEdit(attr, Math.min(16, Math.max(0, parseInt(e.target.value) || 0)))}
                          />
                        </div>
                      ))}
                    </div>
                  </div>

                  <Button onClick={savePlayer} disabled={saving} className="font-heading">
                    <Save size={14} /> {saving ? "Salvando..." : "Salvar Alterações"}
                  </Button>
                </div>
              )}
            </div>
          ))}
        </div>
      </div>
    </GameLayout>
  );
};

export default AdminEditor;
