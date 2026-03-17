import { redirect } from 'next/navigation'

// Redirect old /condo/historico-encomendas to /condo/encomendas-admin
export default function HistoricoEncomendasRedirect() {
  redirect('/condo/encomendas-admin')
}
