import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:condomeet/core/design_system/design_system.dart';
import 'package:condomeet/features/auth/presentation/bloc/auth_bloc.dart';

// ── Constants ─────────────────────────────────────────────────────────────────

const _especialidades = [
  'Advocacia', 'Agronomia', 'Arquitetura', 'Chaveiro', 'Dedetização',
  'Eletricista', 'Encanador', 'Estética', 'Fisioterapeuta', 'Jardinagem',
  'Marceneiro', 'Mecânico', 'Médico', 'Nutricionista', 'Pedreiro',
  'Personal Trainer', 'Pintor', 'Psicólogo', 'Serralheiro',
  'TI / Informática', 'Outros',
];

const _especialidadeEmoji = {
  'Advocacia': '⚖️', 'Agronomia': '🌱', 'Arquitetura': '🏛️',
  'Chaveiro': '🔑', 'Dedetização': '🪲', 'Eletricista': '⚡',
  'Encanador': '🔧', 'Estética': '💅', 'Fisioterapeuta': '🦴',
  'Jardinagem': '🌿', 'Marceneiro': '🪵', 'Mecânico': '🔩',
  'Médico': '🩺', 'Nutricionista': '🥗', 'Pedreiro': '🧱',
  'Personal Trainer': '🏋️', 'Pintor': '🎨', 'Psicólogo': '🧠',
  'Serralheiro': '⛓️', 'TI / Informática': '💻', 'Outros': '🌟',
};

// ── UF & Cidades ──────────────────────────────────────────────────────────────

/// All Brazilian states sorted alphabetically by abbreviation
const _kUFs = [
  'AC', 'AL', 'AM', 'AP', 'BA', 'CE', 'DF', 'ES', 'GO',
  'MA', 'MG', 'MS', 'MT', 'PA', 'PB', 'PE', 'PI', 'PR',
  'RJ', 'RN', 'RO', 'RR', 'RS', 'SC', 'SE', 'SP', 'TO',
];

