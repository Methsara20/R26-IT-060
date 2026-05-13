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

    setState(() => isLoading = false);
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
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        obscureText: obscure,
        keyboardType: keyboardType,
        validator: validator,
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
        title: const Text("Create Profile"),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Card(
          elevation: 3,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
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
                        showPassword
                            ? Icons.visibility
                            : Icons.visibility_off,
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
                        showConfirmPassword
                            ? Icons.visibility
                            : Icons.visibility_off,
                      ),
                      onPressed: () {
                        setState(
                          () => showConfirmPassword = !showConfirmPassword,
                        );
                      },
                    ),
                  ),

                  Row(
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
                          validator: (value) =>
                              validateNumber(value, "weight"),
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
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return "Please select gender";
                        }
                        return null;
                      },
                    ),
                  ),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: isLoading ? null : createProfile,
                      child: const Text("Create Profile"),
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
      ),
    );
  }
}