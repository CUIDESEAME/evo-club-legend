import { Navigate } from "react-router-dom";
import { useAuth } from "@/lib/auth";
import { useClub } from "@/hooks/useClub";
import GameLayout from "@/components/GameLayout";
import { formatMoney } from "@/lib/gameUtils";
import { supabase } from "@/integrations/supabase/client";
import { useQuery, useQueryClient } from "@tanstack/react-query";
import { useToast } from "@/hooks/use-toast";
import { Button } from "@/components/ui/button";
import { Landmark, TrendingDown, CheckCircle2 } from "lucide-react";
import { useState } from "react";

const Banco = () => {
  const { user, loading: authLoading } = useAuth();
  const { data: club, isLoading } = useClub();
  const queryClient = useQueryClient();
  const { toast } = useToast();
  const [amount, setAmount] = useState(100000);
  const [weeks, setWeeks] = useState(20);
  const [submitting, setSubmitting] = useState(false);

  const { data: loans } = useQuery({
    queryKey: ["loans", club?.id],
    queryFn: async () => {
      if (!club) return [];
      const { data } = await supabase.from("loans").select("*").eq("club_id", club.id).order("created_at", { ascending: false });
      return data ?? [];
    },
    enabled: !!club,
  });

  const { data: fund } = useQuery({
    queryKey: ["loan_fund"],
    queryFn: async () => {
      const { data } = await supabase.from("system_funds").select("*").eq("fund_type", "loan_system").maybeSingle();
      return data;
    },
  });

  if (authLoading || isLoading) return <div className="min-h-screen bg-background flex items-center justify-center"><div className="w-8 h-8 border-2 border-primary border-t-transparent rounded-full animate-spin" /></div>;
  if (!user) return <Navigate to="/auth" replace />;
  if (!club) return <Navigate to="/criar-clube" replace />;

  const interestRate = 8;
  const total = amount + (amount * interestRate / 100);
  const weekly = Math.floor(total / weeks);
  const activeLoans = loans?.filter(l => l.status === "active") ?? [];

  const requestLoan = async () => {
    setSubmitting(true);
    const { error } = await supabase.rpc("request_loan", { p_club_id: club.id, p_amount: amount, p_weeks: weeks });
    if (error) toast({ title: "Erro", description: error.message, variant: "destructive" });
    else {
      toast({ title: "Empréstimo aprovado!" });
      queryClient.invalidateQueries({ queryKey: ["loans"] });
      queryClient.invalidateQueries({ queryKey: ["club"] });
    }
    setSubmitting(false);
  };

  const repayLoan = async (loanId: string) => {
    const { error } = await supabase.rpc("repay_loan", { p_club_id: club.id, p_loan_id: loanId });
    if (error) toast({ title: "Erro", description: error.message, variant: "destructive" });
    else {
      toast({ title: "Quitado!" });
      queryClient.invalidateQueries({ queryKey: ["loans"] });
      queryClient.invalidateQueries({ queryKey: ["club"] });
    }
  };

  return (
    <GameLayout>
      <div className="space-y-6">
        <div className="flex items-center gap-3">
          <Landmark className="text-accent" size={32} />
          <div>
            <h1 className="font-heading text-3xl font-bold text-foreground">Banco</h1>
            <p className="text-sm text-muted-foreground">Fundo disponível: <span className="text-accent font-heading">{formatMoney(fund?.balance ?? 0)}</span></p>
          </div>
        </div>

        <div className="bg-glass rounded-xl p-6">
          <h2 className="font-heading text-lg font-bold text-foreground mb-4">Solicitar Empréstimo</h2>
          <div className="grid grid-cols-1 md:grid-cols-2 gap-4 mb-4">
            <div>
              <label className="text-xs text-muted-foreground">Valor (R$50k - R$5M)</label>
              <input type="number" min={50000} max={5000000} step={10000}
                className="w-full bg-secondary text-foreground rounded p-2 border border-border/30"
                value={amount} onChange={e => setAmount(parseInt(e.target.value) || 0)} />
            </div>
            <div>
              <label className="text-xs text-muted-foreground">Prazo (5-52 semanas)</label>
              <input type="number" min={5} max={52}
                className="w-full bg-secondary text-foreground rounded p-2 border border-border/30"
                value={weeks} onChange={e => setWeeks(parseInt(e.target.value) || 5)} />
            </div>
          </div>
          <div className="bg-secondary/50 rounded-lg p-3 mb-4 text-sm space-y-1">
            <div className="flex justify-between"><span className="text-muted-foreground">Juros:</span><span className="text-foreground">{interestRate}%</span></div>
            <div className="flex justify-between"><span className="text-muted-foreground">Total a pagar:</span><span className="text-foreground">{formatMoney(total)}</span></div>
            <div className="flex justify-between"><span className="text-muted-foreground">Parcela semanal:</span><span className="text-accent font-heading">{formatMoney(weekly)}</span></div>
          </div>
          <Button onClick={requestLoan} disabled={submitting || activeLoans.length >= 2} className="w-full font-heading">
            {submitting ? "Processando..." : activeLoans.length >= 2 ? "Limite de 2 empréstimos ativos" : "Solicitar"}
          </Button>
        </div>

        <div className="space-y-3">
          <h2 className="font-heading text-lg font-bold text-foreground">Histórico</h2>
          {loans?.length === 0 && <p className="text-sm text-muted-foreground">Nenhum empréstimo.</p>}
          {loans?.map(loan => (
            <div key={loan.id} className="bg-glass rounded-xl p-4 flex items-center justify-between">
              <div className="flex-1">
                <div className="flex items-center gap-2 mb-1">
                  {loan.status === "paid" ? <CheckCircle2 size={16} className="text-primary" /> : <TrendingDown size={16} className="text-accent" />}
                  <span className="font-heading text-sm text-foreground">{formatMoney(loan.principal)}</span>
                  <span className="text-xs text-muted-foreground">• {loan.interest_rate}% • {loan.total_weeks}sem</span>
                </div>
                <p className="text-xs text-muted-foreground">
                  Pago: {formatMoney(loan.paid_amount)} • Restantes: {loan.remaining_weeks} sem • Status: {loan.status}
                </p>
              </div>
              {loan.status === "active" && (
                <Button size="sm" variant="outline" onClick={() => repayLoan(loan.id)}>Quitar</Button>
              )}
            </div>
          ))}
        </div>
      </div>
    </GameLayout>
  );
};

export default Banco;