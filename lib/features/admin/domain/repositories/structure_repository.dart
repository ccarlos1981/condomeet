import 'package:condomeet/shared/models/bloco.dart';
import 'package:condomeet/shared/models/apartamento.dart';
import 'package:condomeet/shared/models/unidade.dart';

abstract class StructureRepository {
  // Blocos
  Stream<List<Bloco>> watchBlocos(String condominiumId);
  Future<void> addBloco(String condominiumId, String nomeOuNumero);
  Future<void> deleteBloco(String blocoId);

  // Apartamentos (independentes de bloco)
  Stream<List<Apartamento>> watchApartamentos(String condominiumId);
  Future<void> addApartamento(String condominiumId, String numero);
  Future<void> deleteApartamento(String apartamentoId);

  // Unidades (vínculo Bloco + Apartamento)
  Stream<List<Unidade>> watchUnidades(String condominiumId);
  Future<void> generateUnidades({
    required String condominiumId,
    required List<String> blocoIds,
    required List<String> apartamentoIds,
  });
  Future<void> deleteUnidade(String unidadeId);
}
