// Web downloads intentionally use dart:html because this application targets Flutter web.
// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter

import 'dart:convert';
import 'dart:html' as html;
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../core/theme/app_colors.dart';
import '../services/upload_service.dart';

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
      final response = await UploadService.fetchHistory();
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

  Future<void> downloadUpload(String uploadId) async {
    try {
      final response = await UploadService.downloadUpload(uploadId);
      if (response.statusCode == 200) {
        final blob = html.Blob([response.bodyBytes], 'text/csv');
        final url = html.Url.createObjectUrlFromBlob(blob);
        html.AnchorElement(href: url)
          ..setAttribute('download', 'upload_$uploadId.csv')
          ..click();
        html.Url.revokeObjectUrl(url);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not download this file.')));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Download failed: $e')));
      }
    }
  }

  Future<void> confirmDeleteUpload(String uploadId, String fileType) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.cardBackground,
        title: const Text('Delete this upload?', style: TextStyle(color: AppColors.textPrimary)),
        content: Text(
          'This will permanently delete the $fileType file uploaded at this time. This cannot be undone.',
          style: const TextStyle(color: AppColors.textMuted),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: AppColors.errorText)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final response = await UploadService.deleteUpload(uploadId);
      if (response.statusCode == 200) {
        await fetchHistory();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Upload deleted.')));
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not delete this upload.')));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Delete failed: $e')));
      }
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
      final response = await UploadService.uploadFile(fileType: fileType, bytes: bytes, filename: file.name);

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
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.textPrimary,
        title: Row(
          children: [
            Container(width: 3, height: 20,
              decoration: BoxDecoration(
                gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
                  colors: [AppColors.primaryBlue, AppColors.greenAccent]),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 10),
            const Text('Upload Data', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.primaryBlue.withOpacity(0.12), AppColors.greenAccent.withOpacity(0.04)],
                  begin: Alignment.centerLeft, end: Alignment.centerRight,
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.primaryBlue.withOpacity(0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.auto_fix_high_rounded, color: AppColors.blueAccent, size: 18),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Files are automatically cleaned — duplicates removed, PII anonymized, formats fixed — then saved to the database.',
                      style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            _buildUploadCard(
              title: 'Campaigns',
              subtitle: 'Primary — required for the dashboard',
              fileType: 'campaigns',
              uploading: uploadingCampaigns,
              result: campaignsResult,
              error: campaignsError,
              accentColor: AppColors.goldAccent,
              icon: Icons.campaign_rounded,
            ),
            const SizedBox(height: 16),
            _buildUploadCard(
              title: 'Customers',
              subtitle: 'Recommended for better recommendations',
              fileType: 'customers',
              uploading: uploadingCustomers,
              result: customersResult,
              error: customersError,
              accentColor: AppColors.primaryBlue,
              icon: Icons.people_rounded,
            ),
            const SizedBox(height: 16),
            _buildUploadCard(
              title: 'Transactions',
              subtitle: 'Optional — for revenue analysis',
              fileType: 'transactions',
              uploading: uploadingTransactions,
              result: transactionsResult,
              error: transactionsError,
              accentColor: AppColors.greenAccent,
              icon: Icons.receipt_long_rounded,
            ),

            const SizedBox(height: 28),
            Row(
              children: [
                Container(width: 3, height: 16, decoration: BoxDecoration(color: AppColors.goldAccent, borderRadius: BorderRadius.circular(2))),
                const SizedBox(width: 8),
                const Text('Upload History', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                const Spacer(),
                IconButton(icon: const Icon(Icons.refresh_rounded, size: 18), onPressed: fetchHistory,
                  style: IconButton.styleFrom(foregroundColor: AppColors.textMuted)),
              ],
            ),
            const SizedBox(height: 8),
            if (loadingHistory)
              const Center(child: CircularProgressIndicator())
            else if (uploadHistory.isEmpty)
              const Text('No uploads yet.', style: TextStyle(color: AppColors.textMuted, fontSize: 12))
            else
              Container(
                decoration: BoxDecoration(color: AppColors.cardBackground, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.divider)),
                child: Column(
                  children: uploadHistory.map((h) {
                    return ListTile(
                      dense: true,
                      leading: const Icon(Icons.description_outlined, size: 18),
                      title: Text('${h['file_type']}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      subtitle: Text('${h['row_count']} rows · ${h['uploaded_at']}', style: const TextStyle(fontSize: 11)),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.download, size: 18),
                            tooltip: 'Download',
                            onPressed: () => downloadUpload(h['upload_id']),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.errorText),
                            tooltip: 'Delete',
                            onPressed: () => confirmDeleteUpload(h['upload_id'], h['file_type']),
                          ),
                        ],
                      ),
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
    String? subtitle,
    required String fileType,
    required bool uploading,
    Map<String, dynamic>? result,
    String? error,
    Color accentColor = AppColors.goldAccent,
    IconData icon = Icons.upload_file,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [Colors.white.withOpacity(0.07), Colors.white.withOpacity(0.02)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
        boxShadow: [BoxShadow(color: accentColor.withOpacity(0.06), blurRadius: 16, spreadRadius: -2, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: accentColor),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary, fontSize: 15)),
                  if (subtitle != null)
                    Text(subtitle, style: TextStyle(fontSize: 11, color: accentColor.withOpacity(0.8))),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: GestureDetector(
              onTap: uploading ? null : () => pickAndUpload(fileType),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  gradient: uploading ? null : LinearGradient(
                    colors: [accentColor.withOpacity(0.8), accentColor.withOpacity(0.5)],
                  ),
                  color: uploading ? Colors.white.withOpacity(0.05) : null,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: accentColor.withOpacity(0.4)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    uploading
                        ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : Icon(Icons.upload_file_rounded, size: 16, color: uploading ? AppColors.textMuted : Colors.white),
                    const SizedBox(width: 8),
                    Text(uploading ? 'Uploading...' : 'Choose CSV file',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                        color: uploading ? AppColors.textMuted : Colors.white)),
                  ],
                ),
              ),
            ),
          ),
          if (error != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.errorBackground,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.urgentAccent.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline_rounded, color: AppColors.errorText, size: 16),
                  const SizedBox(width: 8),
                  Expanded(child: Text(error, style: const TextStyle(color: AppColors.errorText, fontSize: 12))),
                ],
              ),
            ),
          ],
          if (result != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.successBackground,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.greenAccent.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.check_circle_rounded, color: AppColors.successText, size: 16),
                      const SizedBox(width: 8),
                      Text('Saved \u2014 ${result['row_count']} rows', style: const TextStyle(color: AppColors.successText, fontSize: 12, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  ...List<String>.from(result['cleaning_report'] ?? []).map(
                    (r) => Text('\u2022 $r', style: const TextStyle(color: AppColors.successText, fontSize: 11)),
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

