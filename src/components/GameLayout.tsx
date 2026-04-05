import { ReactNode } from "react";
import { NavLink, useNavigate } from "react-router-dom";
import { useAuth } from "@/lib/auth";
import { useClub } from "@/hooks/useClub";
import { formatMoney } from "@/lib/gameUtils";
import {
  LayoutDashboard, Users, Dumbbell, Building2, Baby, ShoppingCart,
  Trophy, Swords, Coins, Crown, LogOut, Menu, X, ClipboardList, Edit
} from "lucide-react";
import { useState } from "react";

const navItems = [
  { to: "/dashboard", icon: LayoutDashboard, label: "Dashboard" },
  { to: "/elenco", icon: Users, label: "Elenco" },
  { to: "/escalacao", icon: ClipboardList, label: "Escalação" },
  { to: "/treino", icon: Dumbbell, label: "Treino" },
  { to: "/patrimonio", icon: Building2, label: "Patrimônio" },
  { to: "/juniores", icon: Baby, label: "Juniores" },
  { to: "/mercado", icon: ShoppingCart, label: "Mercado" },
  { to: "/liga", icon: Trophy, label: "Liga" },
  { to: "/partidas", icon: Swords, label: "Partidas" },
  { to: "/financas", icon: Coins, label: "Finanças" },
  { to: "/admin-editor", icon: Edit, label: "Editor" },
  { to: "/vip", icon: Crown, label: "VIP" },
];

export default function GameLayout({ children }: { children: ReactNode }) {
  const { signOut } = useAuth();
  const { data: club } = useClub();
  const navigate = useNavigate();
  const [mobileOpen, setMobileOpen] = useState(false);

  const handleSignOut = async () => {
    await signOut();
    navigate("/");
  };

  return (
    <div className="min-h-screen bg-background flex">
      {/* Mobile header */}
      <div className="lg:hidden fixed top-0 left-0 right-0 z-50 bg-card border-b border-border px-4 py-3 flex items-center justify-between">
        <button onClick={() => setMobileOpen(!mobileOpen)} className="text-foreground">
          {mobileOpen ? <X size={24} /> : <Menu size={24} />}
        </button>
        <span className="font-heading text-lg">
          <span className="text-gradient-gold">STAR</span> <span className="text-foreground">EVOLUTION</span>
        </span>
        {club && <span className="text-sm text-accent font-heading">{formatMoney(club.balance)}</span>}
      </div>

      {/* Sidebar */}
      <aside className={`
        fixed lg:sticky top-0 left-0 z-40 h-screen w-64 bg-card border-r border-border
        flex flex-col transition-transform duration-300
        ${mobileOpen ? "translate-x-0" : "-translate-x-full lg:translate-x-0"}
      `}>
        {/* Logo */}
        <div className="p-6 border-b border-border">
          <h1 className="font-heading text-xl font-bold">
            <span className="text-gradient-gold">STAR</span>{" "}
            <span className="text-foreground">EVOLUTION</span>
          </h1>
          {club && (
            <div className="mt-3 space-y-1">
              <p className="font-heading text-sm text-foreground">{club.name}</p>
              <p className="text-xs text-muted-foreground">Série {club.league} • Divisão {club.division}</p>
              <p className={`text-sm font-heading ${club.balance >= 0 ? "text-primary" : "text-destructive"}`}>
                {formatMoney(club.balance)}
              </p>
            </div>
          )}
        </div>

        {/* Nav */}
        <nav className="flex-1 p-3 space-y-1 overflow-y-auto">
          {navItems.map(item => (
            <NavLink
              key={item.to}
              to={item.to}
              onClick={() => setMobileOpen(false)}
              className={({ isActive }) =>
                `flex items-center gap-3 px-3 py-2.5 rounded-lg text-sm font-medium transition-colors
                ${isActive
                  ? "bg-primary/10 text-primary border border-primary/20"
                  : "text-muted-foreground hover:text-foreground hover:bg-secondary"
                }`
              }
            >
              <item.icon size={18} />
              {item.label}
            </NavLink>
          ))}
        </nav>

        {/* Footer */}
        <div className="p-3 border-t border-border">
          <button
            onClick={handleSignOut}
            className="flex items-center gap-3 px-3 py-2.5 rounded-lg text-sm text-muted-foreground hover:text-destructive hover:bg-secondary w-full transition-colors"
          >
            <LogOut size={18} />
            Sair
          </button>
        </div>
      </aside>

      {/* Overlay */}
      {mobileOpen && (
        <div className="fixed inset-0 bg-background/80 z-30 lg:hidden" onClick={() => setMobileOpen(false)} />
      )}

      {/* Main */}
      <main className="flex-1 min-h-screen lg:pt-0 pt-14">
        <div className="p-6 lg:p-8 max-w-7xl mx-auto">
          {children}
        </div>
      </main>
    </div>
  );
}
