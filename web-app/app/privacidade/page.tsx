import { Metadata } from 'next'

export const metadata: Metadata = {
  title: 'Política de Privacidade | Condomeet',
  description: 'Política de Privacidade do aplicativo Condomeet - seu Condomínio Digital',
}

export default function PrivacidadePage() {
  return (
    <div style={{
      maxWidth: '800px',
      margin: '0 auto',
      padding: '40px 24px',
      fontFamily: 'system-ui, -apple-system, sans-serif',
      color: '#333',
      lineHeight: '1.7',
    }}>
      <div style={{ textAlign: 'center', marginBottom: '40px' }}>
        <h1 style={{ color: '#E53935', fontSize: '28px', marginBottom: '8px' }}>
          Política de Privacidade
        </h1>
        <p style={{ color: '#666', fontSize: '14px' }}>
          Última atualização: 19 de março de 2026
        </p>
      </div>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ color: '#E53935', fontSize: '20px', borderBottom: '2px solid #E53935', paddingBottom: '8px' }}>
          1. Introdução
        </h2>
        <p>
          A <strong>2SCapital</strong> (&quot;nós&quot;, &quot;nosso&quot; ou &quot;empresa&quot;), desenvolvedora do aplicativo
          <strong> Condomeet</strong> (&quot;aplicativo&quot;, &quot;app&quot; ou &quot;plataforma&quot;), está comprometida em
          proteger a privacidade e os dados pessoais de seus usuários. Esta Política de Privacidade
          descreve como coletamos, usamos, armazenamos e protegemos suas informações pessoais quando
          você utiliza nosso aplicativo e serviços.
        </p>
        <p>
          Ao utilizar o Condomeet, você concorda com as práticas descritas nesta Política de Privacidade,
          em conformidade com a Lei Geral de Proteção de Dados Pessoais (LGPD - Lei nº 13.709/2018).
        </p>
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ color: '#E53935', fontSize: '20px', borderBottom: '2px solid #E53935', paddingBottom: '8px' }}>
          2. Dados que Coletamos
        </h2>
        <p>Coletamos os seguintes tipos de dados pessoais:</p>
        <h3 style={{ fontSize: '16px', marginTop: '16px' }}>2.1 Dados de Identificação</h3>
        <ul>
          <li>Nome completo</li>
          <li>Endereço de e-mail</li>
          <li>Número de telefone celular</li>
          <li>CPF (quando necessário para identificação)</li>
        </ul>
        <h3 style={{ fontSize: '16px', marginTop: '16px' }}>2.2 Dados de Residência</h3>
        <ul>
          <li>Condomínio de residência</li>
          <li>Bloco e número do apartamento</li>
          <li>Tipo de vínculo (morador, proprietário, síndico)</li>
        </ul>
        <h3 style={{ fontSize: '16px', marginTop: '16px' }}>2.3 Dados de Uso</h3>
        <ul>
          <li>Registros de acesso ao aplicativo</li>
          <li>Interações com funcionalidades do app</li>
          <li>Token de notificações push (Firebase Cloud Messaging)</li>
        </ul>
        <h3 style={{ fontSize: '16px', marginTop: '16px' }}>2.4 Dados Opcionais</h3>
        <ul>
          <li>Foto de perfil</li>
          <li>Imagens de encomendas (para registro de recebimento)</li>
          <li>Assinatura digital (para confirmação de retirada de encomendas)</li>
        </ul>
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ color: '#E53935', fontSize: '20px', borderBottom: '2px solid #E53935', paddingBottom: '8px' }}>
          3. Como Usamos seus Dados
        </h2>
        <p>Utilizamos seus dados pessoais para as seguintes finalidades:</p>
        <ul>
          <li><strong>Autenticação e Acesso:</strong> Gerenciar sua conta e permitir o acesso seguro ao aplicativo.</li>
          <li><strong>Gestão Condominial:</strong> Facilitar a comunicação entre moradores, síndicos e portaria.</li>
          <li><strong>Encomendas:</strong> Registrar e notificar sobre o recebimento e retirada de encomendas.</li>
          <li><strong>Reservas:</strong> Gerenciar reservas de áreas comuns do condomínio.</li>
          <li><strong>Visitantes:</strong> Controle de acesso e autorização de visitantes.</li>
          <li><strong>Notificações:</strong> Enviar avisos importantes, alertas de encomendas e comunicados do condomínio via push notification e/ou WhatsApp.</li>
          <li><strong>Segurança:</strong> Registrar ocorrências e emergências (SOS).</li>
        </ul>
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ color: '#E53935', fontSize: '20px', borderBottom: '2px solid #E53935', paddingBottom: '8px' }}>
          4. Compartilhamento de Dados
        </h2>
        <p>
          Seus dados pessoais <strong>não são vendidos, alugados ou compartilhados</strong> com terceiros
          para fins comerciais ou de marketing. Os dados são compartilhados apenas:
        </p>
        <ul>
          <li><strong>Com a administração do condomínio:</strong> Síndicos e porteiros têm acesso a dados necessários para a gestão condominial (nome, unidade, telefone).</li>
          <li><strong>Com outros moradores do mesmo condomínio:</strong> Apenas informações limitadas são visíveis, como nome e unidade, para fins de comunicação interna.</li>
          <li><strong>Com prestadores de serviço:</strong> Utilizamos serviços de terceiros para infraestrutura (Supabase para banco de dados, Firebase para notificações push, Vercel para hospedagem web). Estes prestadores estão sujeitos a suas próprias políticas de privacidade e são contratualmente obrigados a proteger seus dados.</li>
        </ul>
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ color: '#E53935', fontSize: '20px', borderBottom: '2px solid #E53935', paddingBottom: '8px' }}>
          5. Armazenamento e Segurança dos Dados
        </h2>
        <p>
          Seus dados são armazenados em servidores seguros com criptografia em trânsito (TLS/SSL) e em repouso.
          Implementamos medidas de segurança técnicas e organizacionais, incluindo:
        </p>
        <ul>
          <li>Criptografia de senhas (hash bcrypt)</li>
          <li>Autenticação segura via tokens JWT</li>
          <li>Políticas de segurança em nível de linha (RLS) no banco de dados</li>
          <li>Controle de acesso baseado em funções (RBAC)</li>
          <li>Armazenamento seguro de credenciais no dispositivo</li>
        </ul>
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ color: '#E53935', fontSize: '20px', borderBottom: '2px solid #E53935', paddingBottom: '8px' }}>
          6. Seus Direitos (LGPD)
        </h2>
        <p>De acordo com a LGPD, você tem os seguintes direitos sobre seus dados pessoais:</p>
        <ul>
          <li><strong>Acesso:</strong> Solicitar informações sobre quais dados pessoais temos sobre você.</li>
          <li><strong>Correção:</strong> Solicitar a correção de dados incompletos, inexatos ou desatualizados.</li>
          <li><strong>Eliminação:</strong> Solicitar a exclusão de seus dados pessoais.</li>
          <li><strong>Portabilidade:</strong> Solicitar a transferência de seus dados para outro fornecedor.</li>
          <li><strong>Revogação do consentimento:</strong> Retirar seu consentimento a qualquer momento.</li>
          <li><strong>Oposição:</strong> Se opor ao tratamento de dados quando realizado com base em hipóteses legais.</li>
        </ul>
        <p>
          Para exercer qualquer um desses direitos, entre em contato conosco através do e-mail
          indicado na seção de Contato.
        </p>
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ color: '#E53935', fontSize: '20px', borderBottom: '2px solid #E53935', paddingBottom: '8px' }}>
          7. Permissões do Aplicativo
        </h2>
        <p>O aplicativo pode solicitar as seguintes permissões no seu dispositivo:</p>
        <ul>
          <li><strong>Câmera:</strong> Para tirar fotos de encomendas e documentos.</li>
          <li><strong>Notificações:</strong> Para enviar alertas sobre encomendas, avisos e emergências.</li>
          <li><strong>Biometria:</strong> Para autenticação segura via impressão digital ou reconhecimento facial (opcional).</li>
          <li><strong>Armazenamento:</strong> Para salvar e compartilhar documentos e imagens.</li>
        </ul>
        <p>
          Todas as permissões são solicitadas apenas quando necessárias e podem ser revogadas
          a qualquer momento nas configurações do seu dispositivo.
        </p>
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ color: '#E53935', fontSize: '20px', borderBottom: '2px solid #E53935', paddingBottom: '8px' }}>
          8. Retenção de Dados
        </h2>
        <p>
          Seus dados pessoais são retidos enquanto sua conta estiver ativa ou conforme necessário para
          cumprir obrigações legais. Ao solicitar a exclusão de sua conta, seus dados serão removidos
          em até 30 dias, exceto quando houver obrigação legal de retenção.
        </p>
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ color: '#E53935', fontSize: '20px', borderBottom: '2px solid #E53935', paddingBottom: '8px' }}>
          9. Menores de Idade
        </h2>
        <p>
          O Condomeet não é direcionado a menores de 18 anos. Não coletamos intencionalmente dados
          pessoais de crianças ou adolescentes. Se tomarmos conhecimento de que coletamos dados de
          um menor sem o consentimento dos pais ou responsáveis, tomaremos medidas para excluir
          essas informações.
        </p>
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ color: '#E53935', fontSize: '20px', borderBottom: '2px solid #E53935', paddingBottom: '8px' }}>
          10. Alterações nesta Política
        </h2>
        <p>
          Podemos atualizar esta Política de Privacidade periodicamente. Quando fizermos alterações
          significativas, notificaremos você através do aplicativo ou por e-mail. Recomendamos que
          você revise esta política regularmente.
        </p>
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ color: '#E53935', fontSize: '20px', borderBottom: '2px solid #E53935', paddingBottom: '8px' }}>
          11. Contato
        </h2>
        <p>
          Para dúvidas, solicitações ou reclamações relacionadas a esta Política de Privacidade
          ou ao tratamento de seus dados pessoais, entre em contato:
        </p>
        <ul style={{ listStyle: 'none', padding: 0 }}>
          <li><strong>Empresa:</strong> 2SCapital</li>
          <li><strong>E-mail:</strong> contato@condomeet.app.br</li>
          <li><strong>Aplicativo:</strong> Condomeet - seu Condomínio Digital</li>
        </ul>
      </section>

      <footer style={{
        borderTop: '1px solid #eee',
        paddingTop: '24px',
        textAlign: 'center',
        color: '#999',
        fontSize: '13px',
      }}>
        <p>© 2026 2SCapital. Todos os direitos reservados.</p>
        <p>Condomeet - seu Condomínio Digital</p>
      </footer>
    </div>
  )
}
