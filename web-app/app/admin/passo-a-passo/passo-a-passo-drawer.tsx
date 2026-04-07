'use client'

import { useState } from 'react'
import { BookOpen, ChevronRight, X, ChevronLeft, Lightbulb, HelpCircle } from 'lucide-react'
import { tutorials, type Tutorial } from './tutorial-data'

export default function PassoAPassoDrawer({
  isOpen,
  onClose,
}: {
  isOpen: boolean
  onClose: () => void
}) {
  const [selectedTutorial, setSelectedTutorial] = useState<Tutorial | null>(null)
  const [activeStep, setActiveStep] = useState(0)

  // Group tutorials by section
  const sections = tutorials.reduce((acc, tutorial) => {
    if (!acc[tutorial.section]) acc[tutorial.section] = []
    acc[tutorial.section].push(tutorial)
    return acc
  }, {} as Record<string, Tutorial[]>)

  const handleSelect = (tutorial: Tutorial) => {
    setSelectedTutorial(tutorial)
    setActiveStep(0)
  }

  const handleBack = () => {
    setSelectedTutorial(null)
    setActiveStep(0)
  }

  const handleClose = () => {
    setSelectedTutorial(null)
    setActiveStep(0)
    onClose()
  }

  if (!isOpen) return null

  return (
    <>
      {/* Backdrop */}
      <div
        className="fixed inset-0 bg-black/30 backdrop-blur-sm z-[100] transition-opacity duration-300"
        onClick={handleClose}
      />

      {/* Drawer */}
      <div className="fixed top-0 right-0 h-full w-full max-w-[420px] bg-white z-[101] shadow-2xl flex flex-col animate-slide-in-right">
        {/* Header */}
        <div className="bg-gradient-to-r from-[#FC5931] to-[#D42F1D] px-5 py-4 flex items-center justify-between shrink-0">
          <div className="flex items-center gap-3">
            {selectedTutorial ? (
              <button
                onClick={handleBack}
                className="p-1.5 rounded-lg bg-white/20 hover:bg-white/30 transition-colors"
                title="Voltar"
              >
                <ChevronLeft size={18} className="text-white" />
              </button>
            ) : (
              <div className="p-1.5 rounded-lg bg-white/20">
                <BookOpen size={18} className="text-white" />
              </div>
            )}
            <div>
              <h2 className="text-white font-bold text-base">
                {selectedTutorial ? selectedTutorial.title : 'Passo a Passo'}
              </h2>
              <p className="text-white/70 text-xs">
                {selectedTutorial
                  ? `${selectedTutorial.steps.length} passos`
                  : 'Aprenda a usar cada função'
                }
              </p>
            </div>
          </div>
          <button
            onClick={handleClose}
            className="p-1.5 rounded-lg hover:bg-white/20 transition-colors"
            title="Fechar"
          >
            <X size={20} className="text-white" />
          </button>
        </div>

        {/* Content */}
        <div className="flex-1 overflow-y-auto">
          {!selectedTutorial ? (
            /* ── Tutorial List ─────────────────────────────────────────── */
            <div className="p-4 space-y-5">
              {/* Intro card */}
              <div className="bg-blue-50 border border-blue-100 rounded-2xl p-4 flex gap-3">
                <div className="shrink-0 mt-0.5">
                  <HelpCircle size={20} className="text-blue-500" />
                </div>
                <div>
                  <p className="text-sm font-semibold text-blue-800">Como funciona?</p>
                  <p className="text-xs text-blue-600 mt-1">
                    Escolha uma função abaixo e siga os passos para aprender a usar. 
                    É simples e rápido! 😊
                  </p>
                </div>
              </div>

              {Object.entries(sections).map(([sectionName, items]) => (
                <div key={sectionName}>
                  <p className="text-[10px] uppercase tracking-[0.12em] font-bold text-gray-400 mb-2 px-1">
                    {sectionName}
                  </p>
                  <div className="space-y-1.5">
                    {items.map(tutorial => (
                      <button
                        key={tutorial.id}
                        onClick={() => handleSelect(tutorial)}
                        className="w-full flex items-center gap-3 px-4 py-3 rounded-xl bg-gray-50 hover:bg-gray-100 border border-gray-100 hover:border-gray-200 transition-all group text-left"
                      >
                        <span className="text-xl">{tutorial.emoji}</span>
                        <div className="flex-1 min-w-0">
                          <p className="text-sm font-semibold text-gray-800 truncate">
                            {tutorial.title}
                          </p>
                          <p className="text-[11px] text-gray-400">
                            {tutorial.steps.length} passos
                          </p>
                        </div>
                        <ChevronRight
                          size={16}
                          className="text-gray-300 group-hover:text-[#FC5931] transition-colors shrink-0"
                        />
                      </button>
                    ))}
                  </div>
                </div>
              ))}
            </div>
          ) : (
            /* ── Step-by-Step View ─────────────────────────────────────── */
            <div className="p-4 space-y-4">
              {/* Progress bar */}
              <div className="flex items-center gap-1 px-1">
                {selectedTutorial.steps.map((_, idx) => (
                  <button
                    key={idx}
                    onClick={() => setActiveStep(idx)}
                    className={`flex-1 h-1.5 rounded-full transition-all duration-300 ${
                      idx <= activeStep
                        ? 'bg-[#FC5931]'
                        : 'bg-gray-200'
                    }`}
                    title={`Passo ${idx + 1}`}
                  />
                ))}
              </div>

              <p className="text-xs text-gray-400 text-center">
                Passo {activeStep + 1} de {selectedTutorial.steps.length}
              </p>

              {/* Active step card */}
              <div className="bg-white rounded-2xl border-2 border-[#FC5931]/20 shadow-sm p-5 space-y-4">
                <div className="flex items-start gap-4">
                  <div className="w-12 h-12 rounded-2xl bg-[#FC5931]/10 flex items-center justify-center shrink-0 text-2xl">
                    {selectedTutorial.steps[activeStep].emoji}
                  </div>
                  <div>
                    <div className="flex items-center gap-2 mb-1">
                      <span className="bg-[#FC5931] text-white text-[10px] font-bold px-2 py-0.5 rounded-full">
                        PASSO {activeStep + 1}
                      </span>
                    </div>
                    <h3 className="text-lg font-bold text-gray-900">
                      {selectedTutorial.steps[activeStep].title}
                    </h3>
                  </div>
                </div>

                <p className="text-sm text-gray-600 leading-relaxed">
                  {selectedTutorial.steps[activeStep].description}
                </p>

                {selectedTutorial.steps[activeStep].tip && (
                  <div className="bg-amber-50 border border-amber-100 rounded-xl p-3 flex gap-2.5">
                    <Lightbulb size={16} className="text-amber-500 shrink-0 mt-0.5" />
                    <p className="text-xs text-amber-700">
                      <span className="font-semibold">Dica: </span>
                      {selectedTutorial.steps[activeStep].tip}
                    </p>
                  </div>
                )}
              </div>

              {/* All steps overview */}
              <div className="space-y-2 mt-4">
                <p className="text-xs font-bold text-gray-400 uppercase tracking-wider px-1">
                  Todos os passos
                </p>
                {selectedTutorial.steps.map((step, idx) => (
                  <button
                    key={idx}
                    onClick={() => setActiveStep(idx)}
                    className={`w-full flex items-center gap-3 px-4 py-3 rounded-xl text-left transition-all ${
                      idx === activeStep
                        ? 'bg-[#FC5931]/5 border-2 border-[#FC5931]/30'
                        : idx < activeStep
                        ? 'bg-green-50/50 border border-green-100'
                        : 'bg-gray-50 border border-gray-100 hover:bg-gray-100'
                    }`}
                  >
                    <div className={`w-8 h-8 rounded-full flex items-center justify-center shrink-0 text-sm font-bold ${
                      idx === activeStep
                        ? 'bg-[#FC5931] text-white'
                        : idx < activeStep
                        ? 'bg-green-500 text-white'
                        : 'bg-gray-200 text-gray-500'
                    }`}>
                      {idx < activeStep ? '✓' : idx + 1}
                    </div>
                    <div className="flex-1 min-w-0">
                      <p className={`text-sm font-medium truncate ${
                        idx === activeStep ? 'text-[#FC5931]' : 'text-gray-700'
                      }`}>
                        {step.title}
                      </p>
                    </div>
                    <span className="text-lg">{step.emoji}</span>
                  </button>
                ))}
              </div>

              {/* Navigation buttons */}
              <div className="flex gap-3 pt-2">
                <button
                  onClick={() => setActiveStep(prev => Math.max(0, prev - 1))}
                  disabled={activeStep === 0}
                  className="flex-1 py-2.5 rounded-xl border border-gray-200 text-gray-600 font-medium text-sm hover:bg-gray-50 disabled:opacity-30 disabled:cursor-not-allowed transition-all"
                >
                  ← Anterior
                </button>
                {activeStep < selectedTutorial.steps.length - 1 ? (
                  <button
                    onClick={() => setActiveStep(prev => prev + 1)}
                    className="flex-1 py-2.5 rounded-xl bg-[#FC5931] text-white font-medium text-sm hover:bg-[#D42F1D] transition-all shadow-sm"
                  >
                    Próximo →
                  </button>
                ) : (
                  <button
                    onClick={handleBack}
                    className="flex-1 py-2.5 rounded-xl bg-green-500 text-white font-medium text-sm hover:bg-green-600 transition-all shadow-sm"
                  >
                    ✅ Concluído!
                  </button>
                )}
              </div>
            </div>
          )}
        </div>
      </div>

      {/* Animation styles */}
      <style jsx>{`
        @keyframes slideInRight {
          from { transform: translateX(100%); }
          to { transform: translateX(0); }
        }
        .animate-slide-in-right {
          animation: slideInRight 0.3s ease-out;
        }
      `}</style>
    </>
  )
}
