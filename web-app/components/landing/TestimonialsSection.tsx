import { Star } from 'lucide-react'

const testimonials = [
  {
    name: 'Ricardo Mendes',
    role: 'Síndico',
    building: 'Residencial Alameda Park',
    avatar: 'R',
    color: 'bg-blue-500/30 text-blue-300',
    text: 'O Condomeet transformou a gestão do nosso condomínio. Antes eu ficava o dia todo respondendo mensagens no WhatsApp. Hoje tudo é organizado e automático.',
    stars: 5,
  },
  {
    name: 'Fernanda Costa',
    role: 'Moradora',
    building: 'Condomínio Solar Nascente',
    avatar: 'F',
    color: 'bg-pink-500/30 text-pink-300',
    text: 'Receber a notificação de encomenda no celular e já saber que está na portaria é fantástico. A reserva de churrasqueira ficou muito mais prática também!',
    stars: 5,
  },
  {
    name: 'Ana Beatriz Lima',
    role: 'Síndica Profissional',
    building: 'Torres do Planalto',
    avatar: 'A',
    color: 'bg-purple-500/30 text-purple-300',
    text: 'Atendo 4 condomínios e o Condomeet é indispensável. Dashboard completo, suporte rápido e os moradores adoram a facilidade de autorizar visitantes pelo celular.',
    stars: 5,
  },
]

export default function TestimonialsSection() {
  return (
    <section id="depoimentos" className="py-24">
      <div className="lp-container">
        {/* Header */}
        <div className="text-center mb-14">
          <div className="inline-flex items-center gap-2 px-3 py-1.5 rounded-full bg-lp-accent/15 border border-lp-accent/25 mb-4">
            <span className="text-xs font-semibold text-lp-accent uppercase tracking-wide">Depoimentos</span>
          </div>
          <h2 className="font-heading text-4xl md:text-5xl font-extrabold text-lp-primary mb-4">
            Quem usa, aprova
          </h2>
          <p className="text-lp-muted text-lg">
            Síndicos e moradores que transformaram a gestão do condomínio.
          </p>
        </div>

        {/* Cards */}
        <div className="grid md:grid-cols-3 gap-6">
          {testimonials.map((t) => (
            <div
              key={t.name}
              className="lp-glass rounded-2xl border border-white/8 p-7 flex flex-col gap-5 hover:border-white/20 transition-colors duration-300 group"
            >
              {/* Stars */}
              <div className="flex gap-1">
                {Array.from({ length: t.stars }).map((_, i) => (
                  <Star key={i} size={14} className="fill-yellow-400 text-yellow-400" />
                ))}
              </div>

              {/* Quote */}
              <blockquote className="text-sm text-lp-muted leading-relaxed flex-1 italic">
                &ldquo;{t.text}&rdquo;
              </blockquote>

              {/* Author */}
              <div className="flex items-center gap-3 pt-4 border-t border-white/8">
                <div className={`w-10 h-10 rounded-full ${t.color} flex items-center justify-center font-heading font-bold text-base flex-shrink-0`}>
                  {t.avatar}
                </div>
                <div>
                  <p className="text-sm font-semibold text-lp-primary">{t.name}</p>
                  <p className="text-xs text-lp-muted">{t.role} · {t.building}</p>
                </div>
              </div>
            </div>
          ))}
        </div>
      </div>
    </section>
  )
}
