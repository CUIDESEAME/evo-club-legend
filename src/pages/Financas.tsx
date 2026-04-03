import { Navigate } from "react-router-dom";
import { useAuth } from "@/lib/auth";
import { useClub, useFinancialTransactions, usePlayers, usePatrimony } from "@/hooks/useClub";
import GameLayout from "@/components/GameLayout";
import { formatMoney } from "@/lib/gameUtils";
import { supabase } from "@/integrations/supabase/client";
import { useQueryClient } from "@tanstack/react-query";
import { useToast } from "@/hooks/use-toast";
import { Button } from "@/components/ui/button";
import { useState } from "react";
import { Coins, TrendingDown, TrendingUp, Banknote, AlertTriangle, Megaphone, Users } from "lucide-react";

const LOAN_AMOUNTS = [100000, 250000, 500000];
const MARKETING_OPTIONS = [0, 5000, 10000, 20000, 50000, 100000];

const Financas = () => {
  const { user, loading: authLoading } = useAuth();
  const { data: club, isLoading } = useClub();
  const { data: transactions } = useFinancialTransactions(club?.id);
  const { data: players } = usePlayers(club?.id);
  const { data: patrimony } = usePatrimony(club?.id);
  const queryClient = useQueryClient();
  const { toast } = useToast();
  const [loaning, setLoaning] = useState(false);
  const [updatingMarketing, setUpdatingMarketing] = useState(false);

  if (authLoading || isLoading) return <div className="min-h-screen bg-background flex items-center justify-center"><div className="w-8 h-8 border-2 border-primary border-t-transparent rounded-full animate-spin" /></div>;
  if (!user) return <Navigate to="/auth" replace />;
  if (!club) return <Navigate to="/criar-clube" replace />;

  const isBankrupt = club.balance <= -10000000;
  const isInDebt = club.balance < 0;
  const interestRate = isInDebt ? 5 + Math.floor(Math.abs(club.balance) / 500000) : 0;
  const totalSalary = players?.reduce((s, p) => s + p.salary, 0) ?? 0;
  const totalMaintenance = patrimony?.reduce((s, p) => s + p.maintenance_cost, 0) ?? 0;
  const marketingBudget = (club as any).marketing_budget ?? 0;
  const memberRevenue = club.members * 100;

  const takeLoan = async (amount: number) => {
    setLoaning(true);
    const { error } = await supabase.rpc("take_loan", {
      p_club_id: club.id,
      p_amount: amount,
    });
    if (error) {
      toast({ title: "Erro", description: error.message, variant: "destructive" });
    } else {
      toast({ title: "Empréstimo recebido!", description: `${formatMoney(amount)} adicionados ao caixa.` });
      queryClient.invalidateQueries({ queryKey: ["club"] });
      queryClient.invalidateQueries({ queryKey: ["transactions"] });
    }
    setLoaning(false);
  };

  const setMarketingBudget = async (amount: number) => {
    setUpdatingMarketing(true);
    const { error } = await supabase
      .from("clubs")
      .update({ marketing_budget: amount } as any)
      .eq("id", club.id);
    if (error) {
      toast({ title: "Erro", description: error.message, variant: "destructive" });
    } else {
      toast({ title: "Marketing atualizado!", description: `Investimento semanal: ${formatMoney(amount)}` });
      queryClient.invalidateQueries({ queryKey: ["club"] });
    }
    setUpdatingMarketing(false);
  };

  const incomeTransactions = transactions?.filter(t => t.amount > 0) ?? [];
  const expenseTransactions = transactions?.filter(t => t.amount < 0) ?? [];
  const totalIncome = incomeTransactions.reduce((s, t) => s + t.amount, 0);
  const totalExpenses = expenseTransactions.reduce((s, t) => s + Math.abs(t.amount), 0);

  const weeklyExpenses = totalSalary + totalMaintenance + marketingBudget;
  const weeklyIncome = memberRevenue;
  const weeklyNet = weeklyIncome - weeklyExpenses;

  return (
    <GameLayout>
      <div className="space-y-6">
        <h1 className="font-heading text-3xl font-bold text-foreground">Finanças</h1>

        <div className={`rounded-xl p-6 ${isBankrupt ? "bg-destructive/10 border border-destructive/30" : "bg-glass"}`}>
          <div className="flex items-center gap-3 mb-2">
            <Coins size={24} className={club.balance >= 0 ? "text-primary" : "text-destructive"} />
            <p className="text-sm text-muted-foreground">Saldo em Caixa</p>
          </div>
          <p className={`font-heading text-4xl font-bold ${club.balance >= 0 ? "text-primary" : "text-destructive"}`}>
            {formatMoney(club.balance)}
          </p>
          {isInDebt && (
            <div className="mt-2 text-sm flex items-center gap-2">
              <AlertTriangle size={14} className="text-destructive" />
              <span className="text-destructive">Taxa de juros semanais: {Math.min(interestRate, 20)}%</span>
            </div>
          )}
          {isBankrupt && (
            <p className="text-destructive font-heading font-bold mt-2">⚠️ FALÊNCIA IMINENTE!</p>
          )}
        </div>

        {/* Weekly summary */}
        <div className="bg-glass rounded-xl p-6">
          <h2 className="font-heading text-xl font-bold text-foreground mb-4">Resumo Semanal</h2>
          <div className="grid grid-cols-1 sm:grid-cols-2 gap-3 text-sm">
            <div className="flex justify-between">
              <span className="text-muted-foreground">Sócios ({club.members}x R$100)</span>
              <span className="text-primary font-heading">+{formatMoney(memberRevenue)}</span>
            </div>
            <div className="flex justify-between">
              <span className="text-muted-foreground">Salários</span>
              <span className="text-destructive font-heading">-{formatMoney(totalSalary)}</span>
            </div>
            <div className="flex justify-between">
              <span className="text-muted-foreground">Manutenção</span>
              <span className="text-destructive font-heading">-{formatMoney(totalMaintenance)}</span>
            </div>
            <div className="flex justify-between">
              <span className="text-muted-foreground">Marketing</span>
              <span className="text-destructive font-heading">-{formatMoney(marketingBudget)}</span>
            </div>
            <div className="col-span-full border-t border-border/30 pt-2 flex justify-between font-heading text-base">
              <span className="text-foreground">Balanço semanal</span>
              <span className={weeklyNet >= 0 ? "text-primary" : "text-destructive"}>
                {weeklyNet >= 0 ? "+" : ""}{formatMoney(weeklyNet)}
              </span>
            </div>
          </div>
        </div>

        {/* Marketing */}
        <div className="bg-glass rounded-xl p-6">
          <div className="flex items-center gap-2 mb-4">
            <Megaphone size={20} className="text-accent" />
            <h2 className="font-heading text-xl font-bold text-foreground">Marketing</h2>
          </div>
          <p className="text-xs text-muted-foreground mb-2">
            Investir em marketing atrai mais sócios. A cada R$ 5.000/sem → ~1 sócio extra por semana.
            Vitórias e liga também influenciam. Cada sócio gera R$ 100/semana.
          </p>
          <div className="flex items-center gap-2 mb-3">
            <Users size={14} className="text-primary" />
            <span className="text-sm text-foreground font-heading">{club.members} sócios ativos</span>
          </div>
          <div className="flex flex-wrap gap-2">
            {MARKETING_OPTIONS.map(amount => (
              <Button
                key={amount}
                variant={marketingBudget === amount ? "default" : "outline"}
                size="sm"
                onClick={() => setMarketingBudget(amount)}
                disabled={updatingMarketing}
                className="font-heading"
              >
                {amount === 0 ? "Sem marketing" : `${formatMoney(amount)}/sem`}
              </Button>
            ))}
          </div>
        </div>

        {/* Loans */}
        <div className="bg-glass rounded-xl p-6">
          <div className="flex items-center gap-2 mb-4">
            <Banknote size={20} className="text-accent" />
            <h2 className="font-heading text-xl font-bold text-foreground">Empréstimos</h2>
          </div>
          <p className="text-xs text-muted-foreground mb-4">
            Empréstimos aumentam seu caixa, mas saldos negativos geram juros semanais crescentes.
          </p>
          <div className="flex flex-wrap gap-3">
            {LOAN_AMOUNTS.map(amount => (
              <Button
                key={amount}
                variant="outline"
                onClick={() => takeLoan(amount)}
                disabled={loaning || isBankrupt}
                className="font-heading"
              >
                <Banknote size={14} />
                {formatMoney(amount)}
              </Button>
            ))}
          </div>
        </div>

        {/* Transaction history */}
        <div className="bg-glass rounded-xl p-6">
          <h2 className="font-heading text-xl font-bold text-foreground mb-4">Extrato</h2>
          {transactions && transactions.length > 0 ? (
            <div className="space-y-2 max-h-96 overflow-y-auto">
              {transactions.map(t => (
                <div key={t.id} className="flex items-center justify-between py-2 border-b border-border/30">
                  <div>
                    <p className="text-sm text-foreground">{t.description}</p>
                    <p className="text-xs text-muted-foreground">
                      {new Date(t.created_at).toLocaleDateString("pt-BR")} • {t.type}
                    </p>
                  </div>
                  <div className="text-right">
                    <span className={`font-heading text-sm ${t.amount >= 0 ? "text-primary" : "text-destructive"}`}>
                      {t.amount >= 0 ? "+" : ""}{formatMoney(t.amount)}
                    </span>
                    <p className="text-xs text-muted-foreground">{formatMoney(t.balance_after)}</p>
                  </div>
                </div>
              ))}
            </div>
          ) : (
            <p className="text-sm text-muted-foreground">Nenhuma transação registrada.</p>
          )}
        </div>
      </div>
    </GameLayout>
  );
};

export default Financas;
