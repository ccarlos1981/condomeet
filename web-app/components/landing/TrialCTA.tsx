import { ArrowRight, CheckCircle2 } from 'lucide-react'

const benefits = [
  'Sem compromisso de fidelidade',
  'Sem cartão de crédito',
  'Cancele quando quiser',
  'Suporte incluído no plano',
]

export default function TrialCTA() {
  return (
    <section className="py-24">
      <div className="lp-container">
        <div className="relative rounded-3xl overflow-hidden">
          {/* Background gradient */}
          <div className="absolute inset-0 bg-gradient-to-br from-lp-accent via-[#d05120] to-[#a03c18]" />

          {/* Pattern overlay */}
          <div className="absolute inset-0 lp-grid-bg opacity-15" />

          {/* Glow */}
          <div className="absolute top-0 right-0 w-80 h-80 bg-white/10 rounded-full blur-[80px]" />

          <div className="relative z-10 px-10 py-16 md:px-16 flex flex-col md:flex-row items-center justify-between gap-10">
            {/* Left text */}
            <div className="text-center md:text-left">
              <p className="text-white/70 text-sm font-semibold uppercase tracking-wider mb-3">
                Sem riscos
              </p>
              <h2 className="font-heading text-4xl md:text-5xl font-extrabold text-white mb-4 leading-tight">
                30 dias grátis.{' '}
                <span className="text-white/80">Comece agora.</span>
              </h2>
              <p className="text-white/75 text-lg max-w-md">
                Teste completo, sem restrições. Veja a diferença que o Condomeet faz no seu dia a dia.
              </p>

              <div className="mt-8">
                <a
                  href="/login"
                  className="inline-flex items-center gap-2.5 bg-white text-lp-accent font-bold text-base px-7 py-4 rounded-xl hover:bg-white/95 hover:shadow-xl hover:shadow-black/20 transition-all duration-200 cursor-pointer group"
                >
                  Começar período gratuito
                  <ArrowRight size={16} className="group-hover:translate-x-0.5 transition-transform duration-200" />
                </a>
              </div>
            </div>

            {/* Right benefits */}
            <ul className="flex flex-col gap-3 flex-shrink-0">
              {benefits.map((b) => (
                <li key={b} className="flex items-center gap-3">
                  <div className="w-5 h-5 rounded-full bg-white/20 flex items-center justify-center flex-shrink-0">
                    <CheckCircle2 size={13} className="text-white" />
                  </div>
                  <span className="text-white/90 text-sm font-medium">{b}</span>
                </li>
              ))}
            </ul>
          </div>
        </div>
      </div>
    </section>
  )
}
