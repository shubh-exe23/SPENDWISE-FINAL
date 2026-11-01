import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:file_saver/file_saver.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw; 
import '../models/transaction.dart';

class ExportService {
  
  static String _sanitizeText(String input) {
    final RegExp emojiRegex = RegExp(
        r'[\u{1F600}-\u{1F64F}\u{1F300}-\u{1F5FF}\u{1F680}-\u{1F6FF}\u{1F700}-\u{1F77F}\u{1F780}-\u{1F7FF}\u{1F800}-\u{1F8FF}\u{1F900}-\u{1F9FF}\u{1FA00}-\u{1FA6F}\u{1FA70}-\u{1FAFF}\u{2600}-\u{26FF}\u{2700}-\u{27BF}]', 
        unicode: true);
    return input.replaceAll(emojiRegex, '').trim();
  }

  // ── 1. CSV DIRECT DOWNLOAD ──
  static Future<void> exportToCSV(List<Transaction> transactions, {String currencySymbol = '₹'}) async {
    List<List<dynamic>> rows = [
      ['Date', 'Description', 'Category', 'Type', 'Amount']
    ];

    for (var tx in transactions) {
      String typeStr = tx.isExpense ? 'Expense' : 'Income';
      String amountFormatted = tx.isExpense 
          ? '-$currencySymbol${tx.amount.toStringAsFixed(2)}' 
          : '+$currencySymbol${tx.amount.toStringAsFixed(2)}';
      String dateFormatted = "${tx.date.year}-${tx.date.month.toString().padLeft(2, '0')}-${tx.date.day.toString().padLeft(2, '0')}";

      rows.add([dateFormatted, tx.title, tx.category, typeStr, amountFormatted]);
    }

    String csvData = csv.encode(rows);
    String csvString = '\ufeff$csvData';
    Uint8List bytes = Uint8List.fromList(utf8.encode(csvString));

    await FileSaver.instance.saveAs(
      name: 'spendwise_report_${DateTime.now().millisecondsSinceEpoch}',
      bytes: bytes,
      fileExtension: 'csv', // ── FIXED HERE ──
      mimeType: MimeType.csv,
    );
  }

  // ── 2. PDF DIRECT DOWNLOAD ──
  static Future<void> exportToPDF(List<Transaction> transactions, {String currencySymbol = '₹'}) async {
    final pdf = pw.Document();
    final headers = ['Date', 'Description', 'Category', 'Amount'];

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('Spendwise Statement', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('3EB489'))),
              pw.SizedBox(height: 4),
              pw.Text('Transaction History Report', style: const pw.TextStyle(fontSize: 14, color: PdfColors.grey700)),
              pw.SizedBox(height: 20),
            ]
          );
        },
        build: (pw.Context context) {
          return [
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
              columnWidths: {
                0: const pw.FlexColumnWidth(2),
                1: const pw.FlexColumnWidth(3),
                2: const pw.FlexColumnWidth(2),
                3: const pw.FlexColumnWidth(2.5), 
              },
              children: [
                pw.TableRow(
                  decoration: pw.BoxDecoration(color: PdfColor.fromHex('3EB489')),
                  children: headers.map((header) => pw.Padding(
                    padding: const pw.EdgeInsets.all(8),
                    child: pw.Text(header, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
                  )).toList(),
                ),
                ...transactions.map((tx) {
                  String dateFormatted = "${tx.date.day.toString().padLeft(2, '0')}/${tx.date.month.toString().padLeft(2, '0')}/${tx.date.year}";
                  String cleanTitle = _sanitizeText(tx.title);
                  String cleanCategory = _sanitizeText(tx.category);
                  
                  if (cleanTitle.isEmpty) cleanTitle = "Item";
                  if (cleanCategory.isEmpty) cleanCategory = "Other";

                  final amountColor = tx.isExpense ? PdfColors.red600 : PdfColors.green600;
                  final sign = tx.isExpense ? '-' : '+';
                  final amountText = '$sign${tx.amount.toStringAsFixed(2)}';

                  return pw.TableRow(
                    children: [
                      pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text(dateFormatted)),
                      pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text(cleanTitle)),
                      pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text(cleanCategory)),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8), 
                        child: pw.Text(amountText, textAlign: pw.TextAlign.right, style: pw.TextStyle(color: amountColor, fontWeight: pw.FontWeight.bold)),
                      ),
                    ],
                  );
                }),
              ],
            ),
          ];
        },
      ),
    );

    Uint8List pdfBytes = await pdf.save();

    await FileSaver.instance.saveAs(
      name: 'spendwise_statement_${DateTime.now().millisecondsSinceEpoch}',
      bytes: pdfBytes,
      fileExtension: 'pdf', // ── FIXED HERE ──
      mimeType: MimeType.pdf,
    );
  }
}