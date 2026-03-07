import 'dart:convert';
import 'dart:io';

Future<void> main() async {
  final apiKey = Platform.environment['BOTCONVERSA_API_KEY'];
  final flowId = Platform.environment['BOTCONVERSA_FLOW_ID'];
  final testPhone = Platform.environment['TEST_PHONE']; // Raw input phone

  if (apiKey == null || apiKey.isEmpty || testPhone == null || testPhone.isEmpty) {
    print('Please set BOTCONVERSA_API_KEY, BOTCONVERSA_FLOW_ID, and TEST_PHONE environment variables.');
    return;
  }

  print('Testing Botconversa with raw phone: $testPhone');
  
  // Test scenario 1: Exactly as passed (but digits only)
  String cleanPhone = testPhone.replaceAll(RegExp(r'\D'), '');
  String formattedPhone = cleanPhone;
  if (cleanPhone.isNotEmpty && !cleanPhone.startsWith('55')) {
    formattedPhone = '55$cleanPhone';
  }

  // Test scenario 2: Without the 9th digit (if it has 11 digits and starts with 1-9)
  // For Brazil, DDD + 9 digits = 11 digits. Some APIs prefer DDD + 8 digits.
  String formattedPhoneNo9 = cleanPhone;
  if (cleanPhone.startsWith('55') && cleanPhone.length == 13) {
      if (cleanPhone[4] == '9') {
          // Remove the 5th character (index 4)
          formattedPhoneNo9 = cleanPhone.substring(0, 4) + cleanPhone.substring(5);
      }
  } else if (!cleanPhone.startsWith('55') && cleanPhone.length == 11) {
      if (cleanPhone[2] == '9') {
          formattedPhoneNo9 = '55' + cleanPhone.substring(0, 2) + cleanPhone.substring(3);
      }
  }

  print('Scenario 1 (With 9): $formattedPhone');
  print('Scenario 2 (Without 9): $formattedPhoneNo9');

  final scenarios = {
    'With 9': formattedPhone,
    'Without 9': formattedPhoneNo9,
  };

  for (final entry in scenarios.entries) {
    final phoneToSend = entry.value;
    print('\nSending to ${entry.key} ($phoneToSend)...');
    
    final body = {
      'phone': phoneToSend,
      'first_name': 'Test',
      'last_name': '(API Debug)',
      'variables': [
        {'key': 'encomenda_id', 'value': 'test-id-123'},
        {'key': 'unidade', 'value': 'Debug'},
        {'key': 'bloco', 'value': 'Debug'},
        {'key': 'foto_url', 'value': ''}
      ],
      'flow_id': flowId != null ? int.tryParse(flowId) : null,
    };

    try {
      final request = await HttpClient().postUrl(Uri.parse('https://backend.botconversa.com.br/api/v1/webhook/subscriber/'));
      request.headers.set('Content-Type', 'application/json');
      request.headers.set('API-KEY', apiKey);
      request.write(jsonEncode(body));
      
      final response = await request.close();
      final responseBody = await response.transform(utf8.decoder).join();
      
      print('Status Code: ${response.statusCode}');
      print('Response: $responseBody');
    } catch (e) {
      print('Error: $e');
    }
  }
}