/// Cities per UF sorted from most populous to least populous (top-20 per state)
const _kCidadesPorUF = <String, List<String>>{
  'AC': ['Rio Branco', 'Cruzeiro do Sul', 'Sena Madureira', 'Tarauacá', 'Feijó', 'Brasileia', 'Epitaciolândia', 'Mâncio Lima', 'Rodrigues Alves', 'Placas'],
  'AL': ['Maceió', 'Arapiraca', 'Palmeira dos Índios', 'Rio Largo', 'Penedo', 'União dos Palmares', 'São Miguel dos Campos', 'Santana do Ipanema', 'Marechal Deodoro', 'Coruripe'],
  'AM': ['Manaus', 'Parintins', 'Itacoatiara', 'Manacapuru', 'Coari', 'Tefé', 'Maués', 'Tabatinga', 'Santarém (Tefé)', 'Iranduba'],
  'AP': ['Macapá', 'Santana', 'Laranjal do Jari', 'Oiapoque', 'Mazagão', 'Porto Grande', 'Tartarugalzinho', 'Amapá', 'Pedra Branca do Amapari', 'Calçoene'],
  'BA': ['Salvador', 'Feira de Santana', 'Vitória da Conquista', 'Camaçari', 'Juazeiro', 'Itabuna', 'Ilhéus', 'Lauro de Freitas', 'Jequié', 'Barreiras', 'Alagoinhas', 'Porto Seguro', 'Simões Filho', 'Paulo Afonso', 'Eunápolis', 'Santo Antônio de Jesus', 'Teixeira de Freitas', 'Jacobina', 'Senhor do Bonfim', 'Serrinha'],
  'CE': ['Fortaleza', 'Caucaia', 'Juazeiro do Norte', 'Maracanaú', 'Sobral', 'Crato', 'Itapipoca', 'Maranguape', 'Iguatu', 'Quixadá', 'Pacatuba', 'Crateús', 'Canindé', 'Russas', 'Cascavel', 'Aquiraz', 'Horizonte', 'Tianguá', 'Camocim', 'Limoeiro do Norte'],
  'DF': ['Brasília', 'Ceilândia', 'Taguatinga', 'Samambaia', 'Planaltina', 'Águas Claras', 'Gama', 'Sobradinho', 'Guará', 'Recanto das Emas'],
  'ES': ['Vitória', 'Serra', 'Cariacica', 'Vila Velha', 'Cachoeiro de Itapemirim', 'Linhares', 'São Mateus', 'Colatina', 'Guarapari', 'Aracruz'],
  'GO': ['Goiânia', 'Aparecida de Goiânia', 'Anápolis', 'Rio Verde', 'Luziânia', 'Águas Lindas de Goiás', 'Valparaíso de Goiás', 'Trindade', 'Formosa', 'Novo Gama', 'Catalão', 'Jataí', 'Senador Canedo', 'Itumbiara', 'Caldas Novas'],
  'MA': ['São Luís', 'Imperatriz', 'Timon', 'Caxias', 'Codó', 'Paço do Lumiar', 'Açailândia', 'Bacabal', 'Balsas', 'Santa Inês'],
  'MG': ['Belo Horizonte', 'Uberlândia', 'Contagem', 'Juiz de Fora', 'Betim', 'Montes Claros', 'Ribeirão das Neves', 'Uberaba', 'Governador Valadares', 'Ipatinga', 'Sete Lagoas', 'Divinópolis', 'Santa Luzia', 'Poços de Caldas', 'Patos de Minas', 'Coronel Fabriciano', 'Ubá', 'Varginha', 'Itabira', 'Conselheiro Lafaiete'],
  'MS': ['Campo Grande', 'Dourados', 'Três Lagoas', 'Corumbá', 'Ponta Porã', 'Naviraí', 'Nova Andradina', 'Aquidauana', 'Sidrolândia', 'Paranaíba'],
  'MT': ['Cuiabá', 'Várzea Grande', 'Rondonópolis', 'Sinop', 'Tangará da Serra', 'Cáceres', 'Sorriso', 'Lucas do Rio Verde', 'Primavera do Leste', 'Barra do Garças'],
  'PA': ['Belém', 'Ananindeua', 'Santarém', 'Marabá', 'Parauapebas', 'Castanhal', 'Abaetetuba', 'Cametá', 'Bragança', 'Altamira', 'Marituba', 'Tailândia', 'Redenção', 'Tucuruí', 'Capanema'],
  'PB': ['João Pessoa', 'Campina Grande', 'Santa Rita', 'Patos', 'Bayeux', 'Sousa', 'Cajazeiras', 'Cabedelo', 'Guarabira', 'Mamanguape'],
  'PE': ['Recife', 'Caruaru', 'Olinda', 'Petrolina', 'Paulista', 'Cabo de Santo Agostinho', 'Camaçari', 'Jaboatão dos Guararapes', 'Santa Cruz do Capibaribe', 'Vitória de Santo Antão', 'Garanhuns', 'Ipojuca', 'Igarassu', 'Araripina', 'São Lourenço da Mata'],
  'PI': ['Teresina', 'Parnaíba', 'Picos', 'Piripiri', 'Floriano', 'Campo Maior', 'Barras', 'Caxias (divisa)', 'União', 'Altos'],
  'PR': ['Curitiba', 'Londrina', 'Maringá', 'Ponta Grossa', 'Cascavel', 'São José dos Pinhais', 'Foz do Iguaçu', 'Colombo', 'Guarapuava', 'Paranaguá', 'Araucária', 'Toledo', 'Apucarana', 'Pinhais', 'Campo Largo', 'Almirante Tamandaré', 'Umuarama', 'Piraquara', 'Sarandi', 'Fazenda Rio Grande'],
  'RJ': ['Rio de Janeiro', 'São Gonçalo', 'Duque de Caxias', 'Nova Iguaçu', 'Belford Roxo', 'Niterói', 'São João de Meriti', 'Campos dos Goytacazes', 'Petrópolis', 'Volta Redonda', 'Magé', 'Mesquita', 'Itaboraí', 'Nova Friburgo', 'Barra Mansa', 'Angra dos Reis', 'Nilópolis', 'Macaé', 'Cabo Frio', 'Queimados'],
  'RN': ['Natal', 'Mossoró', 'Parnamirim', 'São Gonçalo do Amarante', 'Macaíba', 'Ceará-Mirim', 'Caicó', 'Currais Novos', 'Açu', 'Santa Cruz'],
  'RO': ['Porto Velho', 'Ji-Paraná', 'Ariquemes', 'Vilhena', 'Cacoal', 'Rolim de Moura', 'Guajará-Mirim', 'Jaru', 'Ouro Preto do Oeste', 'Buritis'],
  'RR': ['Boa Vista', 'Rorainópolis', 'Caracaraí', 'Alto Alegre', 'Mucajaí', 'Cantá', 'Bonfim', 'Pacaraima', 'Amajari', 'Iracema'],
  'RS': ['Porto Alegre', 'Caxias do Sul', 'Pelotas', 'Canoas', 'Santa Maria', 'Gravataí', 'Viamão', 'Novo Hamburgo', 'São Leopoldo', 'Rio Grande', 'Alvorada', 'Passo Fundo', 'Sapucaia do Sul', 'Uruguaiana', 'Santa Cruz do Sul', 'Cachoeirinha', 'Bagé', 'Bento Gonçalves', 'Erechim', 'Sapiranga'],
  'SC': ['Joinville', 'Florianópolis', 'Blumenau', 'São José', 'Criciúma', 'Chapecó', 'Itajaí', 'Lages', 'Jaraguá do Sul', 'Palhoça', 'Balneário Camboriú', 'Brusque', 'Tubarão', 'São Bento do Sul', 'Caçador'],
  'SE': ['Aracaju', 'Nossa Senhora do Socorro', 'Lagarto', 'Itabaiana', 'São Cristóvão', 'Estância', 'Nossa Senhora da Glória', 'Tobias Barreto', 'Simão Dias', 'Itabaianinha'],
  'SP': ['São Paulo', 'Guarulhos', 'Campinas', 'São Bernardo do Campo', 'Santo André', 'São José dos Campos', 'Ribeirão Preto', 'Osasco', 'Sorocaba', 'Mauá', 'São José do Rio Preto', 'Mogi das Cruzes', 'Santos', 'Diadema', 'Jundiaí', 'Piracicaba', 'Carapicuíba', 'Bauru', 'Itaquaquecetuba', 'São Vicente', 'Franca', 'Guarujá', 'Taubaté', 'Limeira', 'Suzano', 'Taboão da Serra', 'Praia Grande', 'Barueri', 'Sumaré', 'Caçapava'],
  'TO': ['Palmas', 'Araguaína', 'Gurupi', 'Porto Nacional', 'Paraíso do Tocantins', 'Colinas do Tocantins', 'Guaraí', 'Tocantinópolis', 'Miracema do Tocantins', 'Dianópolis'],
};

