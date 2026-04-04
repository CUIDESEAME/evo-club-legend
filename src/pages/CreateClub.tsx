import { useState } from "react";
import { useNavigate } from "react-router-dom";
import { useAuth } from "@/lib/auth";
import { supabase } from "@/integrations/supabase/client";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { toast } from "sonner";

const BRAZILIAN_NAMES = [
  "Silva", "Santos", "Oliveira", "Souza", "Pereira", "Costa", "Rodrigues",
  "Almeida", "Nascimento", "Lima", "Araújo", "Fernandes", "Carvalho", "Gomes",
  "Martins", "Rocha", "Ribeiro", "Mendes", "Barros", "Freitas"
];

const FIRST_NAMES = [
  "Lucas", "Gabriel", "Bruno", "Felipe", "Pedro", "Matheus",
  "Diego", "Thiago", "André", "Carlos", "Marcos", "Paulo", "Vinicius",
  "Leonardo", "Gustavo", "Eduardo", "Ricardo", "Fernando", "João",
  "Daniel", "Roberto", "Alexandre", "Henrique", "Ronaldo"
];

const BANNED_NAMES = ["Rafael Costa"];

const POSITIONS: Array<{ value: string; label: string }> = [
  { value: "goleiro", label: "Goleiro" },
  { value: "zagueiro", label: "Zagueiro" },
  { value: "lateral", label: "Lateral" },
  { value: "volante", label: "Volante" },
  { value: "meia", label: "Meia" },
  { value: "atacante", label: "Atacante" },
];

function randomInt(min: number, max: number) {
  return Math.floor(Math.random() * (max - min + 1)) + min;
}

function generatePlayer(position: string, index: number) {
  let firstName: string, lastName: string, fullName: string;
  do {
    firstName = FIRST_NAMES[randomInt(0, FIRST_NAMES.length - 1)];
    lastName = BRAZILIAN_NAMES[randomInt(0, BRAZILIAN_NAMES.length - 1)];
    fullName = `${firstName} ${lastName}`;
  } while (BANNED_NAMES.includes(fullName));
  const age = randomInt(18, 32);
  const baseSkill = randomInt(3, 6);
  const physBase = randomInt(3, 6);

  return {
    name: `${firstName} ${lastName}`,
    age,
    position: position as any,
    is_captain: index === 0,
    salary: 3000 + baseSkill * 1000,
    market_value: 20000 + baseSkill * 15000,
    reflexos: position === "goleiro" ? baseSkill + 2 : randomInt(1, 3),
    posicionamento: baseSkill + randomInt(0, 2),
    jogo_aereo: baseSkill + randomInt(-1, 1),
    desarme: ["zagueiro", "lateral", "volante"].includes(position) ? baseSkill + 1 : randomInt(1, 4),
    armacao: ["meia", "meia_atacante"].includes(position) ? baseSkill + 1 : randomInt(1, 4),
    passe: baseSkill + randomInt(-1, 1),
    tecnica: ["meia", "atacante", "ponteiro"].includes(position) ? baseSkill + 1 : randomInt(1, 4),
    chute: ["atacante", "meia_atacante", "ponteiro"].includes(position) ? baseSkill + 2 : randomInt(1, 4),
    velocidade: Math.min(physBase + randomInt(-1, 1), 9),
    forca: Math.min(physBase + randomInt(-1, 1), 9),
    resistencia: Math.min(physBase + randomInt(-1, 1), 9),
    forma: Math.min(physBase + randomInt(0, 2), 9),
    experiencia: randomInt(1, Math.min(age - 16, 10)),
    lideranca: randomInt(1, 4),
    inteligencia: randomInt(2, 4),
    agressividade: randomInt(2, 5),
    honestidade: randomInt(2, 5),
    entrosamento: 0,
    moral: 50,
    talento: randomInt(2, 7),
    potencial_velocidade: randomInt(4, 8),
    potencial_forca: randomInt(4, 8),
    potencial_resistencia: randomInt(4, 8),
    potencial_forma: randomInt(4, 8),
  };
}

function generateSquad() {
  const squad: ReturnType<typeof generatePlayer>[] = [];
  // 2 GK, 4 DEF, 4 MID, 3 ATK + subs = ~20 players
  const positions = [
    ...Array(2).fill("goleiro"),
    ...Array(2).fill("zagueiro"),
    ...Array(2).fill("lateral"),
    ...Array(2).fill("volante"),
    ...Array(3).fill("meia"),
    ...Array(2).fill("meia_atacante"),
    ...Array(2).fill("ponteiro"),
    ...Array(3).fill("atacante"),
  ];
  positions.forEach((pos, i) => squad.push(generatePlayer(pos, i)));
  return squad;
}

