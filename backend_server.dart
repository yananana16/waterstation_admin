import 'dart:convert';
import 'dart:io';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';

const String gmailUsername = 'federated.president000@gmail.com';
const String gmailPassword = 'rnty azah nvrk fzyk';
const String senderName = 'H2OGO';
const String senderEmail = 'federated.president000@gmail.com';

Future<Response> sendApprovalEmailHandler(Request request) async {
  print('[DEBUG] Received request to /send-approval-email');
  final payload = await request.readAsString();
  print('[DEBUG] Payload: $payload');
  final data = jsonDecode(payload);
  final recipientEmail = data['recipientEmail'] as String?;
  final stationName = data['stationName'] as String?;
  final customBody = data['customBody'] as String?;
  final customSubject = data['customSubject'] as String?;
  if (recipientEmail == null || recipientEmail.isEmpty) {
    print('[DEBUG] Missing recipientEmail');
    return Response(400, body: 'Missing recipientEmail');
  }

  print('[DEBUG] Sending email via Gmail SMTP...');
  final smtpServer = gmail(gmailUsername, gmailPassword);
  final subject = customSubject ?? 'YOUR STATION HAS BEEN APPROVED';
  final htmlBody = customBody ?? '''
    <div style="font-family: Arial, sans-serif; background: #f4f8fb; padding: 32px;">
      <div style="max-width: 480px; margin: auto; background: #fff; border-radius: 12px; box-shadow: 0 2px 8px #0001; padding: 32px 24px;">
        <div style="text-align: center;">
          <div style="font-size: 54px; margin-bottom: 18px;">👍</div>
          <h2 style="color: #1565c0; margin-bottom: 8px;">CONGRATULATIONS!</h2>
          <h3 style="color: #2e7d32; margin-top: 0;">Your station has been approved</h3>
        </div>
        <p style="font-size: 16px; color: #222; text-align: center; margin: 24px 0 16px 0;">
          You may now login to your account and start using H2OGO.
        </p>
        <p style="font-size: 15px; color: #555; text-align: center; margin-top: 32px;">Thank you for choosing <b>H2OGO</b>!</p>
      </div>
    </div>
    ''';
  final message = Message()
    ..from = Address(senderEmail, senderName)
    ..recipients.add(recipientEmail)
    ..subject = subject
    ..html = htmlBody;

  try {
    final sendReport = await send(message, smtpServer);
    print('[DEBUG] Email sent: ${sendReport.toString()}');
    return Response.ok('Email sent successfully');
  } catch (e) {
    print('[DEBUG] Failed to send email via Gmail SMTP: $e');
    return Response.internalServerError(body: 'Failed to send email: $e');
  }
}

Response _optionsHandler(Request request) {
  return Response.ok('', headers: {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Methods': 'POST, OPTIONS',
    'Access-Control-Allow-Headers': 'Origin, Content-Type, Accept',
  });
}

Middleware corsMiddleware = (Handler innerHandler) {
  return (Request request) async {
    if (request.method == 'OPTIONS') {
      return _optionsHandler(request);
    }
    final response = await innerHandler(request);
    return response.change(headers: {
      ...response.headers,
      'Access-Control-Allow-Origin': '*',
    });
  };
};

void main(List<String> args) async {
  final handler = Pipeline()
      .addMiddleware(logRequests())
      .addMiddleware(corsMiddleware)
      .addHandler((Request request) {
    if (request.method == 'POST' && request.url.path == 'send-approval-email') {
      return sendApprovalEmailHandler(request);
    }
    if (request.method == 'OPTIONS' && request.url.path == 'send-approval-email') {
      return _optionsHandler(request);
    }
    return Response.notFound('Not Found');
  });

  final port = int.parse(Platform.environment['PORT'] ?? '8080');
  final server = await io.serve(handler, InternetAddress.anyIPv4, port);
  print('Backend server listening on port ${server.port}');
}