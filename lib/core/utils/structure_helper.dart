class StructureHelper {
  /// Retorna o rótulo adequado para o Agrupador Nível 1 baseado no tipo de estrutura.
  /// 
  /// - 'predio': Bloco / Torre
  /// - 'casa_rua': Rua
  /// - 'casa_quadra': Quadra
  static String getNivel1Label(String? tipoEstrutura) {
    if (tipoEstrutura == 'casa_rua') return 'Rua';
    if (tipoEstrutura == 'casa_quadra') return 'Quadra';
    return 'Bloco';
  }

  /// Retorna o rótulo adequado para o Agrupador Nível 2 baseado no tipo de estrutura.
  /// 
  /// - 'predio': Apto
  /// - 'casa_rua': Número
  /// - 'casa_quadra': Lote
  static String getNivel2Label(String? tipoEstrutura) {
    if (tipoEstrutura == 'casa_rua') return 'Número';
    if (tipoEstrutura == 'casa_quadra') return 'Lote';
    return 'Apto';
  }

  /// Retorna o rótulo adequado para uma unidade completa ("Apto 101, Bloco A" vs "Casa 10, Rua B")
  static String getFullUnitName(String? tipoEstrutura, String nivel1, String nivel2) {
    if (tipoEstrutura == 'casa_rua') return 'Número $nivel2, Rua $nivel1';
    if (tipoEstrutura == 'casa_quadra') return 'Lote $nivel2, Quadra $nivel1';
    return 'Apto $nivel2, Bloco $nivel1';
  }

  /// Retorna dicas para os TextFields baseados no tipo de estrutura
  static String getNivel1Hint(String? tipoEstrutura) {
    if (tipoEstrutura == 'casa_rua') return 'Ex: Rua Flamboyant, Alameda 1...';
    if (tipoEstrutura == 'casa_quadra') return 'Ex: Quadra 04, QL 10...';
    return 'Ex: Bloco A, Torre 1...';
  }

  static String getNivel2Hint(String? tipoEstrutura) {
    if (tipoEstrutura == 'casa_rua') return 'Ex: 10, 15A...';
    if (tipoEstrutura == 'casa_quadra') return 'Ex: Lote 12, Lote B...';
    return 'Ex: 101, 102, 201...';
  }
}
