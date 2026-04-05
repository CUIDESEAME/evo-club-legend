import { Navigate } from "react-router-dom";
import { useAuth } from "@/lib/auth";
import { useClub, usePlayers } from "@/hooks/useClub";
import { useClosedMarket, useOpenMarket } from "@/hooks/useLineup";
import GameLayout from "@/components/GameLayout";
import { POSITION_ABBREVIATIONS, formatMoney } from "@/lib/gameUtils";
import { supabase } from "@/integrations/supabase/client";
import { useQueryClient } from "@tanstack/react-query";
import { useToast } from "@/hooks/use-toast";
import { Button } from "@/components/ui/button";
import { useState } from "react";
import { ShoppingCart, Gavel, Clock, DollarSign } from "lucide-react";

const Mercado = () => {
  const { user, loading: authLoading } = useAuth();
  const { data: club, isLoading } = useClub();
  const { data: players } = usePlayers(club?.id);
  const { data: closedListings } = useClosedMarket(club?.league);
  const { data: openListings } = useOpenMarket();
  const queryClient = useQueryClient();
  const { toast } = useToast();
  const [tab, setTab] = useState<"closed" | "open" | "sell">("closed");
  const [buying, setBuying] = useState<string | null>(null);
  const [bidding, setBidding] = useState<string | null>(null);
  const [bidAmount, setBidAmount] = useState<Record<string, number>>({});
  const [listing, setListing] = useState<string | null>(null);
  const [minPrice, setMinPrice] = useState(50000);

  if (authLoading || isLoading) return <div className="min-h-screen bg-background flex items-center justify-center"><div className="w-8 h-8 border-2 border-primary border-t-transparent rounded-full animate-spin" /></div>;
  if (!user) return <Navigate to="/auth" replace />;
  if (!club) return <Navigate to="/criar-clube" replace />;

  const buyFromClosed = async (listingId: string) => {
    setBuying(listingId);
    const { error } = await supabase.rpc("buy_from_closed_market", {
      p_club_id: club.id,
      p_listing_id: listingId,
    });
    if (error) {
      toast({ title: "Erro", description: error.message, variant: "destructive" });
    } else {
      toast({ title: "Jogador contratado!" });
      queryClient.invalidateQueries({ queryKey: ["market_closed"] });
      queryClient.invalidateQueries({ queryKey: ["players"] });
      queryClient.invalidateQueries({ queryKey: ["club"] });
    }
    setBuying(null);
  };

  const placeBid = async (listingId: string) => {
    const bid = bidAmount[listingId] ?? 0;
    setBidding(listingId);
    const { error } = await supabase.rpc("place_bid", {
      p_club_id: club.id,
      p_listing_id: listingId,
      p_bid: bid,
    });
    if (error) {
      toast({ title: "Erro", description: error.message, variant: "destructive" });
    } else {
      toast({ title: "Lance registrado!" });
      queryClient.invalidateQueries({ queryKey: ["market_open"] });
    }
    setBidding(null);
  };

  const listForSale = async (playerId: string) => {
    setListing(playerId);
    const { error } = await supabase.rpc("list_player_for_sale", {
      p_club_id: club.id,
      p_player_id: playerId,
      p_min_price: minPrice,
    });
    if (error) {
      toast({ title: "Erro", description: error.message, variant: "destructive" });
    } else {
      toast({ title: "Jogador listado no leilão! (8h)" });
      queryClient.invalidateQueries({ queryKey: ["players"] });
      queryClient.invalidateQueries({ queryKey: ["market_open"] });
    }
    setListing(null);
  };

  const timeRemaining = (endsAt: string) => {
    const diff = new Date(endsAt).getTime() - Date.now();
    if (diff <= 0) return "Encerrado";
    const h = Math.floor(diff / 3600000);
    const m = Math.floor((diff % 3600000) / 60000);
    return `${h}h ${m}m`;
  };

  return (
    <GameLayout>
      <div className="space-y-6">
        <h1 className="font-heading text-3xl font-bold text-foreground">Mercado</h1>

        <div className="flex gap-2">
          {[
            { key: "closed", label: "Fechado", icon: ShoppingCart },
            { key: "open", label: "Aberto (Leilão)", icon: Gavel },
            { key: "sell", label: "Vender", icon: DollarSign },
          ].map(t => (
            <Button
              key={t.key}
              variant={tab === t.key ? "default" : "outline"}
              size="sm"
              onClick={() => setTab(t.key as any)}
              className="font-heading"
            >
              <t.icon size={14} /> {t.label}
            </Button>
          ))}
        </div>

        {tab === "closed" && (
          <div className="space-y-4">
            <p className="text-sm text-muted-foreground">
              Jogadores disponíveis para compra imediata na Série {club.league}. Qualidade adequada à sua liga.
            </p>
            {closedListings && closedListings.length > 0 ? (
              <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-3">
                {closedListings.map(item => (
                  <div key={item.id} className="bg-glass rounded-xl p-4 hover:glow-green transition-all">
                    <div className="flex items-center justify-between mb-2">
                      <h3 className="font-heading text-sm font-bold text-foreground">{item.name}</h3>
                      <span className="text-xs px-2 py-0.5 rounded bg-secondary text-foreground font-heading">
                        {POSITION_ABBREVIATIONS[item.position] ?? item.position}
                      </span>
                    </div>
                    <div className="text-xs text-muted-foreground space-y-1 mb-3">
                      <p>Idade: {item.age} • OVR: <span className="text-primary font-heading">{item.overall}</span></p>
                      <p>Preço: <span className="text-foreground font-heading">{formatMoney(item.price)}</span></p>
                      <p>Salário: {formatMoney(item.salary)}/sem</p>
                    </div>
                    <Button
                      size="sm"
                      className="w-full font-heading"
                      disabled={buying === item.id || club.balance < item.price}
                      onClick={() => buyFromClosed(item.id)}
                    >
                      {buying === item.id ? "Comprando..." : "Contratar"}
                    </Button>
                  </div>
                ))}
              </div>
            ) : (
              <p className="text-sm text-muted-foreground">Nenhum jogador disponível no momento.</p>
            )}
          </div>
        )}

        {tab === "open" && (
          <div className="space-y-4">
            <p className="text-sm text-muted-foreground">
              Leilões ativos. Taxa total: 20% (10% mercado + 5% premiações + 5% fundo de empréstimos).
            </p>
            {openListings && openListings.length > 0 ? (
              <div className="space-y-3">
                {openListings.map(item => {
                  const player = (item as any).players;
                  const seller = (item as any).clubs;
                  return (
                    <div key={item.id} className="bg-glass rounded-xl p-4">
                      <div className="flex items-center justify-between mb-2">
                        <div>
                          <h3 className="font-heading text-sm font-bold text-foreground">
                            {player?.name ?? "Jogador"}
                          </h3>
                          <p className="text-xs text-muted-foreground">
                            {player?.position ? POSITION_ABBREVIATIONS[player.position] : ""} • {player?.age} anos
                            • De: {seller?.name}
                          </p>
                        </div>
                        <div className="text-right">
                          <div className="flex items-center gap-1 text-xs text-accent">
                            <Clock size={12} /> {timeRemaining(item.ends_at)}
                          </div>
                        </div>
                      </div>
                      <div className="text-xs text-muted-foreground mb-2">
                        Mín: {formatMoney(item.min_price)} • Lance atual: <span className="text-primary font-heading">{formatMoney(item.current_bid)}</span>
                      </div>
                      {item.seller_club_id !== club.id && (
                        <div className="flex gap-2 items-center">
                          <input
                            type="number"
                            className="flex-1 bg-secondary text-foreground text-sm rounded p-1.5 border border-border/30"
                            placeholder="Seu lance"
                            value={bidAmount[item.id] ?? ""}
                            onChange={e => setBidAmount({ ...bidAmount, [item.id]: parseInt(e.target.value) || 0 })}
                          />
                          <Button
                            size="sm"
                            disabled={bidding === item.id}
                            onClick={() => placeBid(item.id)}
                          >
                            {bidding === item.id ? "..." : "Dar Lance"}
                          </Button>
                        </div>
                      )}
                    </div>
                  );
                })}
              </div>
            ) : (
              <p className="text-sm text-muted-foreground">Nenhum leilão ativo.</p>
            )}
          </div>
        )}

        {tab === "sell" && (
          <div className="space-y-4">
            <p className="text-sm text-muted-foreground">
              Coloque jogadores à venda no leilão aberto (8h). Taxa: 20% sobre o valor final.
            </p>
            <div className="flex items-center gap-3 mb-4">
              <label className="text-sm text-muted-foreground">Preço mínimo:</label>
              <input
                type="number"
                className="bg-secondary text-foreground text-sm rounded p-1.5 border border-border/30 w-40"
                value={minPrice}
                onChange={e => setMinPrice(parseInt(e.target.value) || 0)}
              />
              <span className="text-xs text-muted-foreground">{formatMoney(minPrice)}</span>
            </div>
            <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
              {players?.filter(p => !p.is_for_sale).map(p => (
                <div key={p.id} className="bg-glass rounded-xl p-4 flex items-center justify-between">
                  <div>
                    <p className="text-sm font-medium text-foreground">{p.name}</p>
                    <p className="text-xs text-muted-foreground">
                      {POSITION_ABBREVIATIONS[p.position]} • {p.age} anos • {formatMoney(p.market_value)}
                    </p>
                  </div>
                  <Button
                    size="sm"
                    variant="outline"
                    disabled={listing === p.id}
                    onClick={() => listForSale(p.id)}
                  >
                    {listing === p.id ? "..." : "Vender"}
                  </Button>
                </div>
              ))}
            </div>
          </div>
        )}
      </div>
    </GameLayout>
  );
};

export default Mercado;