// ── Screen ────────────────────────────────────────────────────────────────────

class IndicacoesScreen extends StatefulWidget {
  const IndicacoesScreen({super.key});

  @override
  State<IndicacoesScreen> createState() => _IndicacoesScreenState();
}

class _IndicacoesScreenState extends State<IndicacoesScreen> {
  final _supabase = Supabase.instance.client;

  List<Map<String, dynamic>> _indicacoes = [];
  List<Map<String, dynamic>> _avaliacoes = [];
  bool _loading = true;
  String _userId = '';
  String _condoId = '';

  // Filter
  String _filterEsp = '';
  String _filterSearch = '';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final authState = context.read<AuthBloc>().state;
    _userId = authState.userId ?? '';
    _condoId = authState.condominiumId ?? '';

    if (_condoId.isEmpty) { setState(() => _loading = false); return; }

    final indRes = await _supabase
        .from('indicacoes_servico')
        .select('*')
        .eq('condominio_id', _condoId)
        .order('created_at', ascending: false);

    // Fetch creator names separately
    final ids2 = (indRes as List).map((i) => i['criado_por'] as String).toSet().toList();
    Map<String, String> criadorMap = {};
    if (ids2.isNotEmpty) {
      final criRes = await _supabase.from('perfil').select('id, nome_completo').inFilter('id', ids2);
      criadorMap = { for (final c in (criRes as List)) c['id'] as String: c['nome_completo'] as String? ?? 'Morador' };
    }
    final indResWithCriador = (indRes).map((i) => {
      ...Map<String, dynamic>.from(i as Map),
      'criador': {'nome_completo': criadorMap[i['criado_por']] ?? 'Morador'},
    }).toList();

