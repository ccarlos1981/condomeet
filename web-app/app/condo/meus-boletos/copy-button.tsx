'use client'

import { useState } from 'react'
import { Copy, Check } from 'lucide-react'

export default function CopyButton({ text, label, primary }: { text: string, label: string, primary?: boolean }) {
  const [copied, setCopied] = useState(false)

  function handleCopy() {
    navigator.clipboard.writeText(text)
    setCopied(true)
    setTimeout(() => setCopied(false), 2000)
  }

  const baseClasses = "px-4 py-2.5 rounded-xl font-medium transition-colors flex items-center justify-center gap-2 text-sm"
  const classes = primary
    ? `${baseClasses} flex-1 md:flex-none bg-[#FC5931] hover:bg-[#D42F1D] text-white shadow-sm`
    : `${baseClasses} flex-1 md:flex-none bg-gray-50 hover:bg-gray-100 text-gray-700 border border-gray-200`

  return (
    <button onClick={handleCopy} className={classes}>
      {copied ? <Check size={16} /> : <Copy size={16} />}
      {copied ? 'Copiado!' : label}
    </button>
  )
}
