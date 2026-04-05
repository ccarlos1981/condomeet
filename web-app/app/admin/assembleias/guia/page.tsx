import Link from 'next/link';
import { 
  BookOpen, 
  Settings, 
  PlusCircle, 
  Gavel, 
  PlayCircle,
  FileText,
  CheckCircle2,
  AlertCircle
} from 'lucide-react';

export default function GuiaAssembleiasPage() {
  const passos = [
    {
      icon: <Settings className="text-blue-500 w-8 h-8" />,
      titulo: 'Passo 1: Configurar Unidades Participantes',
      descricao: 'Antes de realizar uma assembleia, precisamos dizer ao sistema quem pode votar. Por padrão, todas as unidades já estão cadastradas.',
      dicas: [
        'Acesse a página "Configurações" no menu lateral.',
        'Se o morador não puder votar (ex: está inadimplente e a regra do condomínio não permite), você deve desativar o acesso dele a voto.',
        'O morador bloqueado ainda poderá assistir à assembleia virtual, mas os botões de votação não aparecerão para ele.'
      ],
      cor: 'bg-blue-50 border-blue-200'
    },
    {
      icon: <PlusCircle className="text-emerald-500 w-8 h-8" />,
      titulo: 'Passo 2: Criar a Assembleia e suas Pautas',
      descricao: 'Agora vamos agendar a assembleia de fato e definir os assuntos (Pautas) que serão votados ou discutidos.',
      dicas: [
        'Acesse a página "Nova Assembleia" no menu.',
        'Preencha informações básicas: Título, Data, Link da videochamada.',
        'Crie as Pautas. Escolha entre "Votação" (para as pessoas escolherem Sim/Não ou outras opções criadas por você) ou "Informativa" (apenas para discutir um tema).',
        'Foque em opções claras nas pautas de votação para não confundir os condôminos.'
      ],
      cor: 'bg-emerald-50 border-emerald-200'
    },
    {
      icon: <Gavel className="text-orange-500 w-8 h-8" />,
      titulo: 'Passo 3: Acompanhar Assembleia Agendada',
      descricao: 'A assembleia vai ficar com o status "Agendada". Você e os moradores poderão ver a contagem regressiva.',
      dicas: [
        'Na página "Assembleias", você verá a lista de todas as assembleias criadas.',
        'Ao clicar na assembleia agendada, você acessa o Painel.',
        'Enquanto ela estiver fechada, os votos não ficam abertos, servindo como uma "visão prévia" do que ocorrerá.'
      ],
      cor: 'bg-orange-50 border-orange-200'
    },
    {
      icon: <PlayCircle className="text-indigo-500 w-8 h-8" />,
      titulo: 'Passo 4: O Momento da Assembleia (Ao Vivo)',
      descricao: 'Chegou o dia e horário! Você deve comandar a transmissão.',
      dicas: [
        'Acesse o painel da assembleia. Você terá controle de "Iniciar Assembleia".',
        'Os votos serão liberados automaticamente quando a assembleia estiver aberta e as pautas ativas.',
        'No Painel de Controle, você pode moderar o chat (apagar mensagens), iniciar gravação, e silenciar moradores.',
        'Dica de ouro: Use o Painel de Engajamento para ver em tempo real quantos estão votando.'
      ],
      cor: 'bg-indigo-50 border-indigo-200'
    },
    {
      icon: <FileText className="text-purple-500 w-8 h-8" />,
      titulo: 'Passo 5: Encerramento e Emissão da Ata',
      descricao: 'A reunião acabou. Como guardo o histórico de decisões e votos?',
      dicas: [
        'Você deve clicar em "Encerrar Assembleia". Ninguém mais poderá votar.',
        'O sistema pode utilizar a gravação para gerar uma Ata Inicial através de Inteligência Artificial.',
        'O painel virará um documento final (Dashboard) com todos os gráficos de aprovação e lista dos votos detalhados por unidade.',
        'Você pode baixar ou Imprimir esses dados e anexar os documentos físicos para oficialização.'
      ],
      cor: 'bg-purple-50 border-purple-200'
    }
  ];

  return (
    <div className="flex-1 w-full p-4 lg:p-8 max-w-5xl mx-auto pb-20">
      
      {/* Header */}
      <div className="mb-8">
        <h1 className="text-3xl font-extrabold text-gray-900 tracking-tight flex items-center gap-3">
          <BookOpen className="text-[#FC5931] w-8 h-8" /> 
          Guia Definitivo de Assembleias
        </h1>
        <p className="text-gray-500 mt-2 text-lg">
          O passo a passo simplificado para conduzir as assembleias do seu condomínio com sucesso e zero dores de cabeça.
        </p>
      </div>

      {/* Introdução Alert */}
      <div className="bg-amber-50 border border-amber-200 shadow-sm rounded-2xl p-5 mb-10 flex gap-4 mt-8">
        <div className="mt-1">
          <AlertCircle className="text-amber-500 w-6 h-6" />
        </div>
        <div>
          <h3 className="font-bold text-amber-800 text-base mb-1">Para Síndicos e Administradores</h3>
          <p className="text-amber-700 text-sm leading-relaxed">
            As assembleias virtuais já são regularizadas por Lei, no entanto as mesmas devem seguir os preceitos do seu regimento interno. O Condomeet digitaliza o processo para você focar no que importa: <strong>decisões.</strong> Nós criamos este manual robusto, direto ao ponto e focado em leigos. Siga o fluxo desenhado abaixo.
          </p>
        </div>
      </div>

      {/* Stepper Vertical */}
      <div className="space-y-6">
        {passos.map((passo, idx) => (
          <div key={idx} className={`relative rounded-3xl border shadow-xs overflow-hidden ${passo.cor} transition-all hover:shadow-md`}>
            {/* Decalque Numérico Invisível */}
            <div className="absolute -right-6 -top-10 text-[180px] font-black opacity-5 select-none pointer-events-none">
              {idx + 1}
            </div>

            <div className="p-6 md:p-8 flex flex-col md:flex-row gap-6 items-start relative z-10">
              <div className="bg-white p-4 rounded-2xl shadow-sm shrink-0 border border-black/5">
                {passo.icon}
              </div>
              
              <div className="flex-1">
                <h2 className="text-xl font-black text-gray-900 mb-2">{passo.titulo}</h2>
                <p className="text-gray-700 font-medium text-sm md:text-base mb-6 leading-relaxed bg-white/50 p-4 rounded-xl">
                  {passo.descricao}
                </p>

                <div className="space-y-3">
                  <h4 className="text-xs uppercase tracking-widest font-bold text-black/40">Como fazer:</h4>
                  {passo.dicas.map((dica, dIdx) => (
                    <div key={dIdx} className="flex gap-3 items-start group">
                      <CheckCircle2 className="w-5 h-5 text-black/20 shrink-0 mt-0.5 group-hover:text-[#FC5931] transition-colors" />
                      <span className="text-gray-800 text-sm leading-relaxed">{dica}</span>
                    </div>
                  ))}
                </div>
              </div>
            </div>
          </div>
        ))}
      </div>

      <div className="mt-12 bg-gray-900 text-white p-8 rounded-3xl text-center shadow-xl">
        <h2 className="text-2xl font-bold mb-4">Pronto para começar?</h2>
        <p className="text-gray-400 mb-6">O sistema Condomeet fará o trabalho pesado por você. Tudo o que você tem a fazer é conduzir e deliberar.</p>
        <div className="flex gap-4 justify-center">
          <Link href="/admin/assembleias/unidades" className="bg-white/10 hover:bg-white/20 text-white font-medium py-3 px-6 rounded-xl transition-colors">
            Revisar Unidades
          </Link>
          <Link href="/admin/assembleias/nova" className="bg-[#FC5931] hover:bg-[#e04f2c] text-white font-medium py-3 px-6 rounded-xl transition-colors shadow-lg shadow-[#FC5931]/20">
            Criar Nova Assembleia
          </Link>
        </div>
      </div>

    </div>
  );
}
