class ErrorSanitizer {
  static String sanitize(String rawMessage) {
    if (rawMessage.contains('Exception:') || rawMessage.contains('Error:')) {
      return 'Ocorreu um problema inesperado. Tente novamente em alguns instantes.';
    }
    
    if (rawMessage.contains('network') || rawMessage.contains('SocketException')) {
      return 'Sem conexão com a internet. Verifique seu sinal e tente novamente.';
    }

    if (rawMessage.contains('PostgrestException') || rawMessage.contains('sqlite3')) {
      return 'Houve um erro ao processar os dados. Se o problema persistir, contate o suporte.';
    }

    // If it's already a localized/clean message from repository, return it
    return rawMessage;
  }
}
