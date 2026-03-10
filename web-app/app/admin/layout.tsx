import { createClient } from '@/lib/supabase/server'
import { redirect } from 'next/navigation'

export default async function AdminLayout({ children }: { children: React.ReactNode }) {
  const supabase = await createClient()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) redirect('/login')

  const { data: profile } = await supabase
    .from('perfil')
    .select('papel_sistema, nome_completo, condominio_id')
    .eq('id', user.id)
    .single()

  const role = profile?.papel_sistema ?? ''
  const isAdmin = ['Síndico', 'Síndico (a)', 'sindico', 'ADMIN', 'admin'].some(r =>
    role.toLowerCase().includes(r.toLowerCase())
  )
  if (!isAdmin) redirect('/condo')

  const { data: condo } = await supabase
    .from('condominio')
    .select('nome')
    .eq('id', profile?.condominio_id ?? '')
    .single()

  return (
    <div className="min-h-screen bg-[#f3f4f8]">
      {/* Admin top bar */}
      <header className="bg-[#1f2d3d] text-white px-6 py-4 flex items-center justify-between shadow-lg">
        <div className="flex items-center gap-6">
          <div className="flex items-center gap-3">
            <div className="w-8 h-8 bg-[#E85D26] rounded-lg flex items-center justify-center text-xs font-bold">A</div>
            <span className="font-semibold text-sm">Painel Admin</span>
          </div>
          <nav className="hidden md:flex gap-1">
            {[
              { label: 'Dashboard',         href: '/admin' },
              { label: 'Aprovações',        href: '/admin/aprovacoes' },
              { label: 'Moradores',         href: '/admin/moradores' },
              { label: 'Avisos',            href: '/admin/avisos' },
              { label: 'Fale Conosco',      href: '/admin/fale-conosco' },
              { label: 'Áreas Comuns',      href: '/admin/areas-comuns' },
              { label: 'Reservas',          href: '/admin/reservas' },
              { label: 'Ocorrências',       href: '/condo/ocorrencias' },
              { label: 'Configurar Acesso', href: '/admin/configurar-acesso' },
              { label: 'Configurar Ordem',  href: '/admin/configurar-ordem' },
            ].map(item => (
              <a key={item.href} href={item.href}
                className="px-3 py-1.5 rounded-lg text-sm text-white/70 hover:text-white hover:bg-white/10 transition-all">
                {item.label}
              </a>
            ))}
          </nav>
        </div>
        <div className="flex items-center gap-4">
          <span className="text-sm text-white/60">{condo?.nome}</span>
          <a href="/condo" className="text-sm text-[#E85D26] hover:text-white transition-colors">→ Portal</a>
        </div>
      </header>

      <main className="p-6 max-w-6xl mx-auto">{children}</main>
    </div>
  )
}
