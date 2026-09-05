import { Metadata } from 'next'
import WhatsappTemplatesClient from './whatsapp-templates-client'

export const metadata: Metadata = {
  title: 'WhatsApp Templates | Admin | Condomeet',
  description: 'Gerenciamento de Templates Oficiais do WhatsApp',
}

export default function WhatsappTemplatesPage() {
  return (
    <div className="container mx-auto p-6 max-w-7xl">
      <WhatsappTemplatesClient />
    </div>
  )
}
