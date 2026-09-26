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
  DependenteData,
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
    .select(`
      id,
      resident_id,
      guest_name,
      visitor_type,
      status,
      validity_date,
      valid_until,
      qr_data,
      created_at,
      visitante_compareceu,
      liberado_em,
      liberado_por,
      documento,
      placa,
      whatsapp,
      observacao,
      cracha_referencia,
      bloco_destino,
      apto_destino,
      criado_por_portaria
    `)
    .eq('resident_id', id)
    .eq('condominio_id', condoId)
    .order('created_at', { ascending: false })
    .limit(20)

  const convites: ConviteData[] = (rawConvites ?? []).map((c: any) => ({
    id: c.id,
    resident_id: c.resident_id,
    guest_name: c.guest_name,
    visitor_type: c.visitor_type,
    status: c.status,
    validity_date: c.validity_date,
    valid_until: c.valid_until,
    qr_data: c.qr_data,
    created_at: c.created_at,
    visitante_compareceu: c.visitante_compareceu,
    liberado_em: c.liberado_em,
    liberado_por: c.liberado_por,
    documento: c.documento,
    placa: c.placa,
    whatsapp: c.whatsapp,
    observacao: c.observacao,
    cracha_referencia: c.cracha_referencia,
    bloco_destino: c.bloco_destino,
    apto_destino: c.apto_destino,
    criado_por_portaria: c.criado_por_portaria,
  })) as ConviteData[]

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
      foto_path,
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
      foto_path,
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

  // 12. Fetch dependentes associated with this resident strictly in this condominium (Gate 3G.3-B1)
  const { data: rawDependentes, error: dependentesError } = await supabase
    .from('dependentes')
    .select(`
      id,
      condominio_id,
      unidade_id,
      responsavel_perfil_id,
      nome_completo,
      parentesco,
      data_nascimento,
      foto_path,
      observacao,
      status,
      perfil_convertido_id,
      created_at,
      updated_at
    `)
    .eq('responsavel_perfil_id', id)
    .eq('condominio_id', condoId)
    .order('status', { ascending: true }) // 'ativo' comes before 'inativo' alphabetically
    .order('nome_completo', { ascending: true })

  if (dependentesError) {
    console.error('[Resident360Page] Falha na consulta de dependentes (perfil_id: %s, condo_id: %s):', id, condoId, dependentesError.message)
  }

  // 13. Batch generate temporary signed URLs for resident, pet, vehicle and dependent photos (Gate 3F.2-B, Gate 3J & Gate 3K)
  const veiculoPaths = (rawVeiculos ?? []).map((v: any) => v.foto_path).filter(Boolean) as string[]
  const petPaths = (rawPets ?? []).map((p: any) => p.foto_path).filter(Boolean) as string[]
  const dependentePaths = (rawDependentes ?? []).map((d: any) => d.foto_path).filter(Boolean) as string[]

  // Resolução canônica de foto do morador:
  // - Se começar com http:// ou https:// -> URL legada pública direta (preserva 106 fotos legadas)
  // - Se for path relativo -> incluir no lote de assinatura privada do Storage base-cadastral-media
  const isResidentLegacyUrl = Boolean(
    resident.foto_url &&
    (resident.foto_url.startsWith('http://') || resident.foto_url.startsWith('https://'))
  )
  const residentRelativePath = resident.foto_url && !isResidentLegacyUrl ? resident.foto_url : null

  const allPathsToSign = Array.from(new Set([
    ...veiculoPaths,
    ...petPaths,
    ...dependentePaths,
    ...(residentRelativePath ? [residentRelativePath] : []),
  ]))

  const signedUrlMap = new Map<string, string>()

  if (allPathsToSign.length > 0) {
    try {
      const { data: signedData, error: signError } = await supabase
        .storage
        .from('base-cadastral-media')
        .createSignedUrls(allPathsToSign, 3600) // 1 hour ephemeral signature

      if (signError) {
        console.error('[Resident360Page] Falha ao gerar signed URLs para fotos:', signError.message)
      } else if (signedData) {
        signedData.forEach((item: any) => {
          if (item?.path && item?.signedUrl) {
            signedUrlMap.set(item.path, item.signedUrl)
          }
        })
      }
    } catch (err: any) {
      console.error('[Resident360Page] Exceção ao gerar signed URLs de fotos:', err?.message || err)
    }
  }

  let residentFotoSignedUrl: string | null = null
  if (isResidentLegacyUrl) {
    residentFotoSignedUrl = resident.foto_url
  } else if (residentRelativePath) {
    residentFotoSignedUrl = signedUrlMap.get(residentRelativePath) || null
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
    foto_path: v.foto_path || null,
    foto_signed_url: v.foto_path ? (signedUrlMap.get(v.foto_path) || null) : null,
    created_at: v.created_at,
    updated_at: v.updated_at,
    unidade_bloco: v.unidades?.blocos?.nome_ou_numero || null,
    unidade_apto: v.unidades?.apartamentos?.numero || null,
  }))

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
    foto_path: p.foto_path || null,
    foto_signed_url: p.foto_path ? (signedUrlMap.get(p.foto_path) || null) : null,
    created_at: p.created_at,
    updated_at: p.updated_at,
    unidade_bloco: p.unidades?.blocos?.nome_ou_numero || null,
    unidade_apto: p.unidades?.apartamentos?.numero || null,
  }))

  const dependentes: DependenteData[] = (rawDependentes ?? []).map((d: any) => ({
    id: d.id,
    condominio_id: d.condominio_id,
    unidade_id: d.unidade_id,
    responsavel_perfil_id: d.responsavel_perfil_id,
    nome_completo: d.nome_completo,
    parentesco: d.parentesco,
    data_nascimento: d.data_nascimento,
    foto_path: d.foto_path || null,
    foto_signed_url: d.foto_path ? (signedUrlMap.get(d.foto_path) || null) : null,
    observacao: d.observacao,
    status: d.status,
    perfil_convertido_id: d.perfil_convertido_id || null,
    created_at: d.created_at,
    updated_at: d.updated_at,
  }))

  const residentWithSignedUrl: ResidentData = {
    ...(resident as ResidentData),
    foto_signed_url: residentFotoSignedUrl,
  }

  return (
    <Resident360Client
      resident={residentWithSignedUrl}
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
      dependentes={dependentes}
      dependentesError={dependentesError ? 'Não foi possível carregar os dados de dependentes devido a uma falha no banco de dados.' : null}
    />
  )
}
