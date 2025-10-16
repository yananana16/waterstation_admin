import 'dart:convert';
import 'dart:developer' show log;
import 'package:http/http.dart' as http;

// ✅ Backend email service endpoint (Render URL)
const String backendUrl = 'https://email-backend-qhq3.onrender.com/send-email';

Future<void> sendApprovalEmail(
  String recipientEmail,
  String stationName, {
  String? customBody,
  String? customSubject,
}) async {
  log('[DEBUG] Preparing to send approval email...');
  log('[DEBUG] Backend URL: $backendUrl');
  log('[DEBUG] To: $recipientEmail | Station: $stationName');

  // Default email content
  final subject = customSubject ?? 'Station $stationName Approved';
  final body = customBody ??
      '''
      <div style="font-family: Arial, Helvetica, sans-serif; background: #f3f8fc; padding: 32px;">
        <div style="max-width:720px;margin:0 auto;padding:36px 24px;background:#ffffff;border-radius:10px;box-shadow:0 6px 18px rgba(20,40,80,0.06);text-align:center;">
          <div style="font-size:56px;line-height:1;color:#f6b21a;margin-bottom:6px;">👍</div>
          <h1 style="margin:8px 0 6px 0;font-size:22px;color:#0b62c9;letter-spacing:0.6px;">CONGRATULATIONS!</h1>
          <div style="font-weight:600;color:#2e7d32;margin-bottom:14px;">Your station has been approved</div>
          <p style="color:#333333;font-size:15px;margin:8px 0 18px 0;">You may now login to your account and start using <strong>H2OGO</strong>.</p>
          <p style="color:#7a7a7a;font-size:13px;margin:0;">Thank you for choosing <strong>H2OGO</strong>!</p>
        </div>
      </div>
      ''';

  final payload = {
    'to': recipientEmail,
    'subject': subject,
    'body': body,
    // Provide a plain-text fallback for SendGrid / email backends that
    // require a non-empty text content to avoid 400 Bad Request errors.
    'text': _htmlToPlainText(body),
  };

  try {
    final response = await http
        .post(
          Uri.parse(backendUrl),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(payload),
        )
        .timeout(const Duration(seconds: 15));

    log('[DEBUG] Backend response: ${response.statusCode} ${response.body}');

    if (response.statusCode == 200) {
      log('[✅] Email sent successfully to $recipientEmail');
    } else {
      log('[❌] Failed to send email: ${response.statusCode} ${response.body}');
    }
  } catch (e, st) {
    log('[⚠️ ERROR] Exception while calling backend: $e\n$st');
  }
}

// Minimal HTML -> plain-text converter. Keeps it intentionally small and
// dependency-free: strip tags and decode a few common HTML entities.
String _htmlToPlainText(String html) {
  var t = html
    // Remove newlines and excessive whitespace
    .replaceAll(RegExp(r'\s+'), ' ')
    // Replace <br> and </p> with newlines (case-insensitive)
    .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
    .replaceAll(RegExp(r'</p>', caseSensitive: false), '\n')
    // Remove all other tags
    .replaceAll(RegExp(r'<[^>]*>'), ' ')
    .trim();

  // Decode a few common HTML entities
  t = t.replaceAll('&lt;', '<').replaceAll('&gt;', '>').replaceAll('&amp;', '&').replaceAll('&nbsp;', ' ');
  // Collapse multiple newlines/spaces
  t = t.replaceAll(RegExp(r'\n{2,}'), '\n').replaceAll(RegExp(r' +'), ' ');
  return t;
}
