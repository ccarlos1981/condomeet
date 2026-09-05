import 'package:flutter_test/flutter_test.dart';
import 'package:condomeet/features/community/domain/models/common_area.dart';

void main() {
  group('CommonArea.formatLocalDisplay — Testes de Regra de Localização', () {
    test('Cenário A: local preenchido e outro_local nulo', () {
      final result = CommonArea.formatLocalDisplay(
        local: 'Salão de Festa',
        outroLocal: null,
      );
      expect(result, equals('Salão de Festa'));
    });

    test('Cenário B: local vazio e outro_local preenchido', () {
      final result = CommonArea.formatLocalDisplay(
        local: '',
        outroLocal: 'Fase A',
      );
      expect(result, equals('Fase A'));
    });

    test('Cenário C: local nulo e outro_local preenchido', () {
      final result = CommonArea.formatLocalDisplay(
        local: null,
        outroLocal: 'Fase A',
      );
      expect(result, equals('Fase A'));
    });

    test('Cenário D: local = Outro e outro_local preenchido', () {
      final result = CommonArea.formatLocalDisplay(
        local: 'Outro',
        outroLocal: 'Fase A',
      );
      expect(result, equals('Fase A'));
    });

    test('Cenário E: local com espaços e outro_local preenchido', () {
      final result = CommonArea.formatLocalDisplay(
        local: '   ',
        outroLocal: 'Fase A',
      );
      expect(result, equals('Fase A'));
    });

    test('Cenário F: ambos vazios / nulos', () {
      final result = CommonArea.formatLocalDisplay(
        local: '',
        outroLocal: null,
      );
      expect(result, equals('—'));
    });

    test('Cenário G: local = Outro sem outro_local', () {
      final result = CommonArea.formatLocalDisplay(
        local: 'Outro',
        outroLocal: '',
      );
      expect(result, equals('Outro'));
    });

    test('Cenário H: local normal prevalece sobre outro_local se local != Outro', () {
      final result = CommonArea.formatLocalDisplay(
        local: 'Bloco B',
        outroLocal: 'Fase A',
      );
      expect(result, equals('Bloco B'));
    });

    test('CommonArea.fromMap instancia corretamente displayLocal', () {
      final area = CommonArea.fromMap({
        'id': 'test-1',
        'condominio_id': 'condo-1',
        'tipo_agenda': 'Churrasqueira',
        'local': '',
        'outro_local': 'Fase A',
      });
      expect(area.displayLocal, equals('Fase A'));
    });
  });
}
