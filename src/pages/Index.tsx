import { motion } from "framer-motion";
import heroImg from "@/assets/hero-stadium.jpg";
import { Trophy, Users, Dumbbell, Building2, Coins, Swords } from "lucide-react";
import { Button } from "@/components/ui/button";

const fadeUp = {
  hidden: { opacity: 0, y: 40 },
  visible: (i: number) => ({
    opacity: 1,
    y: 0,
    transition: { delay: i * 0.12, duration: 0.7, ease: [0.22, 1, 0.36, 1] },
  }),
};

const features = [
  {
    icon: Users,
    title: "Administre seu Clube",
    desc: "Gerencie elenco, finanças, patrimônio e torcida. Cada decisão impacta o futuro do seu time.",
  },
  {
    icon: Swords,
    title: "Partidas ao Vivo",
    desc: "Acompanhe jogos em tempo real com narração minuto a minuto. 90 minutos de pura emoção.",
  },
  {
    icon: Dumbbell,
    title: "Treino Completo",
    desc: "Treino físico e técnico para cada posição. Desenvolva jovens talentos na categoria de base.",
  },
  {
    icon: Building2,
    title: "Construa seu Estádio",
    desc: "De 800 lugares na geral até arenas com 84.000 lugares. Planeje cada setor com cuidado.",
  },
  {
    icon: Coins,
    title: "Gestão Financeira",
    desc: "Controle receitas, despesas, empréstimos e investimentos. Cuidado com a falência!",
  },
  {
    icon: Trophy,
    title: "Conquiste Títulos",
    desc: "Da Série F à Série A, regionais e Copa VIP. Premiações de até R$ 4.800.000 aguardam você.",
  },
];

const positions = [
  { name: "Goleiro", attrs: "Reflexos, Posicionamento, Jogo Aéreo" },
  { name: "Zagueiro", attrs: "Desarme, Posicionamento, Jogo Aéreo" },
  { name: "Lateral", attrs: "Desarme, Passe, Chute" },
  { name: "Volante", attrs: "Desarme, Armação, Passe" },
  { name: "Meia", attrs: "Armação, Passe, Técnica" },
  { name: "Atacante", attrs: "Chute, Técnica, Posicionamento" },
];