const CreateClub = () => {
  const { user } = useAuth();
  const navigate = useNavigate();
  const [clubName, setClubName] = useState("");
  const [abbreviation, setAbbreviation] = useState("");
  const [creating, setCreating] = useState(false);

  const handleCreate = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!user) return;
    setCreating(true);

    try {
      // Check for existing club
      const { data: existingClub } = await supabase
        .from("clubs")
        .select("id")
        .eq("user_id", user.id)
        .maybeSingle();

      if (existingClub) {
        toast.error("Você já possui um clube!");
        setCreating(false);
        return;
      }

      // Create club
      const { data: club, error: clubError } = await supabase
        .from("clubs")
        .insert({ user_id: user.id, name: clubName, abbreviation: abbreviation.toUpperCase() })
        .select()
        .single();

      if (clubError) throw clubError;

      // Generate and insert players
      const squad = generateSquad();
      const playersWithClub = squad.map(p => ({ ...p, club_id: club.id }));
      const { error: playersError } = await supabase.from("players").insert(playersWithClub);
      if (playersError) throw playersError;

      // Create patrimony items
      const patrimonyTypes = ["estadio", "ct", "academia", "alojamento", "marketing", "clube_social", "lojas"];
      const patrimonyItems = patrimonyTypes.map(type => ({
        club_id: club.id,
        type,
        level: type === "estadio" ? 0 : 0,
        maintenance_cost: 0,
      }));
      const { error: patError } = await supabase.from("patrimony").insert(patrimonyItems);
      if (patError) throw patError;

      // Create training config
      const { error: trainError } = await supabase.from("training_config").insert({ club_id: club.id });
      if (trainError) throw trainError;

      // Create default stadium sectors
      const sectors = ["norte", "sul", "leste", "oeste", "ne", "nw", "se", "sw"];
      const stadiumSectors = sectors.map(s => ({
        club_id: club.id,
        sector_name: s,
        structure: "geral",
        seat_type: "geral",
        capacity: 100,
      }));
      const { error: stadError } = await supabase.from("stadium_sectors").insert(stadiumSectors);
      if (stadError) throw stadError;

      // Initialize first season
      const { error: seasonError } = await supabase.rpc("initialize_season_for_club", { p_club_id: club.id });
      if (seasonError) throw seasonError;

      toast.success("Clube criado com sucesso!");
      navigate("/dashboard");
    } catch (err: any) {
      toast.error(err.message || "Erro ao criar clube");
    } finally {
      setCreating(false);
    }
  };

  return (
    <div className="min-h-screen bg-background flex items-center justify-center px-4">
      <div className="w-full max-w-lg">
        <div className="text-center mb-8">
          <h1 className="font-heading text-3xl font-bold text-foreground">CRIE SEU CLUBE</h1>
          <p className="text-muted-foreground mt-2">Escolha o nome e comece sua jornada</p>
        </div>

        <form onSubmit={handleCreate} className="bg-glass rounded-xl p-8 space-y-6">
          <div className="space-y-2">
            <Label className="text-foreground">Nome do Clube</Label>
            <Input
              value={clubName}
              onChange={(e) => setClubName(e.target.value)}
              placeholder="Ex: Estrela FC"
              required
              maxLength={30}
              className="bg-secondary border-border text-foreground"
            />
          </div>

          <div className="space-y-2">
            <Label className="text-foreground">Abreviação (até 4 letras)</Label>
            <Input
              value={abbreviation}
              onChange={(e) => setAbbreviation(e.target.value.toUpperCase().slice(0, 4))}
              placeholder="Ex: EFC"
              required
              maxLength={4}
              className="bg-secondary border-border text-foreground font-heading tracking-widest"
            />
          </div>

          <div className="bg-secondary/50 rounded-lg p-4 text-sm text-muted-foreground space-y-1">
            <p>⚽ Seu clube começará com:</p>
            <p>• 18 jogadores gerados aleatoriamente</p>
            <p>• R$ 500.000 em caixa</p>
            <p>• Estádio geral (800 lugares)</p>
            <p>• Série F do campeonato</p>
          </div>

          <Button
            type="submit"
            disabled={creating}
            className="w-full bg-accent text-accent-foreground font-heading text-lg tracking-wide glow-gold"
          >
            {creating ? "CRIANDO..." : "FUNDAR CLUBE"}
          </Button>
        </form>
      </div>
    </div>
  );
};

export default CreateClub;
