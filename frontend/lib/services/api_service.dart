import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

class ApiService {
  static const String baseUrl = "http://172.20.10.5:8000";

  static Future<Map<String, dynamic>> createProfile({
    required String email,
    required String password,
    required double height,
    required double weight,
    required String gender,
  }) async {
    final response = await http.post(
      Uri.parse("$baseUrl/profile/create"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "email": email,
        "password": password,
        "height": height,
        "weight": weight,
        "gender": gender,
      }),
    );

    return _handleResponse(response);
  }

  static Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final response = await http.post(
      Uri.parse("$baseUrl/profile/login"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"email": email, "password": password}),
    );

    return _handleResponse(response);
  }

  static Future<Map<String, dynamic>> updateProfile({
    required String profileId,
    double? height,
    double? weight,
    String? gender,
    String? password,
  }) async {
    final Map<String, dynamic> data = {};

    if (height != null) data["height"] = height;
    if (weight != null) data["weight"] = weight;
    if (gender != null && gender.isNotEmpty) data["gender"] = gender;
    if (password != null && password.isNotEmpty) data["password"] = password;

    final response = await http.put(
      Uri.parse("$baseUrl/profile/update/$profileId"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode(data),
    );

    return _handleResponse(response);
  }

  static Future<Map<String, dynamic>> deleteProfile(String profileId) async {
    final response = await http.delete(
      Uri.parse("$baseUrl/profile/delete/$profileId"),
      headers: {"Content-Type": "application/json"},
    );

    return _handleResponse(response);
  }

  static Future<Map<String, dynamic>> generateTryOn({
    required XFile humanImage,
    required XFile clothImage,
  }) async {
    final request = http.MultipartRequest(
      "POST",
      Uri.parse("$baseUrl/tryon/generate"),
    );

    final humanBytes = await humanImage.readAsBytes();
    final clothBytes = await clothImage.readAsBytes();

    request.files.add(
      http.MultipartFile.fromBytes(
        "human_image",
        humanBytes,
        filename: humanImage.name,
      ),
    );

    request.files.add(
      http.MultipartFile.fromBytes(
        "cloth_image",
        clothBytes,
        filename: clothImage.name,
      ),
    );

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    return _handleResponse(response);
  }

  static Map<String, dynamic> _handleResponse(http.Response response) {
    final decoded =
        response.body.isNotEmpty &&
            response.headers["content-type"]?.contains("application/json") ==
                true
        ? jsonDecode(response.body)
        : <String, dynamic>{};

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return decoded;
    }

    throw Exception(decoded["detail"] ?? "Something went wrong");
  }
}
