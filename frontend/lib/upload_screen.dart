import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';
import 'main.dart' show backendUrl;

class UploadScreen extends StatefulWidget {
  const UploadScreen({super.key});

  @override
  State<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {
  bool uploadingCampaigns = false;
  bool uploadingCustomers = false;
  bool uploadingTransactions = false;

  Map<String, dynamic>? campaignsResult;
  Map<String, dynamic>? customersResult;
  Map<String, dynamic>? transactionsResult;

  String? campaignsError;
  String? customersError;
  String? transactionsError;

  List<dynamic> uploadHistory = [];
  bool loadingHistory = false;

  @override
  void initState() {
    super.initState();
    fetchHistory();
  }

  Future<void> fetchHistory() async {
    setState(() => loadingHistory = true);
    try {
      final response = await http.get(Uri.parse('$backendUrl/upload-history')).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        setState(() {
          uploadHistory = json.decode(response.body);
          loadingHistory = false;
        });
      } else {
        setState(() => loadingHistory = false);
      }
    } catch (e) {
      setState(() => loadingHistory = false);
    }
  }

  Future<void> pickAndUpload(String fileType) async {
    final files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
    );
    if (files.isEmpty) return;

    final file = files.first;
    final bytes = await file.readAsBytes();

    setState(() {
      if (fileType == 'campaigns') { uploadingCampaigns = true; campaignsError = null; }
      if (fileType == 'customers') { uploadingCustomers = true; customersError = null; }
      if (fileType == 'transactions') { uploadingTransactions = true; transactionsError = null; }
    });

    try {
      final uri = Uri.parse('$backendUrl/upload');
      final request = http.MultipartRequest('POST', uri);
      request.fields['file_type'] = fileType;
      request.files.add(http.MultipartFile.fromBytes('file', bytes, filename: file.name));

      final streamedResponse = await request.send().timeout(const Duration(seconds: 60));
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          if (fileType == 'campaigns') { campaignsResult = data; uploadingCampaigns = false; }
          if (fileType == 'customers') { customersResult = data; uploadingCustomers = false; }
          if (fileType == 'transactions') { transactionsResult = data; uploadingTransactions = false; }
        });
        await fetchHistory();
      } else {
        final body = json.decode(response.body);
        final msg = body['detail'] ?? 'Upload failed (${response.statusCode})';
        setState(() {
          if (fileType == 'campaigns') { campaignsError = msg; uploadingCampaigns = false; }
          if (fileType == 'customers') { customersError = msg; uploadingCustomers = false; }
          if (fileType == 'transactions') { transactionsError = msg; uploadingTransactions = false; }
        });
      }
    } catch (e) {
      setState(() {
        if (fileType == 'campaigns') { campaignsError = 'Error: $e'; uploadingCampaigns = false; }
        if (fileType == 'customers') { customersError = 'Error: $e'; uploadingCustomers = false; }
        if (fileType == 'transactions') { transactionsError = 'Error: $e'; uploadingTransactions = false; }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A2744),
        foregroundColor: Colors.white,
        title: const Text('Upload Data'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Files are automatically cleaned — duplicates removed, PII anonymized, formats fixed — then saved to Firebase.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 20),

            _buildUploadCard(
              title: 'Campaigns (primary — required)',
              fileType: 'campaigns',
              uploading: uploadingCampaigns,
              result: campaignsResult,
              error: campaignsError,
            ),
            const SizedBox(height: 16),
            _buildUploadCard(
              title: 'Customers (recommended)',
              fileType: 'customers',
              uploading: uploadingCustomers,
              result: customersResult,
              error: customersError,
            ),
            const SizedBox(height: 16),
            _buildUploadCard(
              title: 'Transactions (optional)',
              fileType: 'transactions',
              uploading: uploadingTransactions,
              result: transactionsResult,
              error: transactionsError,
            ),

            const SizedBox(height: 24),
            Row(
              children: [
                const Text('Upload History', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1A2744))),
                const Spacer(),
                IconButton(icon: const Icon(Icons.refresh, size: 18), onPressed: fetchHistory),
              ],
            ),
            const SizedBox(height: 8),
            if (loadingHistory)
              const Center(child: CircularProgressIndicator())
            else if (uploadHistory.isEmpty)
              const Text('No uploads yet.', style: TextStyle(color: Colors.grey, fontSize: 12))
            else
              Container(
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFEDE5D0))),
                child: Column(
                  children: uploadHistory.map((h) {
                    return ListTile(
                      dense: true,
                      leading: const Icon(Icons.description_outlined, size: 18),
                      title: Text('${h['file_type']}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      subtitle: Text('${h['row_count']} rows · ${h['uploaded_at']}', style: const TextStyle(fontSize: 11)),
                    );
                  }).toList(),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildUploadCard({
    required String title,
    required String fileType,
    required bool uploading,
    Map<String, dynamic>? result,
    String? error,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFEDE5D0))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1A2744))),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: uploading ? null : () => pickAndUpload(fileType),
              icon: uploading
                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.upload_file),
              label: Text(uploading ? 'Uploading...' : 'Choose CSV file'),
            ),
          ),
          if (error != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(8)),
              child: Text(error, style: TextStyle(color: Colors.red.shade900, fontSize: 12)),
            ),
          ],
          if (result != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(8)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Saved to Firebase — ${result['row_count']} rows', style: TextStyle(color: Colors.green.shade900, fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  ...List<String>.from(result['cleaning_report'] ?? []).map(
                    (r) => Text('• $r', style: TextStyle(color: Colors.green.shade800, fontSize: 11)),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}