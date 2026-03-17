import { redirect } from 'next/navigation'

// Redirect old /condo/historico-encomendas to Minhas Encomendas
export default function HistoricoEncomendasRedirect() {
  redirect('/condo/encomendas')
}
