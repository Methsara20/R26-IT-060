import 'package:flutter/material.dart';
import '../services/api_service.dart';

class DeleteProfilePage extends StatefulWidget {
  final String profileId;
  final VoidCallback onDeleted;

  const DeleteProfilePage({
    super.key,
    required this.profileId,
    required this.onDeleted,
  });

  @override
  State<DeleteProfilePage> createState() => _DeleteProfilePageState();
}

class _DeleteProfilePageState extends State<DeleteProfilePage> {
  bool isLoading = false;
  String message = "";

  Future<void> deleteProfile() async {
    setState(() => isLoading = true);

    try {
      await ApiService.deleteProfile(widget.profileId);

      widget.onDeleted();

      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      setState(() => message = e.toString());
    }

    setState(() => isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text("Delete Profile"),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Card(
          elevation: 3,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.warning_amber_rounded,
                  size: 70,
                  color: Colors.red,
                ),

                const SizedBox(height: 12),

                const Text(
                  "Delete Profile?",
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 12),

                const Text(
                  "Are you sure you want to delete your profile? This action cannot be undone.",
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 20),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: isLoading ? null : deleteProfile,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text("Yes, Delete"),
                  ),
                ),

                const SizedBox(height: 8),

                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: isLoading ? null : () => Navigator.pop(context),
                    child: const Text("Cancel"),
                  ),
                ),

                if (isLoading)
                  const Padding(
                    padding: EdgeInsets.only(top: 12),
                    child: CircularProgressIndicator(),
                  ),

                if (message.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(message),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}