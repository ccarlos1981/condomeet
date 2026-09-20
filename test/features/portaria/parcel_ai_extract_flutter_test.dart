import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:condomeet/core/errors/result.dart';
import 'package:condomeet/features/portaria/domain/entities/parcel.dart';
import 'package:condomeet/features/portaria/domain/repositories/parcel_repository.dart';
import 'package:condomeet/features/portaria/domain/services/parcel_address_normalizer.dart';

// ── Mock Parcel Repository for Contract Verification ────────────────────────

class _TestParcelRepository implements ParcelRepository {
  final List<Parcel> registeredParcels = [];

  @override
  Future<Result<void>> registerParcel(Parcel parcel) async {
    registeredParcels.add(parcel);
    return const Success(null);
  }

  @override
  Future<Result<List<Parcel>>> getAllPendingParcels(String condominiumId) async =>
      Success(registeredParcels);

  @override
  Stream<List<Parcel>> watchAllPendingParcels(String condominiumId) =>
      Stream.value(registeredParcels);

  @override
  Future<Result<List<Parcel>>> getParcelsForResident(String residentId) async =>
      const Success([]);

  @override
  Stream<List<Parcel>> watchPendingParcelsForUnit(String residentId) =>
      Stream.value([]);

  @override
  Future<Result<void>> markAsDelivered(
    String parcelId, {
    String? pickupProofUrl,
    String? pickedUpById,
    String? pickedUpByName,
    bool silentDischarge = false,
    String? dischargedBy,
  }) async =>
      const Success(null);

  @override
  Future<Result<List<Parcel>>> getParcelHistory({
    String? residentId,
    required String condominiumId,
  }) async =>
      const Success([]);
}

// ── Testable AI Parsing & Unit Validation Engine with Priority Logic ─────────

class AiParcelExtractionEngine {
  final List<Map<String, dynamic>> blocos;
  final Map<String, List<Map<String, dynamic>>> aptosByBlocoId;
  int aiCallCount = 0;

  AiParcelExtractionEngine({
    required this.blocos,
    required this.aptosByBlocoId,
  });

