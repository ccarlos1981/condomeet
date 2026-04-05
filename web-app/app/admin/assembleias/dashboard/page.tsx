import React from 'react';
import { createClient } from '@/lib/supabase/server';
import { redirect } from 'next/navigation';
import {
  BarChart3,
  Users,
  Building2,
  CalendarDays,
  Target,
  FileCheck2,
  LayoutDashboard
} from 'lucide-react';

import DashboardFilter from './dashboard-filter';

export default async function GlobalAssembleiasDashboard(props: { searchParams: Promise<{ assembleia?: string }> }) {
  const searchParams = await props.searchParams;
  const filteredAssembleiaId = searchParams?.assembleia;
  const supabase = await createClient();
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) redirect('/login');

  const { data: profile } = await supabase
    .from('perfil')
    .select('condominio_id')
    .eq('id', user.id)
    .single();

  const condoId = profile?.condominio_id ?? '';

  if (!condoId) {
    return <div className="p-8 text-center text-gray-500">Condomínio não encontrado.</div>;
  }

  // Fetch all assemblies
  const { data: assembleias } = await supabase
    .from('assembleias')
    .select('*')
    .eq('condominio_id', condoId)
    .order('created_at', { ascending: false });

  // Count total units for quorum reference
  const { data: unitsRaw } = await supabase
    .from('perfil')
    .select('bloco_txt, apto_txt')
    .eq('condominio_id', condoId)
    .eq('status_aprovacao', 'aprovado')
    .not('bloco_txt', 'is', null)
    .not('apto_txt', 'is', null);

  const uniqueUnits = new Set(
    (unitsRaw ?? []).map((u: { bloco_txt: string | null; apto_txt: string | null }) => `${u.bloco_txt}-${u.apto_txt}`)
  );
  const totalUnidades = uniqueUnits.size;

  // Fetch all votes for the condo's assemblies
  let assembleiaIds = assembleias?.map((a: { id: string }) => a.id) || [];
  
  if (filteredAssembleiaId && filteredAssembleiaId !== 'todas') {
    assembleiaIds = [filteredAssembleiaId];
  }

  const { data: globalVotes } = assembleiaIds.length > 0 ? await supabase
    .from('assembleia_votos')
    .select(`
      unidade_id,
      assembleia_id,
      pauta_id,
      voto,
      unidades (
        bloco:blocos ( nome_ou_numero ),
        apartamento:apartamentos ( numero )
      )
    `)
    .in('assembleia_id', assembleiaIds) : { data: [] };

  // Calculate engagement per unit
  const unitEngagement: Record<string, { nome: string, presencas: Set<string> }> = {};
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  globalVotes?.forEach((voto: any) => {
    const bloco = voto.unidades?.bloco?.nome_ou_numero || '';
    const apto = voto.unidades?.apartamento?.numero || '';
    const unidadeNome = `${bloco}-${apto}`;
    if (bloco && apto) {
      if (!unitEngagement[unidadeNome]) {
        unitEngagement[unidadeNome] = { nome: unidadeNome, presencas: new Set() };
      }
      unitEngagement[unidadeNome].presencas.add(voto.assembleia_id);
    }
  });

  const ranking = Object.values(unitEngagement)
    .map(u => ({ nome: u.nome, totalPresencas: u.presencas.size }))
    .sort((a, b) => b.totalPresencas - a.totalPresencas);

  // Média de Engajamento
  const uniqueUnitsGlobalVoted = ranking.length;
  // This is a naive calculation for demonstration: (unique units who ever voted / total units * 100)
  const mediaEngajamento = totalUnidades > 0 ? Math.round((uniqueUnitsGlobalVoted / totalUnidades) * 100) : 0;

  // Placeholder for compiled metrics
  const isFiltered = filteredAssembleiaId && filteredAssembleiaId !== 'todas';

  const stats = {
    total: isFiltered ? 1 : (assembleias?.length || 0),
    finalizadas: isFiltered ? 
                 (assembleias?.find((a: { id: string; status: string }) => a.id === filteredAssembleiaId)?.status === 'finalizada' ? 1 : 0) : 
                 (assembleias?.filter((a: { status: string }) => a.status === 'finalizada').length || 0),
    emAndamento: isFiltered ? 
                 (assembleias?.find((a: { id: string; status: string }) => a.id === filteredAssembleiaId)?.status === 'Ao Vivo' || assembleias?.find((a: { id: string; status: string }) => a.id === filteredAssembleiaId)?.status === 'votacao' ? 1 : 0) : 
                 (assembleias?.filter((a: { status: string }) => a.status === 'Ao Vivo' || a.status === 'votacao').length || 0),
    mediaPresentes: `${mediaEngajamento}%`
  };

  const dashboardTargetTitle = filteredAssembleiaId && filteredAssembleiaId !== 'todas' ? 
    `Dashboard: ${assembleias?.find((a: { id: string; nome: string }) => a.id === filteredAssembleiaId)?.nome || ''}` : 
    'Dashboard Consolidado';

  return (
    <div className="flex-1 w-full p-4 lg:p-8 max-w-7xl mx-auto pb-20 space-y-6">
      <div className="flex flex-col md:flex-row md:items-center justify-between gap-4 mb-2">
        <div>
          <h1 className="text-3xl font-extrabold text-gray-900 tracking-tight flex items-center gap-3">
            <LayoutDashboard className="text-[#FC5931] w-8 h-8" />
            {dashboardTargetTitle}
          </h1>
          <p className="text-gray-500 mt-2 text-sm">
            {filteredAssembleiaId ? 'Acompanhe as métricas e os votos lançados de forma isolada nesta assembleia.' : 'Nesta área você tem acesso à visão panorâmica do engajamento do condomínio em todas as suas assembleias.'}
          </p>
        </div>
        
        <DashboardFilter assembleias={assembleias || []} />
      </div>

      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
        <div className="bg-white border border-gray-200/60 shadow-sm rounded-2xl overflow-hidden">
          <div className="p-6">
            <div className="flex items-center justify-between">
              <div>
                <p className="text-sm font-medium text-gray-500 mb-1">Total Assembleias</p>
                <div className="text-3xl font-black text-gray-900">{stats.total}</div>
              </div>
              <div className="w-12 h-12 rounded-full bg-blue-50 flex items-center justify-center text-blue-500">
                <CalendarDays size={24} />
              </div>
            </div>
          </div>
        </div>
        
        <div className="bg-white border border-gray-200/60 shadow-sm rounded-2xl overflow-hidden">
          <div className="p-6">
            <div className="flex items-center justify-between">
              <div>
                <p className="text-sm font-medium text-gray-500 mb-1">Assembleias Finalizadas</p>
                <div className="text-3xl font-black text-emerald-600">{stats.finalizadas}</div>
              </div>
              <div className="w-12 h-12 rounded-full bg-emerald-50 flex items-center justify-center text-emerald-500">
                <FileCheck2 size={24} />
              </div>
            </div>
          </div>
        </div>

        <div className="bg-white border border-gray-200/60 shadow-sm rounded-2xl overflow-hidden">
          <div className="p-6">
            <div className="flex items-center justify-between">
              <div>
                <p className="text-sm font-medium text-gray-500 mb-1">Unidades Cadastradas</p>
                <div className="text-3xl font-black text-gray-900">{totalUnidades}</div>
              </div>
              <div className="w-12 h-12 rounded-full bg-orange-50 flex items-center justify-center text-orange-500">
                <Building2 size={24} />
              </div>
            </div>
          </div>
        </div>

        <div className="bg-white border border-gray-200/60 shadow-sm rounded-2xl overflow-hidden">
          <div className="p-6">
            <div className="flex items-center justify-between">
              <div>
                <p className="text-sm font-medium text-gray-500 mb-1">Média de Engajamento</p>
                <div className="text-3xl font-black text-indigo-600">{stats.mediaPresentes}</div>
              </div>
              <div className="w-12 h-12 rounded-full bg-indigo-50 flex items-center justify-center text-indigo-500">
                <Target size={24} />
              </div>
            </div>
          </div>
        </div>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6 mt-8">
        
        <div className="bg-white border border-gray-200/60 shadow-sm rounded-2xl h-[400px] flex flex-col overflow-hidden">
          <div className="p-6 pb-2">
            <h3 className="font-bold tracking-tight text-lg flex items-center gap-2">
              <BarChart3 size={20} className="text-[#FC5931]" /> 
              {filteredAssembleiaId ? 'Engajamento Nesta Votação' : 'Volume de Assembleias no Ano'}
            </h3>
            <p className="text-sm text-gray-500 mt-1">
              {filteredAssembleiaId ? 'Pautas e distribuição de participações ativas.' : 'Comparativo de sessões abertas nos últimos meses.'}
            </p>
          </div>
          <div className="p-6 flex-1 flex flex-col justify-center">
            {filteredAssembleiaId ? (
              <div className="w-full flex items-center justify-between text-center gap-4">
                 <div className="flex-1 bg-emerald-50 rounded-xl p-4">
                   <p className="text-sm text-emerald-600 font-bold mb-1">Média Presentes</p>
                   <p className="text-3xl font-black text-emerald-700">{mediaEngajamento}%</p>
                   <p className="text-xs text-emerald-600/70 mt-1">das unidades confirmadas</p>
                 </div>
                 <div className="flex-1 bg-indigo-50 rounded-xl p-4">
                   <p className="text-sm text-indigo-600 font-bold mb-1">Votos Lançados</p>
                   <p className="text-3xl font-black text-indigo-700">{(globalVotes || []).length}</p>
                   <p className="text-xs text-indigo-600/70 mt-1">nas pautas desta sessão</p>
                 </div>
              </div>
            ) : (
              <div className="text-gray-400 text-sm italic m-auto">
                (Gráfico em Construção - Necessário volume maior de dados globais)
              </div>
            )}
          </div>
        </div>

        <div className="bg-white border border-gray-200/60 shadow-sm rounded-2xl h-[400px] flex flex-col overflow-hidden">
          <div className="p-6 pb-2 border-b border-gray-100">
            <h3 className="font-bold tracking-tight text-lg flex items-center gap-2"><Users size={20} className="text-[#FC5931]" /> Presença por Unidade {filteredAssembleiaId ? '(Nesta Assembleia)' : '(Ranking Geral)'}</h3>
            <p className="text-sm text-gray-500 mt-1">
              Acompanhe as unidades mais engajadas nas decisões do condomínio.
            </p>
          </div>
          <div className="p-0 flex-1 overflow-y-auto">
            {ranking.length > 0 ? (
              <table className="w-full text-left text-sm">
                <thead className="bg-gray-50 text-gray-500 sticky top-0 border-b border-gray-100">
                  <tr>
                    <th className="px-6 py-3 font-medium">Unidade</th>
                    <th className="px-6 py-3 font-medium text-right">{filteredAssembleiaId ? 'Métricas Calculadas' : 'Assembleias Participadas'}</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-gray-100">
                  {ranking.map((row, idx) => (
                    <tr key={idx} className="hover:bg-gray-50/50">
                      <td className="px-6 py-3 font-medium text-gray-900">{row.nome}</td>
                      <td className="px-6 py-3 text-right">
                        <span className="inline-flex items-center justify-center bg-blue-50 text-blue-700 px-2.5 py-1 rounded-full font-bold text-xs">
                          {filteredAssembleiaId ? '✓ Presente' : row.totalPresencas}
                        </span>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            ) : (
              <div className="text-gray-500 text-sm p-8 text-center flex flex-col items-center justify-center h-full">
                <Users size={32} className="text-gray-300 mb-3" />
                <p>Nenhuma presença registrada ainda.</p>
                <p className="text-xs mt-1 text-gray-400">*As métricas começam a popular após as assembleias receberem votos.*</p>
              </div>
            )}
          </div>
        </div>
      </div>

    </div>
  );
}
