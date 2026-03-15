import { ArrowRight, Play, Shield, Zap, Users } from 'lucide-react'

export default function HeroSection() {
  return (
    <section className="relative min-h-screen flex items-center overflow-hidden pt-24 pb-16">
      {/* Background grid pattern */}
      <div className="absolute inset-0 lp-grid-bg opacity-30" />

      {/* Radial glow */}
      <div className="absolute top-1/3 left-1/2 -translate-x-1/2 -translate-y-1/2 w-[900px] h-[600px] rounded-full bg-lp-accent/10 blur-[120px] pointer-events-none" />

      <div className="lp-container relative z-10 grid lg:grid-cols-2 gap-12 items-center">
        {/* Left: Text */}
        <div>
          {/* Eyebrow tag */}
          <div className="inline-flex items-center gap-2 px-3 py-1.5 rounded-full bg-lp-accent/15 border border-lp-accent/30 mb-6">
            <span className="w-1.5 h-1.5 rounded-full bg-lp-accent animate-pulse" />
            <span className="text-xs font-semibold text-lp-accent tracking-wide uppercase">
              Gestão de Condomínios
            </span>
          </div>

          <h1 className="font-heading text-5xl md:text-6xl font-extrabold text-lp-primary leading-[1.08] tracking-tight mb-6">
            O Condomínio{' '}
            <span className="text-lp-accent">do Futuro</span>{' '}
            começa aqui
          </h1>

          <p className="text-lg text-lp-muted leading-relaxed mb-8 max-w-lg">
            Autorize visitantes, gerencie encomendas, reserve áreas comuns e tudo mais — em um app moderno e fácil de usar.
          </p>

          {/* CTAs */}
          <div className="flex flex-wrap items-center gap-4 mb-12">
            <a
              href="/login"
              className="lp-btn-primary inline-flex items-center gap-2 text-base px-6 py-3.5 group cursor-pointer"
            >
              Começar Grátis
              <ArrowRight size={16} className="group-hover:translate-x-0.5 transition-transform duration-200" />
            </a>
            <a
              href="https://www.youtube.com/@condomeet"
              target="_blank"
              rel="noopener noreferrer"
              className="inline-flex items-center gap-2.5 px-5 py-3.5 rounded-xl border border-white/15 text-lp-primary text-base font-semibold hover:border-lp-accent hover:text-lp-accent transition-all duration-200 cursor-pointer"
            >
              <div className="w-7 h-7 rounded-full bg-white/10 flex items-center justify-center">
                <Play size={12} className="ml-0.5" />
              </div>
              Ver Demonstração
            </a>
          </div>

          {/* Mini trust badges */}
          <div className="flex flex-wrap items-center gap-6 text-sm text-lp-muted">
            {[
              { icon: Shield, text: 'Dados seguros' },
              { icon: Zap, text: '30 dias grátis' },
              { icon: Users, text: 'Sem cartão de crédito' },
            ].map(({ icon: Icon, text }) => (
              <div key={text} className="flex items-center gap-2">
                <Icon size={14} className="text-lp-accent" />
                <span>{text}</span>
              </div>
            ))}
          </div>
        </div>

        {/* Right: App Mockup */}
        <div className="relative flex justify-center lg:justify-end">
          <div className="relative w-full max-w-md">
            {/* Glow behind phone */}
            <div className="absolute inset-0 bg-lp-accent/20 blur-[80px] rounded-full scale-75" />

            {/* Phone frame */}
            <div className="relative lp-glass rounded-[2.5rem] border border-white/15 overflow-hidden shadow-2xl shadow-black/50 mx-auto w-72">
              {/* Status bar */}
              <div className="bg-lp-surface/80 px-6 pt-4 pb-2 flex items-center justify-between">
                <span className="text-[10px] text-lp-muted font-medium">9:41</span>
                <div className="flex gap-1">
                  <div className="w-4 h-2 rounded-sm bg-lp-accent/60" />
                  <div className="w-4 h-2 rounded-sm bg-white/20" />
                </div>
              </div>

              {/* App content mockup */}
              <div className="bg-[#0a1628] px-4 pb-6 pt-3">
                {/* Header */}
                <div className="flex items-center justify-between mb-4">
                  <div>
                    <p className="text-[10px] text-lp-muted">Olá, Morador!</p>
                    <p className="text-sm font-bold text-lp-primary">Condomínio Solar</p>
                  </div>
                  <div className="w-8 h-8 rounded-full bg-lp-accent/20 border border-lp-accent/30 flex items-center justify-center">
                    <span className="text-xs font-bold text-lp-accent">M</span>
                  </div>
                </div>

                {/* Notification card */}
                <div className="lp-glass rounded-2xl p-3 border border-lp-accent/20 mb-3">
                  <div className="flex items-start gap-2.5">
                    <div className="w-8 h-8 rounded-xl bg-lp-accent/20 flex items-center justify-center flex-shrink-0">
                      <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="#FC3951" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
                        <path d="M20 12V22H4V12"/><path d="M22 7H2v5h20V7z"/><path d="M12 22V7"/><path d="M12 7H7.5a2.5 2.5 0 0 1 0-5C11 2 12 7 12 7z"/><path d="M12 7h4.5a2.5 2.5 0 0 0 0-5C13 2 12 7 12 7z"/>
                      </svg>
                    </div>
                    <div>
                      <p className="text-[11px] font-semibold text-lp-primary">📦 Encomenda chegou!</p>
                      <p className="text-[9px] text-lp-muted mt-0.5">Disponível para retirada</p>
                      <p className="text-[9px] text-lp-accent mt-1 font-medium">Agora mesmo</p>
                    </div>
                  </div>
                </div>

                {/* Quick actions grid */}
                <div className="grid grid-cols-3 gap-2">
                  {[
                    { label: 'Visitantes', color: 'bg-blue-500/20', stroke: '#60a5fa' },
                    { label: 'Reservas', color: 'bg-purple-500/20', stroke: '#a78bfa' },
                    { label: 'Avisos', color: 'bg-green-500/20', stroke: '#4ade80' },
                    { label: 'SOS', color: 'bg-red-500/20', stroke: '#f87171' },
                    { label: 'Portaria', color: 'bg-yellow-500/20', stroke: '#fbbf24' },
                    { label: 'Mais', color: 'bg-white/10', stroke: '#8FA3B8' },
                  ].map(({ label, color }) => (
                    <div key={label} className={`${color} rounded-xl p-2.5 flex flex-col items-center gap-1`}>
                      <div className="w-4 h-4 rounded bg-white/10" />
                      <span className="text-[8px] text-lp-muted font-medium">{label}</span>
                    </div>
                  ))}
                </div>
              </div>
            </div>

            {/* Floating badges */}
            <div className="absolute -left-8 top-1/3 lp-glass border border-white/12 rounded-2xl px-3 py-2.5 shadow-xl">
              <p className="text-[10px] text-lp-muted">Visitantes hoje</p>
              <p className="text-lg font-bold text-lp-primary">12</p>
              <p className="text-[9px] text-green-400">↑ 3 aprovados</p>
            </div>

            <div className="absolute -right-6 bottom-24 lp-glass border border-white/12 rounded-2xl px-3 py-2.5 shadow-xl">
              <div className="flex items-center gap-2">
                <div className="w-5 h-5 rounded-lg bg-lp-accent/20 flex items-center justify-center">
                  <svg width="10" height="10" viewBox="0 0 24 24" fill="none" stroke="#FC3951" strokeWidth="2.5" strokeLinecap="round">
                    <path d="M20 6 9 17l-5-5"/>
                  </svg>
                </div>
                <div>
                  <p className="text-[9px] text-lp-muted">Reserva</p>
                  <p className="text-[10px] font-bold text-lp-primary">Confirmada!</p>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </section>
  )
}
