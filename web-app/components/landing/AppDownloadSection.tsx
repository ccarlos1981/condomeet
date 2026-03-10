export default function AppDownloadSection() {
  return (
    <section className="py-20">
      <div className="lp-container">
        <div className="lp-glass rounded-3xl border border-white/10 p-10 md:p-14 flex flex-col md:flex-row items-center justify-between gap-10">
          {/* Text */}
          <div>
            <p className="text-lp-accent text-sm font-semibold uppercase tracking-wider mb-3">
              Disponível para todos
            </p>
            <h2 className="font-heading text-3xl md:text-4xl font-extrabold text-lp-primary mb-3">
              Baixe o app gratuito
            </h2>
            <p className="text-lp-muted text-base max-w-md">
              Disponível para iOS e Android. Acesse também pelo navegador — sem instalar nada.
            </p>
          </div>

          {/* Buttons */}
          <div className="flex flex-col sm:flex-row gap-4 flex-shrink-0">
            {/* Google Play */}
            <a
              href="https://play.google.com/store"
              target="_blank"
              rel="noopener noreferrer"
              className="flex items-center gap-3 bg-lp-surface border border-white/12 rounded-2xl px-5 py-3.5 hover:border-white/30 hover:bg-white/5 transition-all duration-200 cursor-pointer group"
              aria-label="Disponível no Google Play"
            >
              <svg viewBox="0 0 24 24" width="28" height="28" fill="none" xmlns="http://www.w3.org/2000/svg">
                <path d="M3.18 1L13.8 12 3.18 23c-.43-.25-.68-.72-.68-1.29V2.29C2.5 1.72 2.75 1.25 3.18 1z" fill="#EA4335"/>
                <path d="M17.5 8.27L4.55 1.43 13.8 12l3.7-3.73z" fill="#FBBC05"/>
                <path d="M21.5 12c0 .77-.42 1.44-1.04 1.78l-2.96 1.49L13.8 12l3.7-3.73 2.96 1.49A2.08 2.08 0 0121.5 12z" fill="#4285F4"/>
                <path d="M4.55 22.57L17.5 15.73 13.8 12l-9.25 10.57z" fill="#34A853"/>
              </svg>
              <div>
                <p className="text-[10px] text-lp-muted leading-none">Disponível no</p>
                <p className="text-sm font-bold text-lp-primary leading-tight">Google Play</p>
              </div>
            </a>

            {/* App Store */}
            <a
              href="https://apps.apple.com"
              target="_blank"
              rel="noopener noreferrer"
              className="flex items-center gap-3 bg-lp-surface border border-white/12 rounded-2xl px-5 py-3.5 hover:border-white/30 hover:bg-white/5 transition-all duration-200 cursor-pointer group"
              aria-label="Disponível na App Store"
            >
              <svg viewBox="0 0 24 24" width="28" height="28" fill="white" xmlns="http://www.w3.org/2000/svg">
                <path d="M18.71 19.5c-.83 1.24-1.71 2.45-3.05 2.47-1.34.03-1.77-.79-3.29-.79-1.53 0-2 .77-3.27.82-1.31.05-2.3-1.32-3.14-2.53C4.25 17 2.94 12.45 4.7 9.39c.87-1.52 2.43-2.48 4.12-2.51 1.28-.02 2.5.87 3.29.87.78 0 2.26-1.07 3.8-.91.65.03 2.47.26 3.64 1.98-.09.06-2.17 1.28-2.15 3.81.03 3.02 2.65 4.03 2.68 4.04-.03.07-.42 1.44-1.38 2.83M13 3.5c.73-.83 1.94-1.46 2.94-1.5.13 1.17-.34 2.35-1.04 3.19-.69.85-1.83 1.51-2.95 1.42-.15-1.15.41-2.35 1.05-3.11z"/>
              </svg>
              <div>
                <p className="text-[10px] text-lp-muted leading-none">Disponível na</p>
                <p className="text-sm font-bold text-lp-primary leading-tight">App Store</p>
              </div>
            </a>
          </div>
        </div>
      </div>
    </section>
  )
}