    final ids = indResWithCriador.map((i) => i['id'] as String).toList();
    List<Map<String, dynamic>> avs = [];
    if (ids.isNotEmpty) {
      final avsRes = await _supabase
          .from('indicacoes_avaliacoes')
          .select('*')
          .inFilter('indicacao_id', ids);
      avs = List<Map<String, dynamic>>.from(avsRes);
    }

    if (mounted) {
      setState(() {
        _indicacoes = List<Map<String, dynamic>>.from(indResWithCriador);
        _avaliacoes = avs;
        _loading = false;
      });
    }
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  double? _avgRating(String id) {
    final avs = _avaliacoes.where((a) => a['indicacao_id'] == id).toList();
    if (avs.isEmpty) return null;
    return avs.map((a) => (a['nota'] as int).toDouble()).reduce((a, b) => a + b) / avs.length;
  }

  int _countRatings(String id) =>
      _avaliacoes.where((a) => a['indicacao_id'] == id).length;

  int? _myRating(String id) {
    final av = _avaliacoes.where((a) => a['indicacao_id'] == id && a['usuario_id'] == _userId).firstOrNull;
    return av?['nota'] as int?;
  }

  String? _myComment(String id) {
    final av = _avaliacoes.where((a) => a['indicacao_id'] == id && a['usuario_id'] == _userId).firstOrNull;
    return av?['comentario'] as String?;
  }

  void _openWhatsApp(String phone) {
    final cleaned = phone.replaceAll(RegExp(r'\D'), '');
    final num = cleaned.startsWith('55') ? cleaned : '55$cleaned';
    launchUrl(Uri.parse('https://wa.me/$num'), mode: LaunchMode.externalApplication);
  }

  List<Map<String, dynamic>> get _filtered {
    return _indicacoes.where((i) {
      final matchEsp = _filterEsp.isEmpty || i['especialidade'] == _filterEsp;
      final matchSearch = _filterSearch.isEmpty ||
          (i['nome'] as String).toLowerCase().contains(_filterSearch.toLowerCase());
      return matchEsp && matchSearch;
    }).toList();
  }

  // ── Rating Modal ──────────────────────────────────────────────────────────

