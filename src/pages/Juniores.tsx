import { Navigate } from "react-router-dom";
import { useAuth } from "@/lib/auth";
import { useClub, usePlayers } from "@/hooks/useClub";
import GameLayout from "@/components/GameLayout";
import { POSITION_LABELS, ATTRIBUTE_LEVELS, formatMoney, getAttributeColor } from "@/lib/gameUtils";
import { supabase } from "@/integrations/supabase/client";
import { useQuery, useQueryClient } from "@tanstack/react-query";
import { useToast } from "@/hooks/use-toast";
import { Button } from "@/components/ui/button";
import { useState } from "react";
import { Baby, ArrowUp, Eye, EyeOff, Trash2, Coins } from "lucide-react";
import type { Tables } from "@/integrations/supabase/types";

type Junior = Tables<"juniors">;

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

function useJuniorInvestments(clubId: string | undefined) {
  return useQuery({
    queryKey: ["junior_investments", clubId],
    queryFn: async () => {
      if (!clubId) return [];
      const { data, error } = await supabase
        .from("junior_investments")
        .select("*")
        .eq("club_id", clubId);
      if (error) throw error;
      return data ?? [];
    },
    enabled: !!clubId,
  });
}

const POSITIONS = ["goleiro", "zagueiro", "lateral", "volante", "meia", "atacante"] as const;
const FIRST_NAMES = ["Lucas", "Pedro", "Gabriel", "Rafael", "Felipe", "Matheus", "Bruno", "Diego", "André", "Caio", "Vinícius", "Thiago", "Gustavo", "Igor", "Leonardo"];
const LAST_NAMES = ["Silva", "Santos", "Oliveira", "Souza", "Lima", "Pereira", "Costa", "Almeida", "Ferreira", "Rocha", "Nascimento", "Araújo", "Ribeiro", "Cardoso", "Moreira"];

const SKILL_LABELS: Record<string, string> = {
  reflexos: "Reflexos", posicionamento: "Posicionamento", jogo_aereo: "Jogo Aéreo",
  desarme: "Desarme", armacao: "Armação", passe: "Passe",
  tecnica: "Técnica", chute: "Chute", velocidade: "Velocidade",
  forca: "Força", resistencia: "Resistência", forma: "Forma",
  experiencia: "Experiência", lideranca: "Liderança", inteligencia: "Inteligência",
  agressividade: "Agressividade",
};

function randomName() {
  return `${FIRST_NAMES[Math.floor(Math.random() * FIRST_NAMES.length)]} ${LAST_NAMES[Math.floor(Math.random() * LAST_NAMES.length)]}`;
}

// Estimate junior potential skills based on quality and talent
function estimateSkills(junior: Junior) {
  const base = junior.quality;
  const talent = junior.talento;
  const skills: Record<string, number> = {};
  const keys = Object.keys(SKILL_LABELS);
  
  for (const key of keys) {
    // Generate a deterministic-ish value based on the junior's id hash + key
    const hash = junior.id.split("").reduce((a, c) => a + c.charCodeAt(0), 0);
    const keyHash = key.split("").reduce((a, c) => a + c.charCodeAt(0), 0);
    const seed = (hash * keyHash) % 100;
    
    let value: number;
    if (junior.revealed) {
      // Revealed: show actual estimated values from quality + talent
      value = Math.max(1, Math.min(16, base + Math.floor((seed % (talent + 1)))));
    } else {
      // Not revealed: show "???"
      value = 0;
    }
    skills[key] = value;
  }
  return skills;
}

