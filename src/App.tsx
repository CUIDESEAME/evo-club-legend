import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { BrowserRouter, Route, Routes, Navigate } from "react-router-dom";
import { Toaster as Sonner } from "@/components/ui/sonner";
import { Toaster } from "@/components/ui/toaster";
import { TooltipProvider } from "@/components/ui/tooltip";
import { AuthProvider } from "@/lib/auth";
import Index from "./pages/Index";
import Auth from "./pages/Auth";
import CreateClub from "./pages/CreateClub";
import Dashboard from "./pages/Dashboard";
import Elenco from "./pages/Elenco";
import Treino from "./pages/Treino";
import Patrimonio from "./pages/Patrimonio";
import Financas from "./pages/Financas";
import Juniores from "./pages/Juniores";
import Liga from "./pages/Liga";
import Partidas from "./pages/Partidas";
import Mercado from "./pages/Mercado";
import Escalacao from "./pages/Escalacao";
import AdminEditor from "./pages/AdminEditor";
import { VIP } from "./pages/ComingSoon";
import NotFound from "./pages/NotFound";

const queryClient = new QueryClient();

const App = () => (
  <QueryClientProvider client={queryClient}>
    <AuthProvider>
      <TooltipProvider>
        <Toaster />
        <Sonner />
        <BrowserRouter>
          <Routes>
            <Route path="/" element={<Index />} />
            <Route path="/auth" element={<Auth />} />
            <Route path="/criar-clube" element={<CreateClub />} />
            <Route path="/dashboard" element={<Dashboard />} />
            <Route path="/elenco" element={<Elenco />} />
            <Route path="/treino" element={<Treino />} />
            <Route path="/patrimonio" element={<Patrimonio />} />
            <Route path="/financas" element={<Financas />} />
            <Route path="/juniores" element={<Juniores />} />
            <Route path="/mercado" element={<Mercado />} />
            <Route path="/escalacao" element={<Escalacao />} />
            <Route path="/admin-editor" element={<AdminEditor />} />
            <Route path="/liga" element={<Liga />} />
            <Route path="/partidas" element={<Partidas />} />
            <Route path="/vip" element={<VIP />} />
            <Route path="*" element={<NotFound />} />
          </Routes>
        </BrowserRouter>
      </TooltipProvider>
    </AuthProvider>
  </QueryClientProvider>
);

export default App;
