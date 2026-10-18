import 'package:http/http.dart' as http;
import '../core/constants/api_constants.dart';

class UploadService {
  static Future<http.Response> fetchHistory() {
    return http.get(Uri.parse('$backendUrl/upload-history')).timeout(const Duration(seconds: 10));
  }

  static Future<http.Response> downloadUpload(String uploadId) {
    return http.get(Uri.parse('$backendUrl/upload/$uploadId/download')).timeout(const Duration(seconds: 15));
  }

  static Future<http.Response> deleteUpload(String uploadId) {
    return http.delete(Uri.parse('$backendUrl/upload/$uploadId')).timeout(const Duration(seconds: 15));
  }

  static Future<http.Response> uploadFile({
    required String fileType,
    required List<int> bytes,
    required String filename,
  }) async {
    final uri = Uri.parse('$backendUrl/upload');
    final request = http.MultipartRequest('POST', uri);
    request.fields['file_type'] = fileType;
    request.files.add(http.MultipartFile.fromBytes('file', bytes, filename: filename));

    final streamedResponse = await request.send().timeout(const Duration(seconds: 60));
    return http.Response.fromStream(streamedResponse);
  }
}
