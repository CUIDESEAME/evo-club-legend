export const ATTRIBUTE_LEVELS: Record<number, string> = {
  1: "Terrível",
  2: "Péssimo",
  3: "Ruim",
  4: "Fraco",
  5: "Razoável",
  6: "Bom",
  7: "Muito Bom",
  8: "Excelente",
  9: "Formidável",
  10: "Fenomenal",
  11: "Incrível",
  12: "Brilhante",
  13: "Magnífico",
  14: "Genial",
  15: "Lendário",
  16: "Divino",
};

export const POSITION_LABELS: Record<string, string> = {
  goleiro: "Goleiro",
  libero: "Líbero",
  zagueiro: "Zagueiro",
  lateral: "Lateral",
  volante: "Volante",
  meia: "Meia",
  ala: "Ala",
  meia_atacante: "Meia Atacante",
  ponteiro: "Ponteiro",
  atacante: "Atacante",
};

export const POSITION_ABBREVIATIONS: Record<string, string> = {
  goleiro: "GOL",
  libero: "LIB",
  zagueiro: "ZAG",
  lateral: "LAT",
  volante: "VOL",
  meia: "MEI",
  ala: "ALA",
  meia_atacante: "MAT",
  ponteiro: "PON",
  atacante: "ATA",
};

export const PATRIMONY_LABELS: Record<string, string> = {
  estadio: "Estádio",
  ct: "Centro de Treinamento",
  academia: "Academia",
  alojamento: "Alojamento de Juniores",
  marketing: "Marketing",
  clube_social: "Clube Social",
  lojas: "Lojas",
  psicologia: "Psicologia",
  escola: "Escola",
  funcionarios: "Funcionários",
};

export const PATRIMONY_ICONS: Record<string, string> = {
  estadio: "🏟️",
  ct: "🏋️",
  academia: "💪",
  alojamento: "👶",
  marketing: "📢",
  clube_social: "🎉",
  lojas: "🛍️",
  psicologia: "🧠",
  escola: "📚",
  funcionarios: "👔",
};

export const PATRIMONY_EFFECTS: Record<string, (level: number) => string> = {
  estadio: (l) => `${(l * 10000).toLocaleString("pt-BR")} lugares • ingresso até R$100/cadeira`,
  ct: (l) => `+${l * 5}% eficácia de treino`,
  academia: (l) => `+${l * 4}% ganho físico semanal`,
  alojamento: (l) => `${8 + l * 2} vagas de juniores`,
  marketing: (l) => `+${l * 8}% patrocínio e sócios`,
  clube_social: (l) => `+R$${(l * 50).toLocaleString("pt-BR")}k/sem em receita social`,
  lojas: (l) => `+R$${(l * 30).toLocaleString("pt-BR")}k/sem em vendas`,
  psicologia: (l) => `${l * 2} vagas • -${l}% agressividade/sem`,
  escola: (l) => `${l * 2} vagas • +${l * 0.5}% inteligência geral`,
  funcionarios: (l) => `+${l * 3}% recuperação e treino`,
};

export function formatMoney(cents: number): string {
  return new Intl.NumberFormat("pt-BR", {
    style: "currency",
    currency: "BRL",
    minimumFractionDigits: 0,
  }).format(cents);
}

export function getAttributeColor(value: number): string {
  if (value <= 3) return "text-destructive";
  if (value <= 5) return "text-muted-foreground";
  if (value <= 7) return "text-foreground";
  if (value <= 9) return "text-primary";
  if (value <= 12) return "text-accent";
  return "text-gradient-gold";
}

export function getOverallRating(player: {
  reflexos: number; posicionamento: number; jogo_aereo: number; desarme: number;
  armacao: number; passe: number; tecnica: number; chute: number;
  velocidade: number; forca: number; resistencia: number; forma: number;
}): number {
  const tech = [player.reflexos, player.posicionamento, player.jogo_aereo, player.desarme, player.armacao, player.passe, player.tecnica, player.chute];
  const phys = [player.velocidade, player.forca, player.resistencia, player.forma];
  const techAvg = tech.reduce((a, b) => a + b, 0) / tech.length;
  const physAvg = phys.reduce((a, b) => a + b, 0) / phys.length;
  return Math.round((techAvg * 0.7 + physAvg * 0.3) * 10) / 10;
}
