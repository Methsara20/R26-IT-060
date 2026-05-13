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
      final result = await ApiService.updateProfile(
        profileId: widget.profileId,
        height: _heightToCm(),
        weight: _weightToKg(),
        gender: selectedGender,
        password: passwordController.text.trim().isEmpty
            ? null
            : passwordController.text.trim(),
      );

      setState(() {
        message =
            "Profile updated successfully. Size: ${result["recommended_size"]}";
      });
    } catch (e) {
      setState(() => message = e.toString());
    }

    setState(() => isLoading = false);
  }

  Widget textInput({
    required String label,
    required TextEditingController controller,
    bool obscure = false,
    Widget? suffixIcon,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
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
    return DropdownButton<String>(
      value: value,
      items: items.map((item) {
        return DropdownMenuItem(
          value: item,
          child: Text(item),
        );
      }).toList(),
      onChanged: (newValue) {
        if (newValue != null) {
          onChanged(newValue);
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text("Update Profile"),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Card(
          elevation: 3,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: textInput(
                        label: "Height",
                        controller: heightController,
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 8),
                    unitDropdown(
                      value: heightUnit,
                      items: const ["cm", "inch"],
                      onChanged: (value) {
                        setState(() => heightUnit = value);
                      },
                    ),
                  ],
                ),

                Row(
                  children: [
                    Expanded(
                      child: textInput(
                        label: "Weight",
                        controller: weightController,
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 8),
                    unitDropdown(
                      value: weightUnit,
                      items: const ["kg", "lb"],
                      onChanged: (value) {
                        setState(() => weightUnit = value);
                      },
                    ),
                  ],
                ),

                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: DropdownButtonFormField<String>(
                    value: selectedGender,
                    decoration: const InputDecoration(
                      labelText: "Gender",
                      border: OutlineInputBorder(),
                    ),
                    items: genderOptions.map((gender) {
                      return DropdownMenuItem(
                        value: gender,
                        child: Text(gender),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() => selectedGender = value);
                    },
                  ),
                ),

                textInput(
                  label: "New Password",
                  controller: passwordController,
                  obscure: !showPassword,
                  suffixIcon: IconButton(
                    icon: Icon(
                      showPassword ? Icons.visibility : Icons.visibility_off,
                    ),
                    onPressed: () {
                      setState(() => showPassword = !showPassword);
                    },
                  ),
                ),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: isLoading ? null : updateProfile,
                    child: const Text("Update Profile"),
                  ),
                ),

                const SizedBox(height: 12),

                if (isLoading) const CircularProgressIndicator(),

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