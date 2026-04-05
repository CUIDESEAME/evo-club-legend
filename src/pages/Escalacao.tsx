import { Navigate } from "react-router-dom";
import { useAuth } from "@/lib/auth";
import { useClub, usePlayers } from "@/hooks/useClub";
import { useLineup } from "@/hooks/useLineup";
import GameLayout from "@/components/GameLayout";
import { POSITION_LABELS, POSITION_ABBREVIATIONS, getOverallRating, formatMoney } from "@/lib/gameUtils";
import { supabase } from "@/integrations/supabase/client";
import { useQueryClient } from "@tanstack/react-query";
import { useToast } from "@/hooks/use-toast";
import { Button } from "@/components/ui/button";
import { useState } from "react";
import { Save, RotateCcw } from "lucide-react";

const FORMATIONS: Record<string, string[]> = {
  "4-4-2": ["goleiro", "lateral", "zagueiro", "zagueiro", "lateral", "meia", "volante", "volante", "meia", "atacante", "atacante"],
  "4-3-3": ["goleiro", "lateral", "zagueiro", "zagueiro", "lateral", "volante", "meia", "meia", "ponteiro", "atacante", "ponteiro"],
  "3-5-2": ["goleiro", "zagueiro", "zagueiro", "zagueiro", "ala", "volante", "meia", "meia", "ala", "atacante", "atacante"],
  "4-2-3-1": ["goleiro", "lateral", "zagueiro", "zagueiro", "lateral", "volante", "volante", "meia", "meia_atacante", "meia", "atacante"],
  "4-5-1": ["goleiro", "lateral", "zagueiro", "zagueiro", "lateral", "meia", "volante", "meia", "ala", "ala", "atacante"],
  "3-4-3": ["goleiro", "zagueiro", "zagueiro", "zagueiro", "ala", "volante", "meia", "ala", "ponteiro", "atacante", "ponteiro"],
};

const Escalacao = () => {
  const { user, loading: authLoading } = useAuth();
  const { data: club, isLoading } = useClub();
  const { data: players } = usePlayers(club?.id);
  const { data: lineup, isLoading: lineupLoading } = useLineup(club?.id);
  const queryClient = useQueryClient();
  const { toast } = useToast();
  const [formation, setFormation] = useState<string>("4-4-2");
  const [slots, setSlots] = useState<(string | null)[]>(Array(11).fill(null));
  const [saving, setSaving] = useState(false);
  const [initialized, setInitialized] = useState(false);

  if (authLoading || isLoading) return <div className="min-h-screen bg-background flex items-center justify-center"><div className="w-8 h-8 border-2 border-primary border-t-transparent rounded-full animate-spin" /></div>;
  if (!user) return <Navigate to="/auth" replace />;
  if (!club) return <Navigate to="/criar-clube" replace />;

  // Load existing lineup once
  if (!initialized && !lineupLoading && lineup) {
    setFormation(lineup.formation);
    const loadedSlots = Array(11).fill(null);
    lineup.players?.forEach((lp: any) => {
      if (lp.position_slot >= 1 && lp.position_slot <= 11) {
        loadedSlots[lp.position_slot - 1] = lp.player_id;
      }
    });
    setSlots(loadedSlots);
    setInitialized(true);
  } else if (!initialized && !lineupLoading && !lineup) {
    setInitialized(true);
  }

  const positionSlots = FORMATIONS[formation] ?? FORMATIONS["4-4-2"];
  const assignedIds = new Set(slots.filter(Boolean));

  const availablePlayers = (slotIndex: number) => {
    return players?.filter(p => !p.is_injured && !assignedIds.has(p.id) || slots[slotIndex] === p.id) ?? [];
  };

  const setSlot = (index: number, playerId: string | null) => {
    const newSlots = [...slots];
    newSlots[index] = playerId;
    setSlots(newSlots);
  };

  const autoFill = () => {
    const newSlots: (string | null)[] = Array(11).fill(null);
    const used = new Set<string>();

    positionSlots.forEach((pos, i) => {
      const best = players
        ?.filter(p => !p.is_injured && !used.has(p.id) && p.position === pos)
        .sort((a, b) => getOverallRating(b) - getOverallRating(a))[0];
      if (best) {
        newSlots[i] = best.id;
        used.add(best.id);
      }
    });

    // Fill remaining with best available
    positionSlots.forEach((_, i) => {
      if (!newSlots[i]) {
        const best = players
          ?.filter(p => !p.is_injured && !used.has(p.id))
          .sort((a, b) => getOverallRating(b) - getOverallRating(a))[0];
        if (best) {
          newSlots[i] = best.id;
          used.add(best.id);
        }
      }
    });

    setSlots(newSlots);
  };

  const saveLineup = async () => {
    setSaving(true);
    try {
      // Upsert lineup
      const { data: lineupData, error: lineupError } = await supabase
        .from("lineups")
        .upsert({ club_id: club.id, formation, updated_at: new Date().toISOString() }, { onConflict: "club_id" })
        .select("id")
        .single();

      if (lineupError) throw lineupError;

      // Delete old players
      await supabase.from("lineup_players").delete().eq("lineup_id", lineupData.id);

      // Insert new
      const inserts = slots
        .map((playerId, i) => playerId ? {
          lineup_id: lineupData.id,
          player_id: playerId,
          position_slot: i + 1,
          position_override: positionSlots[i],
        } : null)
        .filter(Boolean);

      if (inserts.length > 0) {
        const { error } = await supabase.from("lineup_players").insert(inserts as any);
        if (error) throw error;
      }

      toast({ title: "Escalação salva!" });
      queryClient.invalidateQueries({ queryKey: ["lineup"] });
    } catch (err: any) {
      toast({ title: "Erro", description: err.message, variant: "destructive" });
    }
    setSaving(false);
  };

  const getPlayer = (id: string | null) => players?.find(p => p.id === id);

  return (
    <GameLayout>
      <div className="space-y-6">
        <div className="flex items-center justify-between flex-wrap gap-4">
          <h1 className="font-heading text-3xl font-bold text-foreground">Escalação</h1>
          <div className="flex gap-2">
            <Button variant="outline" size="sm" onClick={autoFill}><RotateCcw size={14} /> Auto</Button>
            <Button size="sm" onClick={saveLineup} disabled={saving}><Save size={14} /> {saving ? "Salvando..." : "Salvar"}</Button>
          </div>
        </div>

        {/* Formation selector */}
        <div className="flex flex-wrap gap-2">
          {Object.keys(FORMATIONS).map(f => (
            <Button
              key={f}
              variant={formation === f ? "default" : "outline"}
              size="sm"
              onClick={() => { setFormation(f); setSlots(Array(11).fill(null)); }}
              className="font-heading"
            >
              {f}
            </Button>
          ))}
        </div>

        {/* Slots grid */}
        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-3">
          {positionSlots.map((pos, i) => {
            const player = getPlayer(slots[i]);
            return (
              <div key={i} className={`bg-glass rounded-xl p-4 border ${player ? "border-primary/20" : "border-border/30"}`}>
                <div className="flex items-center justify-between mb-2">
                  <span className="text-xs font-heading text-muted-foreground">#{i + 1}</span>
                  <span className="text-xs px-2 py-0.5 rounded bg-secondary text-foreground font-heading">
                    {POSITION_ABBREVIATIONS[pos] ?? pos.toUpperCase()}
                  </span>
                </div>
                {player ? (
                  <div className="flex items-center justify-between">
                    <div>
                      <p className="text-sm font-medium text-foreground">{player.name}</p>
                      <p className="text-xs text-muted-foreground">
                        {POSITION_ABBREVIATIONS[player.position]} • OVR {getOverallRating(player)}
                      </p>
                    </div>
                    <button
                      onClick={() => setSlot(i, null)}
                      className="text-xs text-destructive hover:underline"
                    >
                      ✕
                    </button>
                  </div>
                ) : (
                  <select
                    className="w-full bg-secondary text-foreground text-sm rounded p-1.5 border border-border/30"
                    value=""
                    onChange={e => setSlot(i, e.target.value || null)}
                  >
                    <option value="">Selecionar...</option>
                    {availablePlayers(i)
                      .sort((a, b) => getOverallRating(b) - getOverallRating(a))
                      .map(p => (
                        <option key={p.id} value={p.id}>
                          {p.name} ({POSITION_ABBREVIATIONS[p.position]}) OVR {getOverallRating(p)}
                        </option>
                      ))}
                  </select>
                )}
              </div>
            );
          })}
        </div>

        {/* Bench info */}
        <div className="bg-glass rounded-xl p-4">
          <h3 className="font-heading text-lg font-bold text-foreground mb-2">Reservas</h3>
          <div className="flex flex-wrap gap-2">
            {players?.filter(p => !assignedIds.has(p.id) && !p.is_injured).map(p => (
              <span key={p.id} className="text-xs bg-secondary px-2 py-1 rounded text-muted-foreground">
                {p.name} ({POSITION_ABBREVIATIONS[p.position]}) {getOverallRating(p)}
              </span>
            ))}
          </div>
        </div>
      </div>
    </GameLayout>
  );
};

export default Escalacao;
