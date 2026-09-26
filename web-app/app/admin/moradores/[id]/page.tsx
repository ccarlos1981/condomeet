import { createClient } from '@/lib/supabase/server'
import { redirect } from 'next/navigation'
import { cookies } from 'next/headers'
import Link from 'next/link'
import { AlertCircle, ArrowLeft, UserX } from 'lucide-react'
import Resident360Client, {
  ResidentData,
  UnitLinkData,
  CoResidentData,
  ConviteData,
  PortariaRegistroData,
  VehicleData,
  PetData,
} from './resident-360-client'

export const metadata = {
  title: 'Página 360º do Morador — Painel Admin',
}

interface PageProps {
  params: Promise<{ id: string }>
}

export default async function Resident360Page(props: PageProps) {
  const { id } = await props.params
  const supabase = await createClient()

  // 1. Authenticate user session
  const {
    data: { user },
  } = await supabase.auth.getUser()
  if (!user) redirect('/login')

  // 2. Resolve condominium_id for the session
  const { data: adminProfile } = await supabase
    .from('perfil')
    .select('condominio_id, papel_sistema, administradora_id')
    .eq('id', user.id)
    .single()

  let condoId = adminProfile?.condominio_id ?? ''
  if (adminProfile?.papel_sistema?.toLowerCase() === 'administradora' && adminProfile?.administradora_id) {
    const cookieStore = await cookies()
    const selectedCondoId = cookieStore.get('selected_condo_id')?.value
    if (selectedCondoId) condoId = selectedCondoId
  }

  if (!condoId) redirect('/admin')

  // 3. Fetch condominium metadata
  const { data: condo } = await supabase
    .from('condominios')
    .select('nome, tipo_estrutura')
    .eq('id', condoId)
    .single()

  const condoNome = condo?.nome ?? 'Condomínio'
  const condoTipoEstrutura = condo?.tipo_estrutura ?? 'predio'

  // 4. Fetch target resident profile strictly scoped to the session's condo (Multi-tenant guard)
  const { data: resident, error: residentError } = await supabase
    .from('perfil')
    .select(
      'id, condominio_id, nome_completo, email, whatsapp, whatsapp_msg_consent, bloqueado, status_aprovacao, tipo_morador, papel_sistema, bloco_txt, apto_txt, foto_url, notificacoes_whatsapp, needs_password_setup, last_interaction_at, created_at, updated_at'
    )
    .eq('id', id)
    .eq('condominio_id', condoId)
    .maybeSingle()

  if (residentError || !resident) {
    return (
      <div className="p-6 max-w-4xl mx-auto">
        <Link
          href="/admin/moradores"
          className="inline-flex items-center gap-2 text-sm font-semibold text-gray-600 hover:text-[#FC5931] mb-6 transition-colors"
        >
          <ArrowLeft size={16} /> Voltar para Moradores
        </Link>
        <div className="bg-white rounded-2xl border border-gray-100 shadow-sm p-12 text-center">
          <div className="w-16 h-16 bg-red-50 rounded-2xl mx-auto mb-4 flex items-center justify-center text-red-500">
            <UserX size={32} />
          </div>
          <h2 className="text-xl font-bold text-gray-900 mb-2">Morador não encontrado</h2>
          <p className="text-gray-500 text-sm max-w-md mx-auto mb-6">
            O cadastro solicitado não foi localizado ou não pertence ao condomínio atualmente selecionado (isolamento multi-tenant).
          </p>
          <Link
            href="/admin/moradores"
            className="inline-flex items-center gap-2 px-5 py-2.5 rounded-xl bg-[#FC5931] text-white font-semibold text-sm hover:bg-[#e04820] transition-colors"
          >
            Retornar para a lista de moradores
          </Link>
        </div>
      </div>
    )
  }

  // 5. Fetch relational unit links from unidade_perfil
  const { data: rawUnitLinks } = await supabase
    .from('unidade_perfil')
    .select(`
      id,
      status,
      data_entrada,
      data_saida,
      created_at,
      unidade_id,
      unidades (
        id,
        fracao_ideal,
        bloqueada,
        blocos (
          id,
          nome_ou_numero
        ),
        apartamentos (
          id,
          numero
        )
      )
    `)
    .eq('perfil_id', id)
    .order('created_at', { ascending: false })

  const unitLinks: UnitLinkData[] = (rawUnitLinks ?? []).map((ul: any) => {
    const u = ul.unidades
    return {
      id: ul.id,
      status: ul.status,
      data_entrada: ul.data_entrada,
      data_saida: ul.data_saida,
      created_at: ul.created_at,
      unidade_id: ul.unidade_id,
      fracao_ideal: u?.fracao_ideal,
      bloqueada: u?.bloqueada,
      bloco_nome: u?.blocos?.nome_ou_numero,
      apto_numero: u?.apartamentos?.numero,
    }
  })

  // 6. Fetch co-residents currently active in the same physical unit
  let coResidents: CoResidentData[] = []
  const activeLink = unitLinks.find(u => u.status === 'ativo')
  if (activeLink?.unidade_id) {
    const { data: coLinks } = await supabase
      .from('unidade_perfil')
      .select(`
        id,
        data_entrada,
        perfil:perfil_id (
          id,
          nome_completo,
          email,
          whatsapp,
          papel_sistema,
          tipo_morador,
          status_aprovacao,
          foto_url
        )
      `)
      .eq('unidade_id', activeLink.unidade_id)
      .eq('status', 'ativo')

    coResidents = (coLinks ?? []).reduce<CoResidentData[]>((acc, cl: any) => {
      const p = cl.perfil
      if (p && p.id && p.id !== id) {
        acc.push({
          id: p.id,
          nome_completo: p.nome_completo,
          email: p.email,
          whatsapp: p.whatsapp,
          papel_sistema: p.papel_sistema,
          tipo_morador: p.tipo_morador,
          status_aprovacao: p.status_aprovacao,
          foto_url: p.foto_url,
          dataEntrada: cl.data_entrada,
        })
      }
      return acc
    }, [])
  }

  // 7. Fetch recent convites emitted by this resident
  const { data: rawConvites } = await supabase
    .from('convites')
    .select('id, guest_name, visitor_type, status, validity_date, qr_data, created_at, visitante_compareceu')
    .eq('resident_id', id)
    .eq('condominio_id', condoId)
    .order('created_at', { ascending: false })
    .limit(20)

  const convites: ConviteData[] = (rawConvites ?? []).map((c: any) => ({
    id: c.id,
    guest_name: c.guest_name,
    visitor_type: c.visitor_type,
    status: c.status,
    validity_date: c.validity_date,
    qr_data: c.qr_data,
    created_at: c.created_at,
    visitante_compareceu: c.visitante_compareceu,
  }))

  // 8. Fetch recent concierge visitor logs directed to this unit
  let portariaRegistros: PortariaRegistroData[] = []
  if (resident.bloco_txt && resident.apto_txt) {
    const { data: rawRegistros } = await supabase
      .from('visitante_registros')
      .select('id, nome, tipo_visitante, entrada_at, saida_at, status, created_at')
      .eq('condominio_id', condoId)
      .eq('bloco', resident.bloco_txt)
      .eq('apto', resident.apto_txt)
      .order('entrada_at', { ascending: false })
      .limit(20)

    portariaRegistros = (rawRegistros ?? []).map((r: any) => ({
      id: r.id,
      nome: r.nome,
      tipo_visitante: r.tipo_visitante,
      entrada_at: r.entrada_at,
      saida_at: r.saida_at,
      status: r.status,
      created_at: r.created_at,
    }))
  }

  // 9. Fetch administrative audit logs for this resident
  const { data: rawAuditLogs } = await supabase
    .from('perfil_audit_log')
    .select(`
      id,
      acao,
      motivo,
      estado_anterior,
      estado_posterior,
      created_at,
      operador:operador_id (
        id,
        nome_completo,
        papel_sistema
      ),
      unidade:unidade_id (
        id,
        blocos ( nome_ou_numero ),
        apartamentos ( numero )
      )
    `)
    .eq('perfil_id', id)
    .eq('condominio_id', condoId)
    .order('created_at', { ascending: false })
    .limit(50)

  const auditLogs = (rawAuditLogs ?? []).map((l: any) => ({
    id: l.id,
    acao: l.acao,
    motivo: l.motivo,
    estado_anterior: l.estado_anterior,
    estado_posterior: l.estado_posterior,
    created_at: l.created_at,
    operador_nome: l.operador?.nome_completo || 'Administrador',
    operador_papel: l.operador?.papel_sistema || 'Admin',
    unidade_bloco: l.unidade?.blocos?.nome_ou_numero || null,
    unidade_apto: l.unidade?.apartamentos?.numero || null,
  }))

  // 10. Fetch vehicles associated with this resident strictly in this condominium (Gate 3D.2-B)
  const { data: rawVeiculos, error: veiculosError } = await supabase
    .from('veiculos')
    .select(`
      id,
      condominio_id,
      perfil_id,
      unidade_id,
      placa,
      tipo,
      marca,
      modelo,
      cor,
      ano,
      vaga_numero,
      observacao,
      status,
      created_at,
      updated_at,
      unidades (
        id,
        blocos ( nome_ou_numero ),
        apartamentos ( numero )
      )
    `)
    .eq('perfil_id', id)
    .eq('condominio_id', condoId)
    .order('status', { ascending: true }) // 'ativo' comes before 'inativo' alphabetically
    .order('created_at', { ascending: false })

  if (veiculosError) {
    console.error('[Resident360Page] Falha na consulta de veículos (perfil_id: %s, condo_id: %s):', id, condoId, veiculosError.message)
  }

  const veiculos: VehicleData[] = (rawVeiculos ?? []).map((v: any) => ({
    id: v.id,
    condominio_id: v.condominio_id,
    perfil_id: v.perfil_id,
    unidade_id: v.unidade_id,
    placa: v.placa,
    tipo: v.tipo,
    marca: v.marca,
    modelo: v.modelo,
    cor: v.cor,
    ano: v.ano,
    vaga_numero: v.vaga_numero,
    observacao: v.observacao,
    status: v.status,
    created_at: v.created_at,
    updated_at: v.updated_at,
    unidade_bloco: v.unidades?.blocos?.nome_ou_numero || null,
    unidade_apto: v.unidades?.apartamentos?.numero || null,
  }))

  // 11. Fetch pets associated with this resident strictly in this condominium (Gate 3E.2-B)
  const { data: rawPets, error: petsError } = await supabase
    .from('pets')
    .select(`
      id,
      condominio_id,
      perfil_id,
      unidade_id,
      nome,
      especie,
      raca,
      sexo,
      porte,
      cor,
      data_nascimento,
      castrado,
      vacinado,
      observacao,
      status,
      created_at,
      updated_at,
      unidades (
        id,
        blocos ( nome_ou_numero ),
        apartamentos ( numero )
      )
    `)
    .eq('perfil_id', id)
    .eq('condominio_id', condoId)
    .order('status', { ascending: true }) // 'ativo' comes before 'inativo' alphabetically
    .order('nome', { ascending: true })

  if (petsError) {
    console.error('[Resident360Page] Falha na consulta de pets (perfil_id: %s, condo_id: %s):', id, condoId, petsError.message)
  }

  const pets: PetData[] = (rawPets ?? []).map((p: any) => ({
    id: p.id,
    condominio_id: p.condominio_id,
    perfil_id: p.perfil_id,
    unidade_id: p.unidade_id,
    nome: p.nome,
    especie: p.especie,
    raca: p.raca,
    sexo: p.sexo,
    porte: p.porte,
    cor: p.cor,
    data_nascimento: p.data_nascimento,
    castrado: p.castrado,
    vacinado: p.vacinado,
    observacao: p.observacao,
    status: p.status,
    created_at: p.created_at,
    updated_at: p.updated_at,
    unidade_bloco: p.unidades?.blocos?.nome_ou_numero || null,
    unidade_apto: p.unidades?.apartamentos?.numero || null,
  }))

  return (
    <Resident360Client
      resident={resident as ResidentData}
      condoNome={condoNome}
      condoTipoEstrutura={condoTipoEstrutura}
      unitLinks={unitLinks}
      coResidents={coResidents}
      convites={convites}
      portariaRegistros={portariaRegistros}
      auditLogs={auditLogs}
      veiculos={veiculos}
      veiculosError={veiculosError ? 'Não foi possível carregar os dados de veículos devido a uma falha no banco de dados.' : null}
      pets={pets}
      petsError={petsError ? 'Não foi possível carregar os dados de pets devido a uma falha no banco de dados.' : null}
    />
  )
}
