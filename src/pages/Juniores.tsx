import { Navigate } from "react-router-dom";
import { useAuth } from "@/lib/auth";
import { useClub, usePlayers } from "@/hooks/useClub";
import GameLayout from "@/components/GameLayout";
import { POSITION_LABELS, ATTRIBUTE_LEVELS, formatMoney } from "@/lib/gameUtils";
import { supabase } from "@/integrations/supabase/client";
import { useQuery, useQueryClient } from "@tanstack/react-query";
import { useToast } from "@/hooks/use-toast";
import { Button } from "@/components/ui/button";
import { useState } from "react";
import { Baby, ArrowUp, Eye, EyeOff, Trash2 } from "lucide-react";

function useJuniors(clubId: string | undefined) {
  return useQuery({
    queryKey: ["juniors", clubId],
    queryFn: async () => {
      if (!clubId) return [];
      const { data, error } = await supabase
        .from("juniors")
        .select("*")
        .eq("club_id", clubId)
        .order("created_at");
      if (error) throw error;
      return data ?? [];
    },
    enabled: !!clubId,
  });
}

const POSITIONS = ["goleiro", "zagueiro", "lateral", "volante", "meia", "atacante"] as const;
const FIRST_NAMES = ["Lucas", "Pedro", "Gabriel", "Rafael", "Felipe", "Matheus", "Bruno", "Diego", "André", "Caio", "Vinícius", "Thiago", "Gustavo", "Igor", "Leonardo"];
const LAST_NAMES = ["Silva", "Santos", "Oliveira", "Souza", "Lima", "Pereira", "Costa", "Almeida", "Ferreira", "Rocha", "Nascimento", "Araújo", "Ribeiro", "Cardoso", "Moreira"];

function randomName() {
  return `${FIRST_NAMES[Math.floor(Math.random() * FIRST_NAMES.length)]} ${LAST_NAMES[Math.floor(Math.random() * LAST_NAMES.length)]}`;
}

