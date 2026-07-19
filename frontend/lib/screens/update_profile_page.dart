import 'package:flutter/material.dart';
import '../services/api_service.dart';

class UpdateProfilePage extends StatefulWidget {
  final String profileId;

  const UpdateProfilePage({
    super.key,
    required this.profileId,
  });

  @override
  State<UpdateProfilePage> createState() => _UpdateProfilePageState();
}

class _UpdateProfilePageState extends State<UpdateProfilePage> {
  final heightController = TextEditingController();
  final weightController = TextEditingController();
  final passwordController = TextEditingController();

  String heightUnit = "cm";
  String weightUnit = "kg";
  String? selectedGender;

  bool isLoading = false;
  bool showPassword = false;
  String message = "";

  final List<String> genderOptions = [
    "male",
    "female",
    "prefer not to say",
  ];

  @override
  void dispose() {
    heightController.dispose();
    weightController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  double _toDouble(String value) {
    return double.tryParse(value.trim()) ?? 0;
  }

  double? _heightToCm() {
    if (heightController.text.trim().isEmpty) return null;
    final height = _toDouble(heightController.text);
    return heightUnit == "inch" ? height * 2.54 : height;
  }

  double? _weightToKg() {
    if (weightController.text.trim().isEmpty) return null;
    final weight = _toDouble(weightController.text);
    return weightUnit == "lb" ? weight * 0.453592 : weight;
  }

  Future<void> updateProfile() async {
    setState(() => isLoading = true);

    try {
      final response = await ApiService.updateProfile(
        profileId: widget.profileId,
        height: _heightToCm(),
        weight: _weightToKg(),
        gender: selectedGender,
        password: passwordController.text.trim().isEmpty
            ? null
            : passwordController.text.trim(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Profile measurements updated instantly!"),
            backgroundColor: Color(0xFF16A34A),
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context, response);
      }
    } catch (e) {
      if (mounted) {
        setState(() => message = e.toString());
      }
    }

    if (mounted) {
      setState(() => isLoading = false);
    }
  }

  Widget textInput({
    required String label,
    required TextEditingController controller,
    bool obscure = false,
    Widget? suffixIcon,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          suffixIcon: suffixIcon,
        ),
      ),
    );
  }

  Widget unitDropdown({
    required String value,
    required List<String> items,
    required Function(String) onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          icon: const Icon(Icons.arrow_drop_down, color: Colors.black54),
          dropdownColor: Colors.white,
          items: items.map((item) {
            return DropdownMenuItem(
              value: item,
              child: Text(item, style: const TextStyle(fontWeight: FontWeight.bold)),
            );
          }).toList(),
          onChanged: (newValue) {
            if (newValue != null) onChanged(newValue);
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          "Update Body Profile",
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              "Body Metrics",
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              "Update your physical measurements so our AI can recalculate your bespoke sizes.",
              style: TextStyle(fontSize: 16, color: Colors.black54),
            ),
            const SizedBox(height: 32),

            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: textInput(
                    label: "Height",
                    controller: heightController,
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 12),
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: unitDropdown(
                    value: heightUnit,
                    items: const ["cm", "inch"],
                    onChanged: (value) => setState(() => heightUnit = value),
                  ),
                ),
              ],
            ),

            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: textInput(
                    label: "Weight",
                    controller: weightController,
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 12),
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: unitDropdown(
                    value: weightUnit,
                    items: const ["kg", "lb"],
                    onChanged: (value) => setState(() => weightUnit = value),
                  ),
                ),
              ],
            ),

            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: DropdownButtonFormField<String>(
                value: selectedGender,
                decoration: InputDecoration(
                  labelText: "Gender",
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                dropdownColor: Colors.white,
                items: genderOptions.map((gender) {
                  return DropdownMenuItem(value: gender, child: Text(gender));
                }).toList(),
                onChanged: (value) => setState(() => selectedGender = value),
              ),
            ),

            const Divider(height: 40),
            
            const Text(
              "Security",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 16),
            textInput(
              label: "New Password (Optional)",
              controller: passwordController,
              obscure: !showPassword,
              suffixIcon: IconButton(
                icon: Icon(showPassword ? Icons.visibility : Icons.visibility_off, color: Colors.grey),
                onPressed: () => setState(() => showPassword = !showPassword),
              ),
            ),

            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: isLoading ? null : updateProfile,
                child: isLoading
                    ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white))
                    : const Text("Save Changes", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
              ),
            ),

            if (message.isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEE2E2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(message, style: const TextStyle(color: Colors.red)),
              ),
            ]
          ],
        ),
      ),
    );
  }
}