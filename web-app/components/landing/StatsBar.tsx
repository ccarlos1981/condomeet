const stats = [
  { value: '500+', label: 'Condomínios Ativos', suffix: '' },
  { value: '50K+', label: 'Moradores Conectados', suffix: '' },
  { value: '200K+', label: 'Encomendas Gerenciadas', suffix: '' },
  { value: '99.9', label: 'Uptime Garantido', suffix: '%' },
]

export default function StatsBar() {
  return (
    <section className="relative py-8 overflow-hidden">
      <div className="lp-container">
        <div className="lp-glass rounded-2xl border border-white/10 px-8 py-6 grid grid-cols-2 md:grid-cols-4 gap-6 md:gap-0 md:divide-x md:divide-white/10">
          {stats.map((s) => (
            <div key={s.label} className="flex flex-col items-center text-center px-4">
              <p className="font-heading text-3xl font-extrabold text-lp-accent">
                {s.value}<span className="text-lp-accent">{s.suffix}</span>
              </p>
              <p className="text-sm text-lp-muted mt-1">{s.label}</p>
            </div>
          ))}
        </div>
      </div>
    </section>
  )
}
