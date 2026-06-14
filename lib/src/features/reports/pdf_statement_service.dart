import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../core/currency.dart';
import '../../data/models.dart';

class PdfStatementService {
  Future<Uint8List> outstandingReport(List<CustomerBalance> balances) async {
    final doc = pw.Document();
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (context) => [
          pw.Text('Smart Ledger AI - Outstanding Balances', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 16),
          pw.TableHelper.fromTextArray(
            headers: ['Customer', 'Phone', 'Balance'],
            data: balances.map((item) => [item.customer.name, item.customer.phone, formatMoney(item.balancePaise)]).toList(),
          ),
        ],
      ),
    );
    return doc.save();
  }
}
