'use client'

import Link from 'next/link'
import {
  ShoppingBag, Wallet, ShoppingCart, Car, Store,
  CheckCircle2, Circle, ArrowRight, BarChart3, Megaphone
} from 'lucide-react'

type Stats = {
  garagem: number
  mercados: number
  produtos: number
  dingloUsers: number
  propaganda: number
}

type CheckItem = {
  label: string
  done: boolean
  href: string
  icon: React.ReactNode
}

type FeatureGroup = {
  title: string
  icon: React.ReactNode
  color: string
  bgColor: string
  borderColor: string
  items: CheckItem[]
}

export default function ChecklistClient({ stats }: { stats: Stats }) {
  const features: FeatureGroup[] = [
    {
      title: 'Propaganda',
      icon: <ShoppingBag size={20} />,
      color: 'text-amber-600',
      bgColor: 'bg-amber-50',
      borderColor: 'border-amber-200',
      items: [
        { label: 'Criar primeira propaganda', done: stats.propaganda > 0, href: '/admin/propaganda', icon: <Megaphone size={16} /> },
      ],
    },
    {
      title: 'Meu Bolso',
      icon: <Wallet size={20} />,
      color: 'text-blue-600',
      bgColor: 'bg-blue-50',
      borderColor: 'border-blue-200',
      items: [
        { label: 'Usuários cadastrados', done: stats.dingloUsers > 0, href: '/admin/dinglo', icon: <Wallet size={16} /> },
      ],
    },
    {
      title: 'Lista Inteligente',
      icon: <ShoppingCart size={20} />,
      color: 'text-orange-600',
      bgColor: 'bg-orange-50',
      borderColor: 'border-orange-200',
      items: [
        { label: 'Cadastrar mercados', done: stats.mercados > 0, href: '/admin/lista-b2b', icon: <Store size={16} /> },
        { label: 'Cadastrar produtos', done: stats.produtos > 0, href: '/admin/lista-inteligente', icon: <ShoppingCart size={16} /> },
        { label: 'Configurar analytics', done: stats.mercados > 0, href: '/admin/lista-analytics', icon: <BarChart3 size={16} /> },
      ],
    },
    {
      title: 'Garagem Inteligente',
      icon: <Car size={20} />,
      color: 'text-purple-600',
      bgColor: 'bg-purple-50',
      borderColor: 'border-purple-200',
      items: [
        { label: 'Vagas cadastradas', done: stats.garagem > 0, href: '/admin/garagem', icon: <Car size={16} /> },
      ],
    },
  ]

  const totalItems = features.reduce((acc, f) => acc + f.items.length, 0)
  const doneItems = features.reduce((acc, f) => acc + f.items.filter(i => i.done).length, 0)
  const progress = totalItems > 0 ? Math.round((doneItems / totalItems) * 100) : 0

  return (
    <div className="space-y-6">
      {/* Header */}
      <div>
        <h1 className="text-2xl font-bold text-gray-900 flex items-center gap-3">
          📋 Checklist — Empresas Parceiras
        </h1>
        <p className="text-sm text-gray-500 mt-1">
          Acompanhe o progresso de configuração de cada funcionalidade
        </p>
      </div>

      {/* Progress bar */}
      <div className="bg-white rounded-xl border border-gray-200 p-5">
        <div className="flex items-center justify-between mb-3">
          <span className="text-sm font-medium text-gray-700">Progresso geral</span>
          <span className="text-sm font-bold text-gray-900">{doneItems}/{totalItems} concluídos ({progress}%)</span>
        </div>
        <div className="w-full bg-gray-100 rounded-full h-3">
          <div
            className="bg-gradient-to-r from-green-400 to-emerald-500 h-3 rounded-full transition-all duration-500"
            style={{ width: `${progress}%` }}
          />
        </div>
      </div>

      {/* Feature cards */}
      <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
        {features.map(feature => {
          const featureDone = feature.items.filter(i => i.done).length
          const featureTotal = feature.items.length
          const allDone = featureDone === featureTotal

          return (
            <div
              key={feature.title}
              className={`rounded-xl border p-5 ${feature.borderColor} ${feature.bgColor}`}
            >
              <div className="flex items-center justify-between mb-4">
                <div className="flex items-center gap-2.5">
                  <span className={feature.color}>{feature.icon}</span>
                  <h3 className="font-semibold text-gray-900">{feature.title}</h3>
                </div>
                {allDone ? (
                  <span className="text-xs font-bold text-green-600 bg-green-100 px-2.5 py-1 rounded-full">
                    ✅ Completo
                  </span>
                ) : (
                  <span className="text-xs font-medium text-gray-500">
                    {featureDone}/{featureTotal}
                  </span>
                )}
              </div>
              <div className="space-y-2.5">
                {feature.items.map(item => (
                  <Link
                    key={item.label}
                    href={item.href}
                    className={`flex items-center justify-between p-3 rounded-lg transition-all ${
                      item.done
                        ? 'bg-white/50'
                        : 'bg-white hover:shadow-sm'
                    }`}
                  >
                    <div className="flex items-center gap-3">
                      {item.done ? (
                        <CheckCircle2 size={18} className="text-green-500" />
                      ) : (
                        <Circle size={18} className="text-gray-300" />
                      )}
                      <span className={`text-sm ${item.done ? 'text-gray-400 line-through' : 'text-gray-700 font-medium'}`}>
                        {item.label}
                      </span>
                    </div>
                    {!item.done && (
                      <ArrowRight size={14} className="text-gray-400" />
                    )}
                  </Link>
                ))}
              </div>
            </div>
          )
        })}
      </div>
    </div>
  )
}
