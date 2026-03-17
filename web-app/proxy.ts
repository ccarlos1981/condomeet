import { createServerClient } from '@supabase/ssr'
import { NextResponse, type NextRequest } from 'next/server'

export async function proxy(request: NextRequest) {
  let supabaseResponse = NextResponse.next({ request })

  const supabase = createServerClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
    {
      cookies: {
        getAll() { return request.cookies.getAll() },
        setAll(cookiesToSet) {
          cookiesToSet.forEach(({ name, value }) => request.cookies.set(name, value))
          supabaseResponse = NextResponse.next({ request })
          cookiesToSet.forEach(({ name, value, options }) =>
            supabaseResponse.cookies.set(name, value, options)
          )
        },
      },
    }
  )

  const { data: { user } } = await supabase.auth.getUser()
  const { pathname } = request.nextUrl

  // Public routes
  const publicRoutes = ['/login', '/register', '/sindico-register', '/forgot-password', '/reset-password', '/privacidade', '/pending-approval']
  if (pathname === '/' || publicRoutes.some(r => pathname.startsWith(r))) {
    if (user && (pathname.startsWith('/login') || pathname === '/')) {
      return NextResponse.redirect(new URL('/condo', request.url))
    }
    return supabaseResponse
  }

  // Protected routes — redirect to login if not authenticated
  if (!user) {
    return NextResponse.redirect(new URL('/login', request.url))
  }

  // Admin routes — check role
  if (pathname.startsWith('/admin')) {
    const { data: profile } = await supabase
      .from('perfil')
      .select('papel_sistema')
      .eq('id', user.id)
      .single()

    const role = profile?.papel_sistema ?? ''
    const isAdmin = ['Síndico', 'Síndico (a)', 'sindico', 'ADMIN', 'admin'].includes(role)
    if (!isAdmin) {
      return NextResponse.redirect(new URL('/condo', request.url))
    }
  }

  return supabaseResponse
}

export const config = {
  matcher: ['/((?!_next/static|_next/image|favicon.ico|.*\\.(?:svg|png|jpg|jpeg|gif|webp)$).*)'],
}