  Map<String, dynamic> analyzeWithManualPriority({
    Map<String, dynamic>? initialBloco,
    Map<String, dynamic>? initialApto,
    required int requestId,
    required int latestRequestId,
    required bool isMounted,
    Map<String, dynamic>? Function()? aiCaller,
  }) {
    final hasBloco = initialBloco != null;
    final hasApto = initialApto != null;

    // CENÁRIO 1: Ambos já preenchidos manualmente -> NÃO chamar Edge Function / IA. Custo ZERO.
    if (hasBloco && hasApto) {
      return {
        'aiCalled': false,
        'selectedBloco': initialBloco,
        'selectedApto': initialApto,
        'message': null,
      };
    }

    // AI must be called for scenarios 2, 3, 4
    aiCallCount++;
    final responseData = aiCaller != null ? aiCaller() : null;

    // Check mounted and race condition token
    if (!isMounted || requestId != latestRequestId) {
      return {'aiCalled': true, 'ignored': true};
    }

    if (responseData == null) {
      return {
        'aiCalled': true,
        'success': false,
        'selectedBloco': initialBloco,
        'selectedApto': initialApto,
        'message':
            '⚠️ Não foi possível identificar a unidade pela foto. Preencha Bloco e Apartamento manualmente.',
      };
    }

    final isAmbiguous = responseData['ambiguo'] == true;
    if (isAmbiguous) {
      final sugestoes = responseData['sugestoes'] is List ? (responseData['sugestoes'] as List) : [];
      final sugText = sugestoes.isNotEmpty
          ? sugestoes.map((s) => 'Bloco ${s['bloco']} - Apto ${s['apartamento']}').join(' ou ')
          : '';
      return {
        'aiCalled': true,
        'success': false,
        'selectedBloco': null,
        'selectedApto': null,
        'message': sugText.isNotEmpty
            ? '⚠️ Ambiguidade detectada na foto ($sugText). Selecione manualmente.'
            : '⚠️ Ambiguidade detectada na foto. Selecione a unidade manualmente.',
      };
    }

    final leituraOk = responseData['leitura_ok'] == true;
    final rawBloco = responseData['bloco']?.toString().trim();
    final rawApto = responseData['apartamento']?.toString().trim();

    if (!leituraOk || (rawBloco == null && rawApto == null)) {
      return {
        'aiCalled': true,
        'success': false,
        'selectedBloco': initialBloco,
        'selectedApto': initialApto,
        'message':
            '⚠️ Não foi possível identificar a unidade pela foto. Preencha manualmente.',
      };
    }

    // CENÁRIO 2: Bloco preenchido manualmente, Apto vazio
    if (hasBloco && !hasApto) {
      final blocoId = initialBloco['id'].toString();
      final blocoNome = initialBloco['nome_ou_numero'].toString().trim().toLowerCase();
      final aptosForBloco = aptosByBlocoId[blocoId] ?? [];

      if (rawApto != null) {
        var matchingApto = aptosForBloco.cast<Map<String, dynamic>>().firstWhere(
          (a) => a['numero'].toString().trim().toLowerCase() == rawApto.toLowerCase(),
          orElse: () => <String, dynamic>{},
        );

        if (matchingApto.isEmpty) {
          final dec = ParcelAddressNormalizer.decompose(rawApto);
          if (dec != null && dec.bloco.toLowerCase() == blocoNome) {
            matchingApto = aptosForBloco.cast<Map<String, dynamic>>().firstWhere(
              (a) => a['numero'].toString().trim().toLowerCase() == dec.apto.toLowerCase(),
              orElse: () => <String, dynamic>{},
            );
          }
        }

        if (matchingApto.isNotEmpty) {
          return {
            'aiCalled': true,
            'success': true,
            'selectedBloco': initialBloco, // SOBERANO
            'selectedApto': matchingApto,
            'message': '✓ Apartamento identificado automaticamente pela foto',
          };
        } else {
          return {
            'aiCalled': true,
            'success': false,
            'selectedBloco': initialBloco, // SOBERANO
            'selectedApto': null,
            'message':
                '⚠️ O apartamento identificado na foto não foi encontrado para o bloco selecionado. Confira os dados manualmente.',
          };
        }
      } else {
        return {
          'aiCalled': true,
          'success': false,
          'selectedBloco': initialBloco,
          'selectedApto': null,
          'message': '⚠️ Não foi possível identificar o apartamento pela foto. Selecione manualmente.',
        };
      }
    }

    // CENÁRIO 3: Bloco vazio, Apartamento preenchido manualmente
    if (!hasBloco && hasApto) {
      final manualAptoNum = initialApto['numero'].toString().trim().toLowerCase();

      var candidateBloco = rawBloco;
      if (candidateBloco == null && rawApto != null) {
        final dec = ParcelAddressNormalizer.decompose(rawApto);
        if (dec != null) {
          candidateBloco = dec.bloco;
        }
      }

      if (candidateBloco != null) {
        final matchingBloco = blocos.cast<Map<String, dynamic>>().firstWhere(
          (b) => b['nome_ou_numero'].toString().trim().toLowerCase() == candidateBloco!.toLowerCase(),
          orElse: () => <String, dynamic>{},
        );

        if (matchingBloco.isNotEmpty) {
          final blocoId = matchingBloco['id'].toString();
          final aptosForBloco = aptosByBlocoId[blocoId] ?? [];

          final matchingAptoInBloco = aptosForBloco.cast<Map<String, dynamic>>().firstWhere(
            (a) => a['numero'].toString().trim().toLowerCase() == manualAptoNum,
            orElse: () => <String, dynamic>{},
          );

          if (matchingAptoInBloco.isNotEmpty) {
            return {
              'aiCalled': true,
              'success': true,
              'selectedBloco': matchingBloco,
              'selectedApto': initialApto, // SOBERANO
              'message': '✓ Bloco identificado automaticamente pela foto',
            };
          } else {
            return {
              'aiCalled': true,
              'success': false,
              'selectedBloco': null,
              'selectedApto': initialApto, // SOBERANO
              'message':
                  '⚠️ O bloco identificado na foto não foi encontrado para o apartamento selecionado. Confira os dados manualmente.',
            };
          }
        } else {
          return {
            'aiCalled': true,
            'success': false,
            'selectedBloco': null,
            'selectedApto': initialApto,
            'message': '⚠️ O bloco identificado na foto não foi encontrado neste condomínio. Confira os dados manualmente.',
          };
        }
      } else {
        return {
          'aiCalled': true,
          'success': false,
          'selectedBloco': null,
          'selectedApto': initialApto,
          'message': '⚠️ Não foi possível identificar o bloco pela foto. Selecione manualmente.',
        };
      }
    }

    // CENÁRIO 4: Ambos vazios (!hasBloco && !hasApto)
    String? targetBloco = rawBloco;
    String? targetApto = rawApto;

    if (rawApto != null) {
      final dec = ParcelAddressNormalizer.decompose(rawApto);
      if (dec != null) {
        targetBloco ??= dec.bloco;
        targetApto = dec.apto;
      }
    }

    if (targetBloco == null && targetApto != null) {
      return {
        'aiCalled': true,
        'success': false,
        'selectedBloco': null,
        'selectedApto': null,
        'message':
            '⚠️ Apartamento $targetApto identificado, mas o bloco não está visível na foto. Selecione o bloco manualmente.',
      };
    }

    final matchingBloco = targetBloco != null
        ? blocos.cast<Map<String, dynamic>>().firstWhere(
            (b) => b['nome_ou_numero'].toString().trim().toLowerCase() == targetBloco!.toLowerCase(),
            orElse: () => <String, dynamic>{},
          )
        : <String, dynamic>{};

    if (matchingBloco.isEmpty) {
      return {
        'aiCalled': true,
        'success': false,
        'selectedBloco': null,
        'selectedApto': null,
        'message':
            '⚠️ A unidade identificada na foto não foi encontrada neste condomínio. Confira os dados manualmente.',
      };
    }

    final blocoId = matchingBloco['id'].toString();
    final aptosForBloco = aptosByBlocoId[blocoId] ?? [];

    if (targetApto != null) {
      final matchingApto = aptosForBloco.cast<Map<String, dynamic>>().firstWhere(
        (a) {
          final numStr = a['numero'].toString().trim().toLowerCase();
          return numStr == targetApto!.toLowerCase() || (rawApto != null && numStr == rawApto.toLowerCase());
        },
        orElse: () => <String, dynamic>{},
      );

      if (matchingApto.isNotEmpty) {
        return {
          'aiCalled': true,
          'success': true,
          'selectedBloco': matchingBloco,
          'selectedApto': matchingApto,
          'message': '✓ Unidade identificada automaticamente pela foto',
        };
      } else {
        return {
          'aiCalled': true,
          'success': false,
          'selectedBloco': null,
          'selectedApto': null,
          'message':
              '⚠️ A unidade identificada na foto não foi encontrada neste condomínio. Confira os dados manualmente.',
        };
      }
    } else {
      return {
        'aiCalled': true,
        'success': false,
        'selectedBloco': matchingBloco,
        'selectedApto': null,
        'message': '✓ Bloco identificado. Selecione o apartamento manualmente.',
      };
    }
  }
}