  void _openRatingModal(Map<String, dynamic> ind) {
    final id = ind['id'] as String;
    int stars = _myRating(id) ?? 0;
    String comment = _myComment(id) ?? '';
    bool loading = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.only(
            left: 24, right: 24, top: 24,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Expanded(
                    child: Text(
                      ind['nome'] as String,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(ctx),
                    icon: const Icon(Icons.close),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '${_especialidadeEmoji[ind['especialidade']] ?? '🌟'} ${ind['especialidade']}',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
              ),
              const SizedBox(height: 20),
              // Stars
              const Text('Sua avaliação', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 10),
              Row(
                children: List.generate(5, (i) => GestureDetector(
                  onTap: () => setModalState(() => stars = i + 1),
                  child: Icon(
                    stars > i ? Icons.star_rounded : Icons.star_border_rounded,
                    color: stars > i ? Colors.amber : Colors.grey.shade300,
                    size: 36,
                  ),
                )),
              ),
              const SizedBox(height: 16),
              // Comment
              TextField(
                controller: TextEditingController(text: comment),
                onChanged: (v) => comment = v,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: 'Opcional: Escreva aqui seu comentário.',
                  hintStyle: TextStyle(color: Colors.grey.shade400),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade200),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.primary),
                  ),
                  contentPadding: const EdgeInsets.all(14),
                ),
              ),
              const SizedBox(height: 20),
              // Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: stars == 0 || loading ? null : () async {
                    setModalState(() => loading = true);
                    await _supabase.from('indicacoes_avaliacoes').upsert({
                      'indicacao_id': id,
                      'usuario_id': _userId,
                      'nota': stars,
                      'comentario': comment.trim().isEmpty ? null : comment.trim(),
                    }, onConflict: 'indicacao_id,usuario_id');
                    if (mounted) {
                      Navigator.pop(ctx);
                      await _loadData();
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  child: loading
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Avaliar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── New Indicação Bottom Sheet ─────────────────────────────────────────────

  void _openNewIndicacao() {
    String nome = '', whatsapp = '', uf = '', cidade = '', obs = '', esp = '';
    String? selectedUf;
    String? selectedCidade;
    String espSearch = '';
    File? fotoFile;
    String? fotoPreview;
    bool loading = false;
    String? error;
    bool showEspList = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final filteredEsps = _especialidades
              .where((e) => e.toLowerCase().contains(espSearch.toLowerCase()))
              .toList();

          return Padding(
            padding: EdgeInsets.only(
              left: 20, right: 20, top: 20,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    children: [
                      const Expanded(
                        child: Text('Nova Indicação',
                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(ctx),
                        icon: const Icon(Icons.close),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Foto
                  Center(
                    child: GestureDetector(
                      onTap: () async {
                        final img = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 80);
                        if (img != null) {
                          setModalState(() {
                            fotoFile = File(img.path);
                            fotoPreview = img.path;
                          });
                        }
                      },
                      child: Container(
                        width: 80, height: 80,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.grey.shade300, style: BorderStyle.solid),
                        ),
                        child: fotoPreview != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(15),
                                child: Image.file(File(fotoPreview!), fit: BoxFit.cover),
                              )
                            : Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.camera_alt_outlined, color: Colors.grey.shade400, size: 28),
                                  const SizedBox(height: 4),
                                  Text('Foto', style: TextStyle(fontSize: 11, color: Colors.grey.shade400)),
                                ],
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Nome
                  _buildField('Nome do profissional / Loja *', onChanged: (v) => nome = v),
                  const SizedBox(height: 12),

                  // WhatsApp
                  _buildField('WhatsApp (para vizinhos contatarem)',
                    keyboardType: TextInputType.phone,
                    hint: '(XX) 9 9999-9999',
                    onChanged: (v) => whatsapp = v,
                  ),
                  const SizedBox(height: 12),

                  // UF + Cidade (cascading dropdowns)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      SizedBox(
                        width: 88,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('UF', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                            const SizedBox(height: 6),
                            DropdownButtonFormField<String>(
                              value: selectedUf,
                              isDense: true,
                              isExpanded: true,
                              hint: const Text('UF', style: TextStyle(fontSize: 13)),
                              decoration: InputDecoration(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: Colors.grey.shade200),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(color: AppColors.primary),
                                ),
                                isDense: true,
                              ),
                              items: _kUFs.map((u) => DropdownMenuItem(value: u, child: Text(u, style: const TextStyle(fontSize: 13)))).toList(),
                              onChanged: (v) => setModalState(() {
                                selectedUf = v;
                                uf = v ?? '';
                                selectedCidade = null;
                                cidade = '';
                              }),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Cidade', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                            const SizedBox(height: 6),
                            DropdownButtonFormField<String>(
                              value: selectedCidade,
                              isDense: true,
                              isExpanded: true,
                              hint: Text(
                                selectedUf == null ? 'Selecione UF' : 'Cidade',
                                style: const TextStyle(fontSize: 13),
                              ),
                              decoration: InputDecoration(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: Colors.grey.shade200),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(color: AppColors.primary),
                                ),
                                isDense: true,
                              ),
                              items: selectedUf == null
                                  ? []
                                  : (_kCidadesPorUF[selectedUf] ?? []).map((c) =>
                                      DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 13)))).toList(),
                              onChanged: selectedUf == null ? null : (v) => setModalState(() {
                                selectedCidade = v;
                                cidade = v ?? '';
                              }),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Especialidade typeahead
                  const Text('Especialidade *', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  const SizedBox(height: 6),
                  TextField(
                    onChanged: (v) => setModalState(() { espSearch = v; esp = ''; showEspList = true; }),
                    onTap: () => setModalState(() => showEspList = true),
                    controller: TextEditingController(text: esp.isNotEmpty ? esp : espSearch),
                    decoration: InputDecoration(
                      hintText: 'Buscar especialidade...',
                      hintStyle: TextStyle(color: Colors.grey.shade400),
                      prefixIcon: const Icon(Icons.search, size: 18),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade200),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.primary),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      isDense: true,
                    ),
                  ),
                  if (showEspList && filteredEsps.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade200),
                        borderRadius: BorderRadius.circular(12),
                        color: Colors.white,
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 8)],
                      ),
                      constraints: const BoxConstraints(maxHeight: 160),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: filteredEsps.length,
                        itemBuilder: (_, i) {
                          final e = filteredEsps[i];
                          return ListTile(
                            dense: true,
                            leading: Text(_especialidadeEmoji[e] ?? '🌟', style: const TextStyle(fontSize: 18)),
                            title: Text(e, style: const TextStyle(fontSize: 13)),
                            selected: esp == e,
                            selectedColor: AppColors.primary,
                            onTap: () => setModalState(() { esp = e; espSearch = e; showEspList = false; }),
                          );
                        },
                      ),
                    ),
                  const SizedBox(height: 12),

                  // Observações
                  const Text('Observações', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  const SizedBox(height: 6),
                  TextField(
                    onChanged: (v) => obs = v,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: 'Conte sua experiência com este profissional...',
                      hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade200),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.primary),
                      ),
                      contentPadding: const EdgeInsets.all(14),
                    ),
                  ),

                  if (error != null) ...[
                    const SizedBox(height: 10),
                    Text(error!, style: const TextStyle(color: Colors.red, fontSize: 13)),
                  ],

                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: loading ? null : () async {
                        if (nome.trim().isEmpty) {
                          setModalState(() => error = 'Informe o nome do profissional.');
                          return;
                        }
                        if (esp.isEmpty) {
                          setModalState(() => error = 'Selecione a especialidade.');
                          return;
                        }
                        setModalState(() { loading = true; error = null; });

                        String? fotoUrl;
                        if (fotoFile != null) {
                          final ext = fotoFile!.path.split('.').last;
                          final path = 'indicacoes/$_condoId/${DateTime.now().millisecondsSinceEpoch}.$ext';
                          final uploadRes = await _supabase.storage.from('community').upload(path, fotoFile!);
                          if (!uploadRes.contains('error')) {
                            fotoUrl = _supabase.storage.from('community').getPublicUrl(path);
                          }
                        }

                        final inserted = await _supabase
                            .from('indicacoes_servico')
                            .insert({
                              'condominio_id': _condoId,
                              'criado_por': _userId,
                              'nome': nome.trim(),
                              'whatsapp': whatsapp.trim().isEmpty ? null : whatsapp.trim(),
                              'especialidade': esp,
                              'uf': uf.trim().isEmpty ? null : uf.trim(),
                              'cidade': cidade.trim().isEmpty ? null : cidade.trim(),
                              'observacoes': obs.trim().isEmpty ? null : obs.trim(),
                              'foto_url': fotoUrl,
                            })
                            .select('id')
                            .single();

                        // Fire push notification
                        try {
                          await _supabase.functions.invoke('indicacoes-notify', body: {
                            'condominio_id': _condoId,
                            'indicacao_id': inserted['id'],
                          });
                        } catch (_) {}

                        if (mounted) {
                          Navigator.pop(ctx);
                          await _loadData();
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                      child: loading
                          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Text('🌟 Publicar Indicação',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildField(String label, {
    String? hint,
    int? maxLength,
    TextInputType? keyboardType,
    required void Function(String) onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        const SizedBox(height: 6),
        TextField(
          onChanged: onChanged,
          maxLength: maxLength,
          keyboardType: keyboardType,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
            counterText: '',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade200),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.primary),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            isDense: true,
          ),
        ),
      ],
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        title: const Text('Indicações de Serviço'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        actions: [
          // Filter by especialidade
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list),
            tooltip: 'Filtrar por especialidade',
            onSelected: (v) => setState(() => _filterEsp = v == '__all__' ? '' : v),
            itemBuilder: (ctx) => [
              const PopupMenuItem(value: '__all__', child: Text('Todas')),
              ..._especialidades.map((e) => PopupMenuItem(
                    value: e,
                    child: Text('${_especialidadeEmoji[e] ?? ''} $e'),
                  )),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openNewIndicacao,
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Indicar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: Column(
        children: [
          // Search bar
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: TextField(
              onChanged: (v) => setState(() => _filterSearch = v),
              decoration: InputDecoration(
                hintText: 'Buscar por nome...',
                hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                prefixIcon: const Icon(Icons.search, size: 18),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade200),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.primary),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                isDense: true,
              ),
            ),
          ),
          if (_filterEsp.isNotEmpty)
            Container(
              color: Colors.white,
              padding: const EdgeInsets.only(left: 16, bottom: 10),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('${_especialidadeEmoji[_filterEsp] ?? ''} $_filterEsp',
                            style: const TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w600)),
                        const SizedBox(width: 6),
                        GestureDetector(
                          onTap: () => setState(() => _filterEsp = ''),
                          child: const Icon(Icons.close, size: 14, color: AppColors.primary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          // Content
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                : _filtered.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text('🌟', style: TextStyle(fontSize: 48)),
                            const SizedBox(height: 12),
                            const Text('Nenhuma indicação ainda',
                                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black54)),
                            const SizedBox(height: 4),
                            Text('Seja o primeiro a indicar!',
                                style: TextStyle(color: Colors.grey.shade400, fontSize: 13)),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _filtered.length,
                        itemBuilder: (ctx, i) => _buildCard(_filtered[i]),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(Map<String, dynamic> ind) {
    final id = ind['id'] as String;
    final nome = ind['nome'] as String;
    final esp = ind['especialidade'] as String;
    final emoji = _especialidadeEmoji[esp] ?? '🌟';
    final whatsapp = ind['whatsapp'] as String?;
    final uf = ind['uf'] as String?;
    final cidade = ind['cidade'] as String?;
    final obs = ind['observacoes'] as String?;
    final fotoUrl = ind['foto_url'] as String?;
    final criador = (ind['criador'] as Map?)?['nome_completo'] as String? ?? 'Morador';

    final avg = _avgRating(id);
    final cnt = _countRatings(id);
    final myNote = _myRating(id) ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 10, offset: const Offset(0, 3)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top row: photo + info + WA
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Photo
                Container(
                  width: 60, height: 60,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: fotoUrl != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(15),
                          child: Image.network(fotoUrl, fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Center(child: Text(emoji, style: const TextStyle(fontSize: 28)))),
                        )
                      : Center(child: Text(emoji, style: const TextStyle(fontSize: 28))),
                ),
                const SizedBox(width: 12),
                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(nome, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text('$emoji $esp',
                            style: const TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.w600)),
                      ),
                      if (uf != null || cidade != null) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.location_on_outlined, size: 12, color: Colors.grey.shade400),
                            const SizedBox(width: 3),
                            Text(
                              [if (uf != null) uf, if (cidade != null) cidade].join(' / '),
                              style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                // WhatsApp button
                if (whatsapp != null && whatsapp.isNotEmpty)
                  GestureDetector(
                    onTap: () => _openWhatsApp(whatsapp),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF25D366),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.chat_rounded, color: Colors.white, size: 14),
                          SizedBox(width: 4),
                          Text('WA', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11)),
                        ],
                      ),
                    ),
                  ),
              ],
            ),

            if (obs != null && obs.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(obs, style: TextStyle(fontSize: 12, color: Colors.grey.shade600), maxLines: 2, overflow: TextOverflow.ellipsis),
            ],

            // Quem indicou
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.person_outline, size: 12, color: Colors.grey.shade400),
                const SizedBox(width: 4),
                Text('Indicado por ', style: TextStyle(fontSize: 11, color: Colors.grey.shade400)),
                Text(criador, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.black54)),
              ],
            ),

            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),

            // Ratings row
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // My rating
                      Row(
                        children: [
                          Text('Minha: ', style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                          ...List.generate(5, (i) => Icon(
                            myNote > i ? Icons.star_rounded : Icons.star_border_rounded,
                            size: 14,
                            color: myNote > i ? Colors.amber : Colors.grey.shade300,
                          )),
                        ],
                      ),
                      const SizedBox(height: 2),
                      // Average
                      Row(
                        children: [
                          Text('Geral: ', style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                          ...List.generate(5, (i) {
                            final filled = avg != null && avg > i;
                            return Icon(
                              filled ? Icons.star_rounded : Icons.star_border_rounded,
                              size: 14,
                              color: filled ? Colors.amber : Colors.grey.shade300,
                            );
                          }),
                          if (avg != null)
                            Text(' ${avg.toStringAsFixed(1)} ($cnt)',
                                style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                          if (avg == null)
                            Text(' (0)', style: TextStyle(fontSize: 11, color: Colors.grey.shade400)),
                        ],
                      ),
                    ],
                  ),
                ),
                // Avaliar button
                OutlinedButton(
                  onPressed: () => _openRatingModal(ind),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.primary),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    myNote > 0 ? 'Reavaliar' : 'Avaliar',
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
