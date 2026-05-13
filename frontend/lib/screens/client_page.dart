import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'create_profile_page.dart';
import 'update_profile_page.dart';
import 'delete_profile_page.dart';
import 'try_on_page.dart';

class ClientPage extends StatefulWidget {
  const ClientPage({super.key});

  @override
  State<ClientPage> createState() => _ClientPageState();
}

class _ClientPageState extends State<ClientPage> {
  final _formKey = GlobalKey<FormState>();

  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  bool isLoading = false;
  bool showPassword = false;
  bool isLoggedIn = false;

  String resultMessage = "";
  String? profileId;
  String? token;
  String? loggedEmail;

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
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

  Future<void> login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => isLoading = true);

    try {
      final result = await ApiService.login(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );

      setState(() {
        profileId = result["profile_id"];
        token = result["access_token"];
        loggedEmail = result["email"];
        isLoggedIn = true;
        resultMessage = "Login successful";
      });
    } catch (e) {
      setState(() => resultMessage = e.toString());
    }

    setState(() => isLoading = false);
  }

  void logout() {
    setState(() {
      isLoggedIn = false;
      profileId = null;
      token = null;
      loggedEmail = null;
      passwordController.clear();
      resultMessage = "Logged out";
    });
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

  Widget buildLoginForm() {
    return Card(
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              const Text(
                "Client Login",
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 16),

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
                  ),
                  onPressed: () {
                    setState(() => showPassword = !showPassword);
                  },
                ),
              ),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: isLoading ? null : login,
                  child: const Text("Login"),
                ),
              ),

              const SizedBox(height: 12),

              TextButton(
                onPressed: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const CreateProfilePage(),
                    ),
                  );

                  if (result != null && result is Map<String, dynamic>) {
                    setState(() {
                      profileId = result["profile_id"];
                      loggedEmail = result["email"];
                      isLoggedIn = true;

                      final body = result["body_measurements"];

                      resultMessage =
                          "Profile created successfully.\n\n"
                          "Recommended Size: ${result["recommended_size"]}\n\n"
                          "Predicted Body Measurements\n"
                          "----------------------------------\n"
                          "Shoulder Width: ${body["predicted_shoulder_width"]}\n"
                          "Waist: ${body["predicted_waist"]}\n"
                          "Leg Length: ${body["predicted_leg_length"]}";
                    });
                  }
                },
                child: const Text("Don't have a profile? Create profile"),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget buildHomeContent() {
    return Card(
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Icon(
              Icons.person,
              size: 70,
              color: Colors.blue,
            ),

            const SizedBox(height: 12),

            const Text(
              "Welcome to Recommendation System",
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 12),

            Text(
              "Logged in as $loggedEmail",
              style: const TextStyle(fontWeight: FontWeight.w500),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 20),

            const Text(
              "Your profile is ready. You can now continue to the clothing recommendation process.",
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const TryOnPage(),
                    ),
                  );
                },
                icon: const Icon(Icons.checkroom),
                label: const Text("Start Virtual Try-On"),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text("Client Recommendation Profile"),
        centerTitle: true,
        actions: [
          if (isLoggedIn)
            PopupMenuButton<String>(
              onSelected: (value) async {
                if (value == "update") {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => UpdateProfilePage(
                        profileId: profileId!,
                      ),
                    ),
                  );
                } else if (value == "delete") {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => DeleteProfilePage(
                        profileId: profileId!,
                        onDeleted: logout,
                      ),
                    ),
                  );
                } else if (value == "logout") {
                  logout();
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: "update",
                  child: Text("Update Profile"),
                ),
                PopupMenuItem(
                  value: "delete",
                  child: Text("Delete Profile"),
                ),
                PopupMenuItem(
                  value: "logout",
                  child: Text("Logout"),
                ),
              ],
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            isLoggedIn ? buildHomeContent() : buildLoginForm(),

            const SizedBox(height: 16),

            if (isLoading) const CircularProgressIndicator(),

            if (resultMessage.isNotEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(resultMessage),
                ),
              ),
          ],
        ),
      ),
    );
  }
}