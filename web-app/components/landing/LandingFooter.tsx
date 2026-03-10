import Image from 'next/image'
import { Facebook, Youtube, Instagram, MessageCircle } from 'lucide-react'

const footerLinks = {
  Produto: [
    { label: 'Funcionalidades', href: '#funcionalidades' },
    { label: 'Como Funciona', href: '#como-funciona' },
    { label: 'Depoimentos', href: '#depoimentos' },
  ],
  Legal: [
    { label: 'Termos de Uso', href: '/termos' },
    { label: 'Política de Privacidade', href: '/privacidade' },
    { label: 'Lei LGPD', href: '/lgpd' },
  ],
  Suporte: [
    { label: 'Central de Ajuda', href: '/suporte' },
    { label: 'Fale Conosco', href: 'mailto:contato@condomeet.app.br' },
    { label: 'WhatsApp', href: 'https://wa.me/5511999999999' },
  ],
}

const social = [
  { icon: Facebook, href: 'https://facebook.com', label: 'Facebook' },
  { icon: Youtube, href: 'https://youtube.com', label: 'YouTube' },
  { icon: Instagram, href: 'https://instagram.com', label: 'Instagram' },
  { icon: MessageCircle, href: 'https://wa.me/5511999999999', label: 'WhatsApp' },
]

export default function LandingFooter() {
  return (
    <footer className="border-t border-white/8 pt-16 pb-8">
      <div className="lp-container">
        <div className="grid grid-cols-2 md:grid-cols-4 gap-10 mb-12">
          {/* Brand column */}
          <div className="col-span-2 md:col-span-1">
            <a href="#" className="flex items-center gap-2.5 mb-4">
              <Image
                src="/logo.png"
                alt="Condomeet"
                width={32}
                height={32}
                className="rounded-xl object-cover"
              />
              <span className="font-heading text-lg font-bold text-lp-primary">Condomeet</span>
            </a>
            <p className="text-sm text-lp-muted leading-relaxed mb-6 max-w-[200px]">
              O condomínio do futuro é digital, seguro e conectado.
            </p>
            {/* Social icons */}
            <div className="flex gap-3">
              {social.map(({ icon: Icon, href, label }) => (
                <a
                  key={label}
                  href={href}
                  target="_blank"
                  rel="noopener noreferrer"
                  aria-label={label}
                  className="w-8 h-8 rounded-lg bg-white/8 border border-white/10 flex items-center justify-center text-lp-muted hover:text-lp-accent hover:border-lp-accent/40 hover:bg-lp-accent/10 transition-all duration-200 cursor-pointer"
                >
                  <Icon size={14} />
                </a>
              ))}
            </div>
          </div>

          {/* Link columns */}
          {Object.entries(footerLinks).map(([group, links]) => (
            <div key={group}>
              <p className="text-xs font-bold text-lp-primary uppercase tracking-wider mb-4">{group}</p>
              <ul className="space-y-3">
                {links.map((l) => (
                  <li key={l.label}>
                    <a
                      href={l.href}
                      className="text-sm text-lp-muted hover:text-lp-accent transition-colors duration-200 cursor-pointer"
                    >
                      {l.label}
                    </a>
                  </li>
                ))}
              </ul>
            </div>
          ))}
        </div>

        {/* Bottom bar */}
        <div className="border-t border-white/8 pt-6 flex flex-col sm:flex-row items-center justify-between gap-3 text-xs text-lp-muted">
          <p>© 2026 Condomeet. Todos os direitos reservados · @2SCapital</p>
          <p>Feito com ♥ no Brasil 🇧🇷</p>
        </div>
      </div>
    </footer>
  )
}