const Index = () => {
  return (
    <div className="min-h-screen bg-background overflow-x-hidden">
      {/* Hero */}
      <section className="relative min-h-screen flex items-center justify-center">
        <div className="absolute inset-0">
          <img
            src={heroImg}
            alt="Estádio Star Evolution"
            className="w-full h-full object-cover"
            width={1920}
            height={1080}
          />
          <div className="absolute inset-0 bg-gradient-to-t from-background via-background/70 to-background/30" />
        </div>

        <div className="relative z-10 text-center px-6 max-w-4xl mx-auto">
          <motion.div
            initial={{ opacity: 0, scale: 0.9 }}
            animate={{ opacity: 1, scale: 1 }}
            transition={{ duration: 1, ease: [0.22, 1, 0.36, 1] }}
          >
            <h1 className="font-heading text-6xl sm:text-7xl md:text-8xl lg:text-9xl font-bold tracking-tight leading-none mb-2">
              <span className="text-gradient-gold">STAR</span>{" "}
              <span className="text-foreground">EVOLUTION</span>
            </h1>
          </motion.div>

          <motion.p
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ delay: 0.4, duration: 0.8 }}
            className="text-lg sm:text-xl text-muted-foreground max-w-2xl mx-auto mt-6 mb-10 font-body leading-relaxed"
          >
            O gerenciador de futebol online onde suas decisões definem o destino do seu clube.
            Treine, escale, construa e conquiste.
          </motion.p>

          <motion.div
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ delay: 0.7, duration: 0.8 }}
            className="flex flex-col sm:flex-row gap-4 justify-center"
          >
            <Button size="lg" className="bg-primary text-primary-foreground font-heading text-lg tracking-wide px-10 py-6 glow-green hover:brightness-110 transition-all">
              COMECE AGORA
            </Button>
            <Button size="lg" variant="outline" className="border-border text-foreground font-heading text-lg tracking-wide px-10 py-6 hover:bg-secondary transition-all">
              SAIBA MAIS
            </Button>
          </motion.div>
        </div>

        {/* Scroll indicator */}
        <motion.div
          className="absolute bottom-8 left-1/2 -translate-x-1/2"
          animate={{ y: [0, 10, 0] }}
          transition={{ repeat: Infinity, duration: 2 }}
        >
          <div className="w-6 h-10 rounded-full border-2 border-muted-foreground/40 flex justify-center pt-2">
            <div className="w-1.5 h-1.5 rounded-full bg-accent animate-pulse-glow" />
          </div>
        </motion.div>
      </section>

      {/* Features */}
      <section className="py-24 px-6">
        <div className="max-w-6xl mx-auto">
          <motion.div
            initial="hidden"
            whileInView="visible"
            viewport={{ once: true, margin: "-100px" }}
            className="text-center mb-16"
          >
            <motion.h2
              variants={fadeUp}
              custom={0}
              className="font-heading text-4xl sm:text-5xl font-bold text-gradient-green tracking-tight"
            >
              DOMINE TODOS OS ASPECTOS
            </motion.h2>
            <motion.p
              variants={fadeUp}
              custom={1}
              className="text-muted-foreground mt-4 max-w-xl mx-auto"
            >
              Não basta conhecer futebol — você precisa saber administrar.
            </motion.p>
          </motion.div>

          <motion.div
            initial="hidden"
            whileInView="visible"
            viewport={{ once: true, margin: "-50px" }}
            className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6"
          >
            {features.map((f, i) => (
              <motion.div
                key={f.title}
                variants={fadeUp}
                custom={i + 2}
                className="bg-glass rounded-xl p-8 group hover:glow-green transition-all duration-500"
              >
                <f.icon className="w-10 h-10 text-accent mb-4 group-hover:scale-110 transition-transform" />
                <h3 className="font-heading text-xl font-semibold text-foreground mb-2">
                  {f.title}
                </h3>
                <p className="text-muted-foreground text-sm leading-relaxed">
                  {f.desc}
                </p>
              </motion.div>
            ))}
          </motion.div>
        </div>
      </section>

      {/* Positions */}
      <section className="py-24 px-6 bg-secondary/30">
        <div className="max-w-6xl mx-auto">
          <motion.div
            initial="hidden"
            whileInView="visible"
            viewport={{ once: true, margin: "-100px" }}
            className="text-center mb-16"
          >
            <motion.h2
              variants={fadeUp}
              custom={0}
              className="font-heading text-4xl sm:text-5xl font-bold text-foreground tracking-tight"
            >
              POSIÇÕES E <span className="text-gradient-gold">ATRIBUTOS</span>
            </motion.h2>
            <motion.p variants={fadeUp} custom={1} className="text-muted-foreground mt-4 max-w-xl mx-auto">
              Cada posição tem habilidades únicas. Escale com sabedoria.
            </motion.p>
          </motion.div>

          <motion.div
            initial="hidden"
            whileInView="visible"
            viewport={{ once: true, margin: "-50px" }}
            className="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-6 gap-4"
          >
            {positions.map((p, i) => (
              <motion.div
                key={p.name}
                variants={fadeUp}
                custom={i + 2}
                className="bg-glass rounded-xl p-6 text-center hover:glow-gold transition-all duration-500"
              >
                <div className="w-12 h-12 rounded-full bg-accent/10 border border-accent/30 flex items-center justify-center mx-auto mb-3">
                  <span className="font-heading text-accent font-bold text-sm">
                    {p.name.slice(0, 3).toUpperCase()}
                  </span>
                </div>
                <h4 className="font-heading text-foreground font-semibold text-sm mb-1">
                  {p.name}
                </h4>
                <p className="text-muted-foreground text-xs leading-relaxed">
                  {p.attrs}
                </p>
              </motion.div>
            ))}
          </motion.div>
        </div>
      </section>

      {/* Attribute Levels */}
      <section className="py-24 px-6">
        <div className="max-w-4xl mx-auto">
          <motion.div
            initial="hidden"
            whileInView="visible"
            viewport={{ once: true, margin: "-100px" }}
            className="text-center mb-16"
          >
            <motion.h2
              variants={fadeUp}
              custom={0}
              className="font-heading text-4xl sm:text-5xl font-bold text-foreground tracking-tight"
            >
              DO TERRÍVEL AO <span className="text-gradient-gold">DIVINO</span>
            </motion.h2>
            <motion.p variants={fadeUp} custom={1} className="text-muted-foreground mt-4">
              16 níveis de evolução para transformar seus jogadores em lendas.
            </motion.p>
          </motion.div>

          <motion.div
            initial="hidden"
            whileInView="visible"
            viewport={{ once: true }}
            className="flex flex-wrap justify-center gap-3"
          >
            {[
              "Terrível", "Péssimo", "Ruim", "Fraco", "Razoável", "Bom",
              "Muito Bom", "Excelente", "Formidável", "Fenomenal", "Incrível",
              "Brilhante", "Magnífico", "Genial", "Lendário", "Divino",
            ].map((level, i) => (
              <motion.span
                key={level}
                variants={fadeUp}
                custom={i * 0.5}
                className="px-4 py-2 rounded-lg font-heading text-sm font-medium border transition-all"
                style={{
                  borderColor: `hsl(${43 + i * 6}, ${50 + i * 3}%, ${35 + i * 2}%)`,
                  color: `hsl(${43 + i * 6}, ${50 + i * 3}%, ${45 + i * 3}%)`,
                  background: `hsl(${43 + i * 6}, ${50 + i * 3}%, ${35 + i * 2}%, 0.1)`,
                }}
              >
                {i + 1}. {level}
              </motion.span>
            ))}
          </motion.div>
        </div>
      </section>

      {/* CTA */}
      <section className="py-32 px-6 relative">
        <div className="absolute inset-0 bg-gradient-to-b from-background via-pitch-dark/10 to-background" />
        <motion.div
          initial={{ opacity: 0, y: 40 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true }}
          transition={{ duration: 0.8 }}
          className="relative z-10 text-center max-w-3xl mx-auto"
        >
          <h2 className="font-heading text-5xl sm:text-6xl font-bold mb-6">
            <span className="text-foreground">PRONTO PARA A </span>
            <span className="text-gradient-gold">EVOLUÇÃO</span>
            <span className="text-foreground">?</span>
          </h2>
          <p className="text-muted-foreground text-lg mb-10 max-w-xl mx-auto">
            Crie seu clube, treine seus jogadores e dispute campeonatos contra milhares de usuários.
          </p>
          <Button
            size="lg"
            className="bg-accent text-accent-foreground font-heading text-xl tracking-wide px-14 py-7 glow-gold hover:brightness-110 transition-all"
          >
            CRIAR MEU CLUBE
          </Button>
        </motion.div>
      </section>

      {/* Footer */}
      <footer className="border-t border-border py-8 px-6">
        <div className="max-w-6xl mx-auto flex flex-col sm:flex-row items-center justify-between gap-4">
          <span className="font-heading text-lg font-bold">
            <span className="text-gradient-gold">STAR</span>{" "}
            <span className="text-foreground">EVOLUTION</span>
          </span>
          <p className="text-muted-foreground text-sm">
            © 2026 Star Evolution. Todos os direitos reservados.
          </p>
        </div>
      </footer>
    </div>
  );
};

export default Index;
