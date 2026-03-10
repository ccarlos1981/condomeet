import {
  Users,
  Package,
  CalendarDays,
  Megaphone,
  ShieldAlert,
  Building2,
} from 'lucide-react'

const features = [
  {
    icon: Users,
    title: 'Autorização de Visitantes',
    desc: 'Autorize a entrada de visitantes pelo celular em segundos. Gere convites com QR Code e controle o acesso com segurança.',
    span: 'col-span-1 md:col-span-2',
    accent: 'text-blue-400',
    bg: 'bg-blue-500/10',
    border: 'border-blue-500/20',
  },
  {
    icon: Package,
    title: 'Controle de Encomendas',
    desc: 'Receba notificação via WhatsApp assim que uma encomenda chegar. Nunca mais perca um pacote.',
    span: 'col-span-1',
    accent: 'text-lp-accent',
    bg: 'bg-lp-accent/10',
    border: 'border-lp-accent/20',
  },
  {
    icon: CalendarDays,
    title: 'Reserva de Áreas Comuns',
    desc: 'Reserve churrasqueira, salão de festas e muito mais sem burocracia.',
    span: 'col-span-1',
    accent: 'text-purple-400',
    bg: 'bg-purple-500/10',
    border: 'border-purple-500/20',
  },
  {
    icon: Megaphone,
    title: 'Avisos e Comunicados',
    desc: 'O síndico envia comunicados com push notification instantânea para todos os moradores.',
    span: 'col-span-1 md:col-span-2',
    accent: 'text-green-400',
    bg: 'bg-green-500/10',
    border: 'border-green-500/20',
  },
  {
    icon: ShieldAlert,
    title: 'SOS / Emergências',
    desc: 'Botão de emergência com acionamento direto para o síndico em situações críticas.',
    span: 'col-span-1',
    accent: 'text-red-400',
    bg: 'bg-red-500/10',
    border: 'border-red-500/20',
  },
  {
    icon: Building2,
    title: 'Portal do Síndico',
    desc: 'Visão completa dos dados do condomínio: moradores, visitantes, histórico de ocorrências e muito mais.',
    span: 'col-span-1 md:col-span-2',
    accent: 'text-yellow-400',
    bg: 'bg-yellow-500/10',
    border: 'border-yellow-500/20',
  },
]

export default function FeaturesSection() {
  return (
    <section id="funcionalidades" className="py-24">
      <div className="lp-container">
        {/* Header */}
        <div className="text-center mb-14">
          <div className="inline-flex items-center gap-2 px-3 py-1.5 rounded-full bg-lp-accent/15 border border-lp-accent/25 mb-4">
            <span className="text-xs font-semibold text-lp-accent uppercase tracking-wide">Funcionalidades</span>
          </div>
          <h2 className="font-heading text-4xl md:text-5xl font-extrabold text-lp-primary mb-4">
            Tudo que seu condomínio precisa
          </h2>
          <p className="text-lp-muted text-lg max-w-xl mx-auto">
            Em uma plataforma integrada, simples e acessível para moradores e administração.
          </p>
        </div>

        {/* Bento grid */}
        <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
          {features.map((f) => {
            const Icon = f.icon
            return (
              <div
                key={f.title}
                className={`${f.span} lp-glass rounded-2xl border ${f.border} p-7 group hover:scale-[1.02] transition-transform duration-300 cursor-pointer`}
              >
                <div className={`w-11 h-11 rounded-xl ${f.bg} border ${f.border} flex items-center justify-center mb-4`}>
                  <Icon size={20} className={f.accent} />
                </div>
                <h3 className={`font-heading text-lg font-bold text-lp-primary mb-2 group-hover:${f.accent} transition-colors duration-200`}>
                  {f.title}
                </h3>
                <p className="text-sm text-lp-muted leading-relaxed">{f.desc}</p>
              </div>
            )
          })}
        </div>
      </div>
    </section>
  )
}
