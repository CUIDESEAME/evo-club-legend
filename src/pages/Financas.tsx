import { Navigate } from "react-router-dom";
import { useAuth } from "@/lib/auth";
import { useClub, useFinancialTransactions } from "@/hooks/useClub";
import GameLayout from "@/components/GameLayout";
import { formatMoney } from "@/lib/gameUtils";

const Financas = () => {
  const { user, loading: authLoading } = useAuth();
  const { data: club, isLoading } = useClub();
  const { data: transactions } = useFinancialTransactions(club?.id);

  if (authLoading || isLoading) return <div className="min-h-screen bg-background flex items-center justify-center"><div className="w-8 h-8 border-2 border-primary border-t-transparent rounded-full animate-spin" /></div>;
  if (!user) return <Navigate to="/auth" replace />;
  if (!club) return <Navigate to="/criar-clube" replace />;

  const isBankrupt = club.balance <= -10000000;
  const isInDebt = club.balance < 0;
  const interestRate = isInDebt ? 5 + Math.floor(Math.abs(club.balance) / 500000) : 0;

  return (
    <GameLayout>
      <div className="space-y-6">
        <h1 className="font-heading text-3xl font-bold text-foreground">Finanças</h1>

        {/* Balance card */}
        <div className={`rounded-xl p-6 ${isBankrupt ? "bg-destructive/10 border border-destructive/30" : "bg-glass"}`}>
          <p className="text-sm text-muted-foreground">Saldo em Caixa</p>
          <p className={`font-heading text-4xl font-bold ${club.balance >= 0 ? "text-primary" : "text-destructive"}`}>
            {formatMoney(club.balance)}
          </p>
          {isInDebt && (
            <div className="mt-2 text-sm">
              <p className="text-destructive">Taxa de juros: {interestRate}%</p>
              {isBankrupt && <p className="text-destructive font-bold mt-1">⚠️ FALÊNCIA IMINENTE!</p>}
            </div>
          )}
        </div>

        {/* Info cards */}
        <div className="grid grid-cols-1 sm:grid-cols-3 gap-4">
          <div className="bg-glass rounded-xl p-4">
            <p className="text-xs text-muted-foreground">Limite de Empréstimo</p>
            <p className="font-heading text-lg text-foreground">R$ 500.000</p>
          </div>
          <div className="bg-glass rounded-xl p-4">
            <p className="text-xs text-muted-foreground">Falência em</p>
            <p className="font-heading text-lg text-foreground">R$ -10.000.000</p>
          </div>
          <div className="bg-glass rounded-xl p-4">
            <p className="text-xs text-muted-foreground">Torcedores</p>
            <p className="font-heading text-lg text-foreground">{club.fans}</p>
          </div>
        </div>

        {/* Transactions */}
        <div className="bg-glass rounded-xl p-6">
          <h2 className="font-heading text-xl font-bold text-foreground mb-4">Extrato</h2>
          {transactions && transactions.length > 0 ? (
            <div className="space-y-2">
              {transactions.map(t => (
                <div key={t.id} className="flex items-center justify-between py-2 border-b border-border/30">
                  <div>
                    <p className="text-sm text-foreground">{t.description}</p>
                    <p className="text-xs text-muted-foreground">{new Date(t.created_at).toLocaleDateString("pt-BR")}</p>
                  </div>
                  <span className={`font-heading text-sm ${t.amount >= 0 ? "text-primary" : "text-destructive"}`}>
                    {t.amount >= 0 ? "+" : ""}{formatMoney(t.amount)}
                  </span>
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
