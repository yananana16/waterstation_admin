import 'dart:convert';
import 'package:http/http.dart' as http;

// Change this to your backend server URL if not running on the same machine
const String backendUrl = 'http://localhost:8080/send-approval-email';

Future<void> sendApprovalEmail(
  String recipientEmail,
  String stationName, {
  String? customBody,
  String? customSubject,
}) async {
  print('[DEBUG] Preparing to send approval email via backend...');
  print('[DEBUG] To: $recipientEmail | Station: $stationName');
  final payload = {
    'recipientEmail': recipientEmail,
    'stationName': stationName,
  };
  if (customBody != null) payload['customBody'] = customBody;
  if (customSubject != null) payload['customSubject'] = customSubject;
  final response = await http.post(
    Uri.parse(backendUrl),
    headers: {
      'Content-Type': 'application/json',
    },
    body: jsonEncode(payload),
  );
  print('[DEBUG] Backend response: ${response.statusCode} ${response.body}');
  if (response.statusCode == 200) {
    print('[DEBUG] Email sent successfully via backend.');
  } else {
    print('[DEBUG] Failed to send email via backend: ${response.statusCode} ${response.body}');
  }
}
