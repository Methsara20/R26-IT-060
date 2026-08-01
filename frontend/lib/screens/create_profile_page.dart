import 'package:flutter/material.dart';
import '../services/api_service.dart';

class CreateProfilePage extends StatefulWidget {
  const CreateProfilePage({super.key});

  @override
  State<CreateProfilePage> createState() => _CreateProfilePageState();
}

class _CreateProfilePageState extends State<CreateProfilePage> {
  final _formKey = GlobalKey<FormState>();

  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();
  final heightController = TextEditingController();
  final weightController = TextEditingController();

  String? selectedGender;
  String heightUnit = "cm";
  String weightUnit = "kg";

  bool isLoading = false;
  bool showPassword = false;
  bool showConfirmPassword = false;
  String message = "";

  final List<String> genderOptions = [
    "male",
    "female",
    "prefer not to say",
  ];

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    heightController.dispose();
    weightController.dispose();
    super.dispose();
  }

  double _toDouble(String value) {
    return double.tryParse(value.trim()) ?? 0;
  }

  double _heightToCm() {
    final height = _toDouble(heightController.text);
    return heightUnit == "inch" ? height * 2.54 : height;
  }

  double _weightToKg() {
    final weight = _toDouble(weightController.text);
    return weightUnit == "lb" ? weight * 0.453592 : weight;
  }

  String? validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return "Email is required";
    }

    final emailRegex = RegExp(r'^[\w\.-]+@[\w\.-]+\.\w+$');

    if (!emailRegex.hasMatch(value.trim())) {
      return "Enter a valid email";
    }

    return null;
  }

  String? validatePassword(String? value) {
    if (value == null || value.trim().isEmpty) {
      return "Password is required";
    }

    if (value.trim().length < 8) {
      return "Password must be at least 8 characters";
    }

    return null;
  }

  String? validateConfirmPassword(String? value) {
    if (value != passwordController.text) {
      return "Passwords do not match";
    }

    return null;
  }

  String? validateNumber(String? value, String label) {
    if (value == null || value.trim().isEmpty) {
      return "$label is required";
    }

    if (double.tryParse(value.trim()) == null) {
      return "Enter a valid $label";
    }

    return null;
  }

  Future<void> createProfile() async {
    if (!_formKey.currentState!.validate()) return;

    if (selectedGender == null) {
      setState(() => message = "Please select gender");
      return;
    }

    setState(() => isLoading = true);

    try {
      final result = await ApiService.createProfile(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
        height: _heightToCm(),
        weight: _weightToKg(),
        gender: selectedGender!,
      );

      if (mounted) {
        Navigator.pop(context, result);
      }
    } catch (e) {
      setState(() => message = e.toString());
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
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        obscureText: obscure,
        keyboardType: keyboardType,
        validator: validator,
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
            if (newValue != null) {
              onChanged(newValue);
            }
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
          "Create Profile",
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                "Let's get started",
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                "Create a profile to get AI-powered size recommendations.",
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.black54,
                ),
              ),
              const SizedBox(height: 32),

              textInput(
                label: "Email",
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                validator: validateEmail,
              ),

              textInput(
                label: "Password",
                controller: passwordController,
                obscure: !showPassword,
                validator: validatePassword,
                suffixIcon: IconButton(
                  icon: Icon(
                    showPassword ? Icons.visibility : Icons.visibility_off,
                    color: Colors.grey,
                  ),
                  onPressed: () {
                    setState(() => showPassword = !showPassword);
                  },
                ),
              ),

              textInput(
                label: "Confirm Password",
                controller: confirmPasswordController,
                obscure: !showConfirmPassword,
                validator: validateConfirmPassword,
                suffixIcon: IconButton(
                  icon: Icon(
                    showConfirmPassword ? Icons.visibility : Icons.visibility_off,
                    color: Colors.grey,
                  ),
                  onPressed: () {
                    setState(
                      () => showConfirmPassword = !showConfirmPassword,
                    );
                  },
                ),
              ),

              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: textInput(
                      label: "Height",
                      controller: heightController,
                      keyboardType: TextInputType.number,
                      validator: (value) =>
                          validateNumber(value, "height"),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: unitDropdown(
                      value: heightUnit,
                      items: const ["cm", "inch"],
                      onChanged: (value) {
                        setState(() => heightUnit = value);
                      },
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
                      validator: (value) =>
                          validateNumber(value, "weight"),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: unitDropdown(
                      value: weightUnit,
                      items: const ["kg", "lb"],
                      onChanged: (value) {
                        setState(() => weightUnit = value);
                      },
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
                    return DropdownMenuItem(
                      value: gender,
                      child: Text(gender),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() => selectedGender = value);
                  },
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return "Please select gender";
                    }
                    return null;
                  },
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
                  onPressed: isLoading ? null : createProfile,
                  child: isLoading
                      ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white))
                      : const Text("Create Profile", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                ),
              ),

              const SizedBox(height: 16),

              if (message.isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEE2E2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(message, style: const TextStyle(color: Colors.red)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}