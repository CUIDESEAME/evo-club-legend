import { Navigate } from "react-router-dom";
import { useAuth } from "@/lib/auth";
import { useClub } from "@/hooks/useClub";
import GameLayout from "@/components/GameLayout";
import { Construction } from "lucide-react";

function ComingSoon({ title, description }: { title: string; description: string }) {
  const { user, loading } = useAuth();
  const { data: club, isLoading } = useClub();

  if (loading || isLoading) return <div className="min-h-screen bg-background flex items-center justify-center"><div className="w-8 h-8 border-2 border-primary border-t-transparent rounded-full animate-spin" /></div>;
  if (!user) return <Navigate to="/auth" replace />;
  if (!club) return <Navigate to="/criar-clube" replace />;

  return (
    <GameLayout>
      <div className="flex flex-col items-center justify-center py-24 text-center">
        <Construction size={48} className="text-accent mb-4" />
        <h1 className="font-heading text-3xl font-bold text-foreground">{title}</h1>
        <p className="text-muted-foreground mt-2 max-w-md">{description}</p>
        <p className="text-xs text-muted-foreground mt-6">Em desenvolvimento...</p>
      </div>
    </GameLayout>
  );
}

export const VIP = () => <ComingSoon title="VIP" description="Recursos premium sem pay-to-win." />;
