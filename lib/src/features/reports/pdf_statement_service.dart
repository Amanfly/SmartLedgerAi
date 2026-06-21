import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../core/currency.dart';
import '../../data/models.dart';

class PdfStatementService {
  Future<Uint8List> outstandingReport(List<CustomerBalance> balances) async {
    final logo = pw.MemoryImage(
      (await rootBundle.load('assets/logo.png')).buffer.asUint8List(),
    );

    final doc = pw.Document();
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (context) => [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('Smart Ledger AI', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
                  pw.Text('Outstanding Balances Report', style: const pw.TextStyle(fontSize: 12)),
                ],
              ),
              pw.Image(logo, height: 40),
            ],
          ),
          pw.SizedBox(height: 24),
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