// ── FLUTTER INTEGRATION TEST SUITE ──────────────────────────────────────────

void main() {
  final List<Map<String, dynamic>> sampleBlocos = [
    <String, dynamic>{'id': 'bloco-1', 'nome_ou_numero': 'A'},
    <String, dynamic>{'id': 'bloco-2', 'nome_ou_numero': 'B'},
  ];

  final Map<String, List<Map<String, dynamic>>> sampleAptos = {
    'bloco-1': [
      <String, dynamic>{'id': 'apto-101', 'numero': '101'},
      <String, dynamic>{'id': 'apto-202', 'numero': '202'},
    ],
    'bloco-2': [
      <String, dynamic>{'id': 'apto-305', 'numero': '305'},
      <String, dynamic>{'id': 'apto-306', 'numero': '306'},
    ],
  };

  late AiParcelExtractionEngine engine;

  setUp(() {
    engine = AiParcelExtractionEngine(
      blocos: sampleBlocos,
      aptosByBlocoId: sampleAptos,
    );
  });

  test('CENÁRIO 1: Bloco e Apto já preenchidos -> IA NÃO É CHAMADA (Custo ZERO)', () {
    final initialBloco = sampleBlocos[1]; // Bloco B
    final initialApto = sampleAptos['bloco-2']![0]; // Apto 305

    final result = engine.analyzeWithManualPriority(
      initialBloco: initialBloco,
      initialApto: initialApto,
      requestId: 1,
      latestRequestId: 1,
      isMounted: true,
      aiCaller: () {
        fail('A IA NÃO deveria ser executada quando ambos os campos já estão preenchidos!');
      },
    );

    expect(result['aiCalled'], false);
    expect(engine.aiCallCount, 0); // 0 chamadas à IA
    expect(result['selectedBloco']['nome_ou_numero'], 'B');
    expect(result['selectedApto']['numero'], '305');
  });

  test('CENÁRIO 2: Bloco preenchido e Apto vazio -> IA chamada somente para Apto (Bloco é SOBERANO)', () {
    final initialBloco = sampleBlocos[1]; // Bloco B manual

    final result = engine.analyzeWithManualPriority(
      initialBloco: initialBloco,
      initialApto: null,
      requestId: 1,
      latestRequestId: 1,
      isMounted: true,
      aiCaller: () => {
        'leitura_ok': true,
        'bloco': 'A', // IA tenta retornar Bloco A (deve ser IGNORADO)
        'apartamento': '305', // Apto 305 válido no Bloco B
        'confianca': 0.98,
      },
    );

    expect(result['aiCalled'], true);
    expect(engine.aiCallCount, 1);
    expect(result['success'], true);
    expect(result['selectedBloco']['nome_ou_numero'], 'B'); // Preserva Bloco B manual!
    expect(result['selectedApto']['numero'], '305');
    expect(result['message'], '✓ Apartamento identificado automaticamente pela foto');
  });

  test('CENÁRIO 2 (Inexistente): Bloco preenchido e Apto retornado não existe no bloco -> Alerta e preservação manual', () {
    final initialBloco = sampleBlocos[0]; // Bloco A manual

    final result = engine.analyzeWithManualPriority(
      initialBloco: initialBloco,
      initialApto: null,
      requestId: 1,
      latestRequestId: 1,
      isMounted: true,
      aiCaller: () => {
        'leitura_ok': true,
        'apartamento': '305', // 305 pertence ao Bloco B, não ao Bloco A
      },
    );

    expect(result['aiCalled'], true);
    expect(result['success'], false);
    expect(result['selectedBloco']['nome_ou_numero'], 'A'); // Preserva Bloco A
    expect(result['selectedApto'], null); // Não seleciona
    expect(result['message'], contains('não foi encontrado para o bloco selecionado'));
  });

  test('CENÁRIO 3: Bloco vazio e Apto preenchido -> IA chamada somente para Bloco (Apto é SOBERANO)', () {
    final initialApto = sampleAptos['bloco-2']![0]; // Apto 305 manual

    final result = engine.analyzeWithManualPriority(
      initialBloco: null,
      initialApto: initialApto,
      requestId: 1,
      latestRequestId: 1,
      isMounted: true,
      aiCaller: () => {
        'leitura_ok': true,
        'bloco': 'B',
        'apartamento': '999', // IA tenta retornar outro apto (deve ser IGNORADO)
        'confianca': 0.95,
      },
    );

    expect(result['aiCalled'], true);
    expect(engine.aiCallCount, 1);
    expect(result['success'], true);
    expect(result['selectedBloco']['nome_ou_numero'], 'B');
    expect(result['selectedApto']['numero'], '305'); // Preserva Apto 305 manual!
    expect(result['message'], '✓ Bloco identificado automaticamente pela foto');
  });

  test('CENÁRIO 3 (Inexistente): Bloco identificado não possui o apartamento manual -> Alerta e preservação', () {
    final initialApto = sampleAptos['bloco-1']![0]; // Apto 101 manual (existe no Bloco A)

    final result = engine.analyzeWithManualPriority(
      initialBloco: null,
      initialApto: initialApto,
      requestId: 1,
      latestRequestId: 1,
      isMounted: true,
      aiCaller: () => {
        'leitura_ok': true,
        'bloco': 'B', // Bloco B não tem 101
      },
    );

    expect(result['aiCalled'], true);
    expect(result['success'], false);
    expect(result['selectedBloco'], null);
    expect(result['selectedApto']['numero'], '101'); // Preserva Apto 101
    expect(result['message'], contains('não foi encontrado para o apartamento selecionado'));
  });

  test('CENÁRIO 4: Bloco e Apto vazios -> IA chamada para ambos e preenche unidade completa', () {
    final result = engine.analyzeWithManualPriority(
      initialBloco: null,
      initialApto: null,
      requestId: 1,
      latestRequestId: 1,
      isMounted: true,
      aiCaller: () => {
        'leitura_ok': true,
        'bloco': 'B',
        'apartamento': '305',
        'confianca': 0.98,
      },
    );

    expect(result['aiCalled'], true);
    expect(engine.aiCallCount, 1);
    expect(result['success'], true);
    expect(result['selectedBloco']['nome_ou_numero'], 'B');
    expect(result['selectedApto']['numero'], '305');
    expect(result['message'], '✓ Unidade identificada automaticamente pela foto');
  });

  test('CENÁRIO 4 (Ilegível): Bloco e Apto vazios e foto ilegível -> Fallback manual gracioso', () {
    final result = engine.analyzeWithManualPriority(
      initialBloco: null,
      initialApto: null,
      requestId: 1,
      latestRequestId: 1,
      isMounted: true,
      aiCaller: () => {
        'leitura_ok': false,
        'bloco': null,
        'apartamento': null,
      },
    );

    expect(result['aiCalled'], true);
    expect(result['success'], false);
    expect(result['selectedBloco'], null);
    expect(result['selectedApto'], null);
    expect(result['message'], '⚠️ Não foi possível identificar a unidade pela foto. Preencha manualmente.');
  });

  test('RACE CONDITION: Foto A atrasada é ignorada em favor da Foto B mais recente', () {
    final resultA = engine.analyzeWithManualPriority(
      initialBloco: null,
      initialApto: null,
      requestId: 1,
      latestRequestId: 2, // Nova foto já solicitada
      isMounted: true,
      aiCaller: () => {
        'leitura_ok': true,
        'bloco': 'A',
        'apartamento': '101',
      },
    );

    expect(resultA['ignored'], true);
  });

  // ── GRUPO MONTSERRAT: ESTRUTURA REAL (BLOCOS A E B, APTO 301 NO BLOCO B) ───
  group('CONDOMÍNIO MONTSERRAT — IDENTIFICAÇÃO PÓS-OCR & BUSCA DE UNIDADES', () {
    final List<Map<String, dynamic>> montserratBlocos = [
      <String, dynamic>{'id': 'bloco-a', 'nome_ou_numero': 'A'},
      <String, dynamic>{'id': 'bloco-b', 'nome_ou_numero': 'B'},
    ];

    final Map<String, List<Map<String, dynamic>>> montserratAptos = {
      'bloco-a': [
        <String, dynamic>{'id': 'apto-101', 'numero': '101'},
        <String, dynamic>{'id': 'apto-301', 'numero': '301'},
      ],
      'bloco-b': [
        <String, dynamic>{'id': 'apto-102', 'numero': '102'},
        <String, dynamic>{'id': 'apto-301', 'numero': '301'},
        <String, dynamic>{'id': 'apto-302', 'numero': '302'},
      ],
    };

    late AiParcelExtractionEngine montserratEngine;

    setUp(() {
      montserratEngine = AiParcelExtractionEngine(
        blocos: montserratBlocos,
        aptosByBlocoId: montserratAptos,
      );
    });

    test('01. MONTSERRAT: Apto 301B (bloco null da IA) -> Identifica Bloco B e Apto 301', () {
      final res = montserratEngine.analyzeWithManualPriority(
        initialBloco: null,
        initialApto: null,
        requestId: 1,
        latestRequestId: 1,
        isMounted: true,
        aiCaller: () => {
          'leitura_ok': true,
          'bloco': null,
          'apartamento': '301B',
          'confianca': 0.98,
        },
      );
      expect(res['success'], true);
      expect(res['selectedBloco']['nome_ou_numero'], 'B');
      expect(res['selectedApto']['numero'], '301');
      expect(res['message'], '✓ Unidade identificada automaticamente pela foto');
    });

    test('02. MONTSERRAT: 301/B manuscrito (bloco null da IA) -> Identifica Bloco B e Apto 301', () {
      final res = montserratEngine.analyzeWithManualPriority(
        initialBloco: null,
        initialApto: null,
        requestId: 1,
        latestRequestId: 1,
        isMounted: true,
        aiCaller: () => {
          'leitura_ok': true,
          'bloco': null,
          'apartamento': '301/B',
          'confianca': 0.95,
        },
      );
      expect(res['success'], true);
      expect(res['selectedBloco']['nome_ou_numero'], 'B');
      expect(res['selectedApto']['numero'], '301');
    });

    test('03. MONTSERRAT: 301-B -> Identifica Bloco B e Apto 301', () {
      final res = montserratEngine.analyzeWithManualPriority(
        initialBloco: null,
        initialApto: null,
        requestId: 1,
        latestRequestId: 1,
        isMounted: true,
        aiCaller: () => {
          'leitura_ok': true,
          'bloco': null,
          'apartamento': '301-B',
          'confianca': 0.96,
        },
      );
      expect(res['success'], true);
      expect(res['selectedBloco']['nome_ou_numero'], 'B');
      expect(res['selectedApto']['numero'], '301');
    });

    test('04. MONTSERRAT: B301 -> Identifica Bloco B e Apto 301', () {
      final res = montserratEngine.analyzeWithManualPriority(
        initialBloco: null,
        initialApto: null,
        requestId: 1,
        latestRequestId: 1,
        isMounted: true,
        aiCaller: () => {
          'leitura_ok': true,
          'bloco': null,
          'apartamento': 'B301',
          'confianca': 0.97,
        },
      );
      expect(res['success'], true);
      expect(res['selectedBloco']['nome_ou_numero'], 'B');
      expect(res['selectedApto']['numero'], '301');
    });

    test('05. MONTSERRAT: B 301 -> Identifica Bloco B e Apto 301', () {
      final res = montserratEngine.analyzeWithManualPriority(
        initialBloco: null,
        initialApto: null,
        requestId: 1,
        latestRequestId: 1,
        isMounted: true,
        aiCaller: () => {
          'leitura_ok': true,
          'bloco': null,
          'apartamento': 'B 301',
          'confianca': 0.95,
        },
      );
      expect(res['success'], true);
      expect(res['selectedBloco']['nome_ou_numero'], 'B');
      expect(res['selectedApto']['numero'], '301');
    });

    test('06. MONTSERRAT: Bloco B Apto 301 (Explícito) -> Identifica Bloco B e Apto 301', () {
      final res = montserratEngine.analyzeWithManualPriority(
        initialBloco: null,
        initialApto: null,
        requestId: 1,
        latestRequestId: 1,
        isMounted: true,
        aiCaller: () => {
          'leitura_ok': true,
          'bloco': null,
          'apartamento': 'Bloco B Apto 301',
          'confianca': 0.99,
        },
      );
      expect(res['success'], true);
      expect(res['selectedBloco']['nome_ou_numero'], 'B');
      expect(res['selectedApto']['numero'], '301');
    });

    test('07. MONTSERRAT: Apto 301 Bloco B (Invertido) -> Identifica Bloco B e Apto 301', () {
      final res = montserratEngine.analyzeWithManualPriority(
        initialBloco: null,
        initialApto: null,
        requestId: 1,
        latestRequestId: 1,
        isMounted: true,
        aiCaller: () => {
          'leitura_ok': true,
          'bloco': null,
          'apartamento': 'Apto 301 Bloco B',
          'confianca': 0.99,
        },
      );
      expect(res['success'], true);
      expect(res['selectedBloco']['nome_ou_numero'], 'B');
      expect(res['selectedApto']['numero'], '301');
    });

    test('08. MONTSERRAT: Bloco B pré-selecionado e foto com 301B -> Identifica Apto 301', () {
      final res = montserratEngine.analyzeWithManualPriority(
        initialBloco: montserratBlocos[1], // Bloco B
        initialApto: null,
        requestId: 1,
        latestRequestId: 1,
        isMounted: true,
        aiCaller: () => {
          'leitura_ok': true,
          'bloco': null,
          'apartamento': '301B',
          'confianca': 0.95,
        },
      );
      expect(res['success'], true);
      expect(res['selectedBloco']['nome_ou_numero'], 'B');
      expect(res['selectedApto']['numero'], '301');
    });

    test('09. MONTSERRAT AMBIGUIDADE: Impresso 301B e Manuscrito 402A -> Não sobrescreve, exibe sugestões', () {
      final res = montserratEngine.analyzeWithManualPriority(
        initialBloco: null,
        initialApto: null,
        requestId: 1,
        latestRequestId: 1,
        isMounted: true,
        aiCaller: () => {
          'leitura_ok': false,
          'ambiguo': true,
          'sugestoes': [
            {'bloco': 'B', 'apartamento': '301'},
            {'bloco': 'A', 'apartamento': '402'},
          ],
          'bloco': null,
          'apartamento': null,
          'confianca': 0.90,
        },
      );
      expect(res['success'], false);
      expect(res['selectedBloco'], null);
      expect(res['selectedApto'], null);
      expect(res['message'], contains('Ambiguidade detectada'));
      expect(res['message'], contains('Bloco B - Apto 301'));
      expect(res['message'], contains('Bloco A - Apto 402'));
    });
  });

  test('CADASTRO FINAL: registerParcel() persiste com sucesso', () async {
    final repo = _TestParcelRepository();
    final parcel = Parcel(
      id: 'test-parcel-1',
      condominiumId: 'condo-1',
      residentName: 'Carlos Oliveira',
      unitNumber: '305',
      block: 'B',
      trackingCode: 'ML123456789',
      photoUrl: 'https://avypyaxthvgaybplnwxu.supabase.co/storage/v1/object/public/parcel-photos/test.jpg',
      status: 'pending',
      arrivalTime: DateTime.now(),
      registeredBy: 'user-porteiro',
    );

    final res = await repo.registerParcel(parcel);
    expect(res.isSuccess, true);
    expect(repo.registeredParcels.length, 1);
    expect(repo.registeredParcels.first.block, 'B');
    expect(repo.registeredParcels.first.unitNumber, '305');
  });
}