const Juniores = () => {
  const { user, loading: authLoading } = useAuth();
  const { data: club, isLoading } = useClub();
  const { data: juniors } = useJuniors(club?.id);
  const { data: players } = usePlayers(club?.id);
  const { data: investments } = useJuniorInvestments(club?.id);
  const queryClient = useQueryClient();
  const { toast } = useToast();
  const [acting, setActing] = useState(false);

  if (authLoading || isLoading) return <div className="min-h-screen bg-background flex items-center justify-center"><div className="w-8 h-8 border-2 border-primary border-t-transparent rounded-full animate-spin" /></div>;
  if (!user) return <Navigate to="/auth" replace />;
  if (!club) return <Navigate to="/criar-clube" replace />;

  const maxJuniors = 8;
  const maxPlayers = 50;
  const gameWeek = (club as any).game_week ?? 0;

  const generateJunior = async () => {
    if ((juniors?.length ?? 0) >= maxJuniors) {
      toast({ title: "Base lotada", description: `Máximo de ${maxJuniors} juniores.`, variant: "destructive" });
      return;
    }
    setActing(true);
    const pos = POSITIONS[Math.floor(Math.random() * POSITIONS.length)];
    const talent = Math.floor(Math.random() * 6) + 1;
    const quality = Math.floor(Math.random() * 3) + 1;
    const age = 16 + Math.floor(Math.random() * 3); // 16, 17 or 18
    const { error } = await supabase.from("juniors").insert({
      club_id: club.id,
      name: randomName(),
      position: pos,
      talento: talent,
      quality,
      age,
      weeks_to_reveal: 4 + Math.floor(Math.random() * 8),
    });
    if (error) toast({ title: "Erro", description: error.message, variant: "destructive" });
    else toast({ title: "Novo junior na base!" });
    queryClient.invalidateQueries({ queryKey: ["juniors"] });
    setActing(false);
  };

  const investInJunior = async (junior: Junior) => {
    const alreadyInvested = investments?.some(
      inv => inv.junior_id === junior.id && inv.week_number === gameWeek
    );
    if (alreadyInvested) {
      toast({ title: "Já investido", description: "Você já investiu neste júnior esta semana.", variant: "destructive" });
      return;
    }
    setActing(true);
    const { data, error } = await supabase.rpc("invest_in_junior", {
      p_club_id: club.id,
      p_junior_id: junior.id,
    });
    if (error) {
      toast({ title: "Erro", description: error.message, variant: "destructive" });
    } else {
      const result = data as { improved: boolean; cost: number };
      toast({
        title: result.improved ? "Melhoria! ⭐" : "Sem efeito",
        description: result.improved
          ? `${junior.name} melhorou! (-${formatMoney(result.cost)})`
          : `Investimento feito, mas sem melhoria visível. (-${formatMoney(result.cost)})`,
      });
      queryClient.invalidateQueries({ queryKey: ["juniors"] });
      queryClient.invalidateQueries({ queryKey: ["junior_investments"] });
      queryClient.invalidateQueries({ queryKey: ["club"] });
      queryClient.invalidateQueries({ queryKey: ["transactions"] });
    }
    setActing(false);
  };

  const promoteJunior = async (junior: Junior) => {
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

  const dismissJunior = async (junior: Junior) => {
    if (!confirm(`Dispensar ${junior.name}?`)) return;
    setActing(true);
    await supabase.from("juniors").delete().eq("id", junior.id);
    toast({ title: `${junior.name} dispensado da base.` });
    queryClient.invalidateQueries({ queryKey: ["juniors"] });
    setActing(false);
  };

  const hasInvestedThisWeek = (juniorId: string) =>
    investments?.some(inv => inv.junior_id === juniorId && inv.week_number === gameWeek) ?? false;

  return (
    <GameLayout>
      <div className="space-y-6">
        <div className="flex items-center justify-between">
          <div>
            <h1 className="font-heading text-3xl font-bold text-foreground">Juniores</h1>
            <p className="text-muted-foreground">{juniors?.length ?? 0}/{maxJuniors} na base • Semana {gameWeek}</p>
          </div>
          <Button onClick={generateJunior} disabled={acting || (juniors?.length ?? 0) >= maxJuniors} className="font-heading">
            <Baby size={16} /> Buscar Jovem
          </Button>
        </div>

        <div className="bg-glass rounded-xl p-4 text-xs text-muted-foreground space-y-1">
          <p>• Juniores treinam automaticamente durante o período de espera</p>
          <p>• Investir custa R$ 15.000 (máx 1x por júnior por semana, sem garantia)</p>
          <p>• A promoção só é possível após a revelação do talento</p>
          <p>• Saem com 16, 17 ou 18 anos</p>
        </div>

        <div className="grid grid-cols-1 lg:grid-cols-2 gap-4">
          {juniors?.map(j => {
            const skills = estimateSkills(j);
            const invested = hasInvestedThisWeek(j.id);

            return (
              <div key={j.id} className="bg-glass rounded-xl p-5 space-y-3">
                <div className="flex items-center justify-between">
                  <div>
                    <h3 className="font-heading text-foreground font-bold">{j.name}</h3>
                    <p className="text-xs text-muted-foreground">{POSITION_LABELS[j.position]} • {j.age} anos</p>
                  </div>
                  <span className="text-2xl">👶</span>
                </div>

                <div className="grid grid-cols-2 gap-x-4 gap-y-1 text-xs">
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
                        <EyeOff size={12} /> {j.weeks_to_reveal} sem
                      </span>
                    )}
                  </div>
                </div>

                {/* 16 Skills grid */}
                <div className="border-t border-border/30 pt-2">
                  <p className="text-[10px] text-muted-foreground mb-1 font-heading">HABILIDADES ESTIMADAS</p>
                  <div className="grid grid-cols-2 gap-x-4 gap-y-0.5 text-[11px]">
                    {Object.entries(SKILL_LABELS).map(([key, label]) => (
                      <div key={key} className="flex justify-between">
                        <span className="text-muted-foreground">{label}</span>
                        {j.revealed ? (
                          <span className={`font-heading ${getAttributeColor(skills[key])}`}>
                            {skills[key]}
                          </span>
                        ) : (
                          <span className="text-muted-foreground/50">???</span>
                        )}
                      </div>
                    ))}
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
                  <Button
                    size="sm"
                    variant="outline"
                    onClick={() => investInJunior(j)}
                    disabled={acting || invested || j.revealed}
                    className="font-heading"
                    title={invested ? "Já investido esta semana" : "Investir R$ 15.000"}
                  >
                    <Coins size={14} />
                    {invested ? "Investido" : "Investir"}
                  </Button>
                  <Button size="sm" variant="ghost" onClick={() => dismissJunior(j)} disabled={acting}>
                    <Trash2 size={14} className="text-destructive" />
                  </Button>
                </div>
              </div>
            );
          })}

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
