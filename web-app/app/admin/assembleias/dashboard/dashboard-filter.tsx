"use client";

import { useRouter, useSearchParams } from 'next/navigation';

export default function DashboardFilter({ assembleias }: { assembleias: Array<{ id: string, nome: string, data_inicio?: string }> }) {
  const router = useRouter();
  const searchParams = useSearchParams();
  const currentId = searchParams.get('assembleia') || 'todas';

  return (
    <div className="flex flex-col sm:flex-row sm:items-center gap-3 bg-white p-4 rounded-2xl border border-gray-200/60 shadow-sm w-full md:w-auto">
      <label htmlFor="assembleia-select" className="text-sm font-semibold tracking-tight text-gray-700 whitespace-nowrap">
        Analisar Assembleia:
      </label>
      <select 
        id="assembleia-select"
        value={currentId} 
        onChange={(e) => {
          const val = e.target.value;
          if (val === 'todas') {
            router.push('/admin/assembleias/dashboard');
          } else {
            router.push(`/admin/assembleias/dashboard?assembleia=${val}`);
          }
        }}
        className="flex-1 min-w-[250px] bg-gray-50 border border-gray-200 text-gray-900 text-sm rounded-xl focus:ring-[#FC5931] focus:border-[#FC5931] block p-2.5 transition-colors"
      >
        <option value="todas">📊 Visão Global (Todas as Assembleias)</option>
        {assembleias.map(a => (
          <option key={a.id} value={a.id}>
            {a.nome}
          </option>
        ))}
      </select>
    </div>
  );
}
