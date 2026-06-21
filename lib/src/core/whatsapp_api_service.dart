import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/ledger_repository.dart';

final whatsappApiServiceProvider = Provider((ref) => WhatsAppApiService(ref));

class WhatsAppApiService {
  WhatsAppApiService(this._ref);
  final Ref _ref;

  Future<bool> sendNotification({
    required String toPhone,
    required String customerName,
    required String type, // 'credit' or 'payment'
    required String amount,
    required String description,
    required String totalBalance,
    required String merchantPhone,
  }) async {
    final repo = _ref.read(ledgerRepositoryProvider);
    final apiUrl = await repo.getSetting('whatsapp_api_url', '');
    final apiKey = await repo.getSetting('whatsapp_api_key', '');
    final apiTemplateId = await repo.getSetting('whatsapp_template_id', '');
    
    if (apiUrl.isEmpty || apiKey.isEmpty) {
      return false; // Fallback to manual share will be handled in UI
    }

    try {
      // Professional WhatsApp Business API structure (Generic)
      // This can be adapted for Twilio, MessageBird, or WhatsApp Cloud API
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
        },
        body: jsonEncode({
          'to': toPhone,
          'type': 'template',
          'template': {
            'id': apiTemplateId,
            'variables': [
              customerName,
              type,
              amount,
              description,
              totalBalance,
              merchantPhone,
            ]
          }
        }),
      );

      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      return false;
    }
  }
}
