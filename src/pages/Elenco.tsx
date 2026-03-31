import { Navigate } from "react-router-dom";
import { useAuth } from "@/lib/auth";
import { useClub, usePlayers } from "@/hooks/useClub";
import GameLayout from "@/components/GameLayout";
import { POSITION_LABELS, POSITION_ABBREVIATIONS, ATTRIBUTE_LEVELS, formatMoney, getOverallRating, getAttributeColor } from "@/lib/gameUtils";
import { useState } from "react";

const TECH_ATTRS = ["reflexos", "posicionamento", "jogo_aereo", "desarme", "armacao", "passe", "tecnica", "chute"] as const;
const PHYS_ATTRS = ["velocidade", "forca", "resistencia", "forma"] as const;

const ATTR_LABELS: Record<string, string> = {
  reflexos: "Reflexos", posicionamento: "Posic.", jogo_aereo: "J.Aéreo",
  desarme: "Desarme", armacao: "Armação", passe: "Passe",
  tecnica: "Técnica", chute: "Chute",
  velocidade: "Veloc.", forca: "Força", resistencia: "Resist.", forma: "Forma",
};

const Elenco = () => {
  const { user, loading: authLoading } = useAuth();
  const { data: club, isLoading } = useClub();
  const { data: players } = usePlayers(club?.id);
  const [selectedId, setSelectedId] = useState<string | null>(null);

  if (authLoading || isLoading) return <div className="min-h-screen bg-background flex items-center justify-center"><div className="w-8 h-8 border-2 border-primary border-t-transparent rounded-full animate-spin" /></div>;
  if (!user) return <Navigate to="/auth" replace />;
  if (!club) return <Navigate to="/criar-clube" replace />;

  const selected = players?.find(p => p.id === selectedId);

  return (
    <GameLayout>
      <div className="space-y-6">
        <h1 className="font-heading text-3xl font-bold text-foreground">Elenco</h1>
        <p className="text-muted-foreground">{players?.length ?? 0}/50 jogadores</p>

        <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
          {/* Player list */}
          <div className="lg:col-span-2 bg-glass rounded-xl p-4 overflow-x-auto">
            <table className="w-full text-sm">
              <thead>
                <tr className="text-muted-foreground text-xs border-b border-border">
                  <th className="text-left pb-2">Nome</th>
                  <th className="text-center pb-2">Pos</th>
                  <th className="text-center pb-2">Idade</th>
                  <th className="text-center pb-2">Geral</th>
                  {TECH_ATTRS.map(a => (
                    <th key={a} className="text-center pb-2 hidden xl:table-cell">{ATTR_LABELS[a]}</th>
                  ))}
                  <th className="text-right pb-2">Valor</th>
                </tr>
              </thead>
              <tbody>
                {players?.map(p => (
                  <tr
                    key={p.id}
                    onClick={() => setSelectedId(p.id)}
                    className={`border-b border-border/30 cursor-pointer transition-colors
                      ${selectedId === p.id ? "bg-primary/5" : "hover:bg-secondary/50"}`}
                  >
                    <td className="py-2 text-foreground font-medium">
                      {p.is_captain && <span className="text-accent mr-1">©</span>}
                      {p.name}
                      {p.is_injured && <span className="text-destructive ml-1">🤕</span>}
                    </td>
                    <td className="text-center">
                      <span className="text-xs px-1.5 py-0.5 rounded bg-secondary text-foreground font-heading">
                        {POSITION_ABBREVIATIONS[p.position]}
                      </span>
                    </td>
                    <td className="text-center text-muted-foreground">{p.age}</td>
                    <td className="text-center font-heading text-primary font-bold">{getOverallRating(p)}</td>
                    {TECH_ATTRS.map(a => (
                      <td key={a} className={`text-center hidden xl:table-cell font-mono ${getAttributeColor(p[a])}`}>
                        {p[a]}
                      </td>
                    ))}
                    <td className="text-right text-muted-foreground text-xs">{formatMoney(p.market_value)}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>

          {/* Player detail */}
          <div className="bg-glass rounded-xl p-6">
            {selected ? (
              <div className="space-y-4">
                <div>
                  <h3 className="font-heading text-xl font-bold text-foreground">
                    {selected.is_captain && <span className="text-accent mr-1">©</span>}
                    {selected.name}
                  </h3>
                  <p className="text-sm text-muted-foreground">
                    {POSITION_LABELS[selected.position]} • {selected.age} anos
                  </p>
                  <p className="font-heading text-2xl text-primary font-bold mt-1">
                    {getOverallRating(selected)}
                  </p>
                </div>

                <div>
                  <h4 className="text-xs text-muted-foreground mb-2 font-heading">TÉCNICOS</h4>
                  <div className="space-y-1">
                    {TECH_ATTRS.map(a => (
                      <div key={a} className="flex items-center justify-between">
                        <span className="text-xs text-muted-foreground">{ATTR_LABELS[a]}</span>
                        <div className="flex items-center gap-2">
                          <div className="w-20 h-1.5 bg-secondary rounded-full overflow-hidden">
                            <div
                              className="h-full bg-primary rounded-full"
                              style={{ width: `${(selected[a] / 16) * 100}%` }}
                            />
                          </div>
                          <span className={`text-xs font-mono w-4 ${getAttributeColor(selected[a])}`}>
                            {selected[a]}
                          </span>
                        </div>
                      </div>
                    ))}
                  </div>
                </div>

                <div>
                  <h4 className="text-xs text-muted-foreground mb-2 font-heading">FÍSICOS</h4>
                  <div className="space-y-1">
                    {PHYS_ATTRS.map(a => (
                      <div key={a} className="flex items-center justify-between">
                        <span className="text-xs text-muted-foreground">{ATTR_LABELS[a]}</span>
                        <div className="flex items-center gap-2">
                          <div className="w-20 h-1.5 bg-secondary rounded-full overflow-hidden">
                            <div
                              className="h-full bg-accent rounded-full"
                              style={{ width: `${(selected[a] / 9) * 100}%` }}
                            />
                          </div>
                          <span className={`text-xs font-mono w-4 ${getAttributeColor(selected[a])}`}>
                            {selected[a]}
                          </span>
                        </div>
                      </div>
                    ))}
                  </div>
                </div>

                <div className="pt-2 border-t border-border text-xs text-muted-foreground space-y-1">
                  <p>Entrosamento: {selected.entrosamento}%</p>
                  <p>Moral: {selected.moral}%</p>
                  <p>Experiência: {ATTRIBUTE_LEVELS[selected.experiencia]}</p>
                  <p>Salário: {formatMoney(selected.salary)}/sem</p>
                  <p>Valor de mercado: {formatMoney(selected.market_value)}</p>
                </div>
              </div>
            ) : (
              <div className="text-center text-muted-foreground py-12">
                <p className="text-sm">Selecione um jogador para ver detalhes</p>
              </div>
            )}
          </div>
        </div>
      </div>
    </GameLayout>
  );
};

export default Elenco;
