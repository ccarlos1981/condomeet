const steps = [
  {
    number: '01',
    title: 'Cadastre seu Condomínio',
    desc: 'O síndico se registra em minutos. Configure blocos, unidades e adicione os moradores de forma simples.',
  },
  {
    number: '02',
    title: 'Convide os Moradores',
    desc: 'Cada morador recebe um convite e cria sua conta. Acesso pelo app iOS, Android ou pelo navegador.',
  },
  {
    number: '03',
    title: 'Gerencie com Facilidade',
    desc: 'Tudo em um só lugar: visitantes, encomendas, reservas, avisos e muito mais. Simples, seguro e conectado.',
  },
]

export default function HowItWorks() {
  return (
    <section id="como-funciona" className="py-24 relative overflow-hidden">
      {/* Subtle background accent */}
      <div className="absolute right-0 top-0 w-[600px] h-full bg-lp-accent/5 rounded-l-full blur-[80px] pointer-events-none" />

      <div className="lp-container relative z-10">
        {/* Header */}
        <div className="text-center mb-16">
          <div className="inline-flex items-center gap-2 px-3 py-1.5 rounded-full bg-lp-accent/15 border border-lp-accent/25 mb-4">
            <span className="text-xs font-semibold text-lp-accent uppercase tracking-wide">Como Funciona</span>
          </div>
          <h2 className="font-heading text-4xl md:text-5xl font-extrabold text-lp-primary mb-4">
            Simples de começar
          </h2>
          <p className="text-lp-muted text-lg max-w-lg mx-auto">
            Em menos de 10 minutos seu condomínio já está funcionando na plataforma.
          </p>
        </div>

        {/* Steps */}
        <div className="grid md:grid-cols-3 gap-6 relative">
          {/* Connecting line (desktop) */}
          <div className="hidden md:block absolute top-10 left-[16.67%] right-[16.67%] h-px bg-gradient-to-r from-transparent via-lp-accent/30 to-transparent" />

          {steps.map((step, i) => (
            <div key={step.number} className="relative group">
              {/* Step number */}
              <div className="flex items-center justify-center mb-6">
                <div className="relative">
                  <div className="w-16 h-16 rounded-2xl bg-lp-surface border border-white/10 flex items-center justify-center group-hover:border-lp-accent/50 transition-colors duration-300">
                    <span className="font-heading text-2xl font-black text-lp-accent">{step.number}</span>
                  </div>
                  {/* Animated ring */}
                  <div className="absolute inset-0 rounded-2xl border border-lp-accent/30 scale-110 opacity-0 group-hover:opacity-100 group-hover:scale-125 transition-all duration-500" />
                </div>
              </div>

              {/* Content card */}
              <div className="lp-glass rounded-2xl border border-white/8 p-6 text-center group-hover:border-white/20 transition-colors duration-300">
                <h3 className="font-heading text-lg font-bold text-lp-primary mb-3">{step.title}</h3>
                <p className="text-sm text-lp-muted leading-relaxed">{step.desc}</p>
              </div>
            </div>
          ))}
        </div>
      </div>
    </section>
  )
}
