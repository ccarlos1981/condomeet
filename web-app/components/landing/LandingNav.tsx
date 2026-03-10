'use client'
import { useState, useEffect } from 'react'
import { Menu, X } from 'lucide-react'
import Image from 'next/image'

export default function LandingNav() {
  const [scrolled, setScrolled] = useState(false)
  const [menuOpen, setMenuOpen] = useState(false)

  useEffect(() => {
    const handleScroll = () => setScrolled(window.scrollY > 20)
    window.addEventListener('scroll', handleScroll, { passive: true })
    return () => window.removeEventListener('scroll', handleScroll)
  }, [])

  const links = [
    { href: '#funcionalidades', label: 'Funcionalidades' },
    { href: '#como-funciona', label: 'Como Funciona' },
    { href: '#depoimentos', label: 'Depoimentos' },
  ]

  return (
    <header
      className={`fixed top-0 left-0 right-0 z-50 transition-all duration-300 ${
        scrolled
          ? 'lp-glass border-b border-white/8 shadow-xl shadow-black/20'
          : 'bg-transparent'
      }`}
    >
      <nav className="lp-container flex items-center justify-between py-4">
        {/* Logo */}
        <a href="#" className="flex items-center gap-2.5 group">
          <Image
            src="/logo.png"
            alt="Condomeet"
            width={36}
            height={36}
            className="rounded-xl object-cover"
          />
          <span className="font-heading text-lg font-bold text-lp-primary tracking-tight group-hover:text-lp-accent transition-colors duration-200">
            Condomeet
          </span>
        </a>

        {/* Desktop nav */}
        <ul className="hidden md:flex items-center gap-8">
          {links.map((l) => (
            <li key={l.href}>
              <a
                href={l.href}
                className="text-sm font-medium text-lp-muted hover:text-lp-primary transition-colors duration-200 cursor-pointer"
              >
                {l.label}
              </a>
            </li>
          ))}
        </ul>

        {/* Desktop CTAs */}
        <div className="hidden md:flex items-center gap-3">
          <a
            href="/login"
            className="text-sm font-semibold text-lp-muted hover:text-lp-primary transition-colors duration-200 px-4 py-2 cursor-pointer"
          >
            Entrar
          </a>
          <a
            href="/login"
            className="lp-btn-primary text-sm px-5 py-2.5 cursor-pointer"
          >
            Teste Grátis
          </a>
        </div>

        {/* Mobile hamburger */}
        <button
          className="md:hidden text-lp-primary hover:text-lp-accent transition-colors cursor-pointer p-2"
          onClick={() => setMenuOpen(!menuOpen)}
          aria-label="Abrir menu"
        >
          {menuOpen ? <X size={22} /> : <Menu size={22} />}
        </button>
      </nav>

      {/* Mobile menu */}
      {menuOpen && (
        <div className="md:hidden lp-glass border-t border-white/8 px-6 py-5 space-y-4">
          {links.map((l) => (
            <a
              key={l.href}
              href={l.href}
              className="block text-sm font-medium text-lp-muted hover:text-lp-primary transition-colors py-1 cursor-pointer"
              onClick={() => setMenuOpen(false)}
            >
              {l.label}
            </a>
          ))}
          <div className="pt-3 flex flex-col gap-2">
            <a href="/login" className="text-center text-sm font-semibold text-lp-muted py-2.5 border border-white/15 rounded-xl hover:border-lp-accent transition-colors cursor-pointer">
              Entrar
            </a>
            <a href="/login" className="lp-btn-primary text-sm text-center py-2.5 cursor-pointer">
              Teste Grátis
            </a>
          </div>
        </div>
      )}
    </header>
  )
}
