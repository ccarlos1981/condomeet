import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';

class GlobalErrorHandler {
  static final Logger _logger = Logger(
    printer: PrettyPrinter(
      methodCount: 2,
      errorMethodCount: 8,
      lineLength: 120,
      colors: true,
      printEmojis: true,
    ),
  );

  static void initialize() {
    // 1. Captura erros ocorridos dentro do framework do Flutter (ex: builds, layouts, callbacks de UI)
    FlutterError.onError = handleFlutterError;

    // 2. Captura erros assíncronos fora do framework do Flutter (ex: Future não capturado com catchError)
    PlatformDispatcher.instance.onError = handlePlatformError;
  }

  static void handleFlutterError(FlutterErrorDetails details) {
    if (kDebugMode) {
      FlutterError.dumpErrorToConsole(details);
    }
    
    _logger.e(
      'Flutter Framework Error Captured',
      error: details.exception,
      stackTrace: details.stack,
    );
    
    // Podemos integrar serviços como Sentry ou Crashlytics aqui futuramente
  }

  static bool handlePlatformError(Object error, StackTrace stack) {
    _logger.e(
      'Platform/Isolate Async Error Captured',
      error: error,
      stackTrace: stack,
    );
    
    // Retornar true indica que o erro foi "tratado" e evita que ele feche sumariamente o app em alguns casos
    // Podemos integrar Crashlytics aqui futuramente
    return true;
  }
}
