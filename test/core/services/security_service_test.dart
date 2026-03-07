import 'package:flutter_test/flutter_test.dart';
import 'package:condomeet/core/services/security_service.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:mocktail/mocktail.dart';
import 'dart:convert';
import 'package:crypto/crypto.dart';

class MockFlutterSecureStorage extends Mock implements FlutterSecureStorage {}

void main() {
  late SecurityService securityService;
  late MockFlutterSecureStorage mockStorage;

  setUp(() {
    mockStorage = MockFlutterSecureStorage();
    securityService = SecurityService(storage: mockStorage);
  });

  group('SecurityService - PIN Management', () {
    const testPin = '1234';
    final testPinHash = sha256.convert(utf8.encode(testPin)).toString();

    test('savePin should hash the PIN and write to secure storage', () async {
      // Arrange
      when(() => mockStorage.write(
            key: any(named: 'key'),
            value: any(named: 'value'),
          )).thenAnswer((_) async {});

      // Act
      await securityService.savePin(testPin);

      // Assert
      verify(() => mockStorage.write(key: 'user_pin_hash', value: testPinHash)).called(1);
    });

    test('verifyPin should return true if PIN matches stored hash', () async {
      // Arrange
      when(() => mockStorage.read(key: 'user_pin_hash'))
          .thenAnswer((_) async => testPinHash);

      // Act
      final result = await securityService.verifyPin(testPin);

      // Assert
      expect(result, isTrue);
    });

    test('verifyPin should return false if PIN does not match', () async {
      // Arrange
      when(() => mockStorage.read(key: 'user_pin_hash'))
          .thenAnswer((_) async => testPinHash);

      // Act
      final result = await securityService.verifyPin('4321');

      // Assert
      expect(result, isFalse);
    });

    test('verifyPin should return false if no PIN is stored', () async {
      // Arrange
      when(() => mockStorage.read(key: 'user_pin_hash'))
          .thenAnswer((_) async => null);

      // Act
      final result = await securityService.verifyPin(testPin);

      // Assert
      expect(result, isFalse);
    });

    test('clearPin should delete PIN from storage', () async {
      // Arrange
      when(() => mockStorage.delete(key: 'user_pin_hash'))
          .thenAnswer((_) async {});

      // Act
      await securityService.clearPin();

      // Assert
      verify(() => mockStorage.delete(key: 'user_pin_hash')).called(1);
    });
  });

  group('SecurityService - Biometrics Status', () {
    test('isBiometricsEnabled should return true if storage value is "true"', () async {
      when(() => mockStorage.read(key: 'biometrics_enabled'))
          .thenAnswer((_) async => 'true');
      
      final result = await securityService.isBiometricsEnabled();
      expect(result, isTrue);
    });

    test('isBiometricsEnabled should return false if storage value is not "true"', () async {
      when(() => mockStorage.read(key: 'biometrics_enabled'))
          .thenAnswer((_) async => 'false');
      
      final result = await securityService.isBiometricsEnabled();
      expect(result, isFalse);
    });
  });
}