const Juniores = () => {
  const { user, loading: authLoading } = useAuth();
  const { data: club, isLoading } = useClub();
  const { data: juniors } = useJuniors(club?.id);
  const { data: players } = usePlayers(club?.id);
  const queryClient = useQueryClient();
  const { toast } = useToast();
  const [acting, setActing] = useState(false);

  if (authLoading || isLoading) return <div className="min-h-screen bg-background flex items-center justify-center"><div className="w-8 h-8 border-2 border-primary border-t-transparent rounded-full animate-spin" /></div>;
  if (!user) return <Navigate to="/auth" replace />;
  if (!club) return <Navigate to="/criar-clube" replace />;

  const maxJuniors = 8;
  const maxPlayers = 50;

  const generateJunior = async () => {
    if ((juniors?.length ?? 0) >= maxJuniors) {
      toast({ title: "Base lotada", description: `Máximo de ${maxJuniors} juniores.`, variant: "destructive" });
      return;
    }
    setActing(true);
    const pos = POSITIONS[Math.floor(Math.random() * POSITIONS.length)];
    const talent = Math.floor(Math.random() * 6) + 1; // 1-6
    const quality = Math.floor(Math.random() * 3) + 1; // 1-3
    const { error } = await supabase.from("juniors").insert({
      club_id: club.id,
      name: randomName(),
      position: pos,
      talento: talent,
      quality,
      age: 15 + Math.floor(Math.random() * 3),
      weeks_to_reveal: 4 + Math.floor(Math.random() * 8),
    });
    if (error) toast({ title: "Erro", description: error.message, variant: "destructive" });
    else toast({ title: "Novo junior na base!" });
    queryClient.invalidateQueries({ queryKey: ["juniors"] });
    setActing(false);
  };

  const promoteJunior = async (junior: any) => {
    if ((players?.length ?? 0) >= maxPlayers) {
      toast({ title: "Elenco cheio", description: "Máximo de 50 jogadores.", variant: "destructive" });
      return;
    }
    if (!junior.revealed) {
      toast({ title: "Não revelado", description: "Aguarde a revelação do talento.", variant: "destructive" });
      return;
    }
    setActing(true);

    const baseAttr = Math.max(1, junior.quality + Math.floor(Math.random() * 3));
    const { error } = await supabase.from("players").insert({
      club_id: club.id,
      name: junior.name,
      position: junior.position,
      age: junior.age,
      talento: junior.talento,
      reflexos: baseAttr, posicionamento: baseAttr, jogo_aereo: baseAttr,
      desarme: baseAttr, armacao: baseAttr, passe: baseAttr,
      tecnica: baseAttr, chute: baseAttr,
      velocidade: Math.max(1, baseAttr - 1), forca: Math.max(1, baseAttr - 1),
      resistencia: Math.max(1, baseAttr - 1), forma: Math.max(1, baseAttr + 1),
      salary: 2000 + junior.quality * 1000,
      market_value: 10000 + junior.quality * 15000 + junior.talento * 10000,
    });

    if (error) {
      toast({ title: "Erro", description: error.message, variant: "destructive" });
      setActing(false);
      return;
    }

    await supabase.from("juniors").delete().eq("id", junior.id);
    toast({ title: `${junior.name} promovido ao elenco profissional!` });
    queryClient.invalidateQueries({ queryKey: ["juniors"] });
    queryClient.invalidateQueries({ queryKey: ["players"] });
    setActing(false);
  };

  const dismissJunior = async (junior: any) => {
    if (!confirm(`Dispensar ${junior.name}?`)) return;
    setActing(true);
    await supabase.from("juniors").delete().eq("id", junior.id);
    toast({ title: `${junior.name} dispensado da base.` });
    queryClient.invalidateQueries({ queryKey: ["juniors"] });
    setActing(false);
  };

  return (
    <GameLayout>
      <div className="space-y-6">
        <div className="flex items-center justify-between">
          <div>
            <h1 className="font-heading text-3xl font-bold text-foreground">Juniores</h1>
            <p className="text-muted-foreground">{juniors?.length ?? 0}/{maxJuniors} na base</p>
          </div>
          <Button onClick={generateJunior} disabled={acting || (juniors?.length ?? 0) >= maxJuniors} className="font-heading">
            <Baby size={16} /> Buscar Jovem
          </Button>
        </div>

        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-4">
          {juniors?.map(j => (
            <div key={j.id} className="bg-glass rounded-xl p-5 space-y-3">
              <div className="flex items-center justify-between">
                <div>
                  <h3 className="font-heading text-foreground font-bold">{j.name}</h3>
                  <p className="text-xs text-muted-foreground">{POSITION_LABELS[j.position]} • {j.age} anos</p>
                </div>
                <span className="text-2xl">👶</span>
              </div>

              <div className="space-y-1 text-xs">
                <div className="flex justify-between">
                  <span className="text-muted-foreground">Qualidade:</span>
                  <span className="text-foreground font-heading">{"⭐".repeat(j.quality)}</span>
                </div>
                <div className="flex justify-between">
                  <span className="text-muted-foreground">Talento:</span>
                  {j.revealed ? (
                    <span className="text-accent font-heading flex items-center gap-1">
                      <Eye size={12} /> {ATTRIBUTE_LEVELS[j.talento] ?? j.talento}
                    </span>
                  ) : (
                    <span className="text-muted-foreground flex items-center gap-1">
                      <EyeOff size={12} /> {j.weeks_to_reveal} sem para revelar
                    </span>
                  )}
                </div>
              </div>

              <div className="flex gap-2">
                <Button
                  size="sm"
                  onClick={() => promoteJunior(j)}
                  disabled={acting || !j.revealed}
                  className="flex-1 font-heading"
                  variant={j.revealed ? "default" : "outline"}
                >
                  <ArrowUp size={14} /> Promover
                </Button>
                <Button size="sm" variant="ghost" onClick={() => dismissJunior(j)} disabled={acting}>
                  <Trash2 size={14} className="text-destructive" />
                </Button>
              </div>
            </div>
          ))}

          {(juniors?.length ?? 0) === 0 && (
            <div className="col-span-full text-center py-12 text-muted-foreground">
              <Baby size={48} className="mx-auto mb-4 opacity-30" />
              <p>Nenhum jovem na base. Clique em "Buscar Jovem" para recrutar.</p>
            </div>
          )}
        </div>
      </div>
    </GameLayout>
  );
};

export default Juniores;
