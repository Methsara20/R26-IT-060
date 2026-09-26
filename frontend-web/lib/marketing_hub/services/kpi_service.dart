import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/constants/api_constants.dart';

class KpiService {
  // KPI requests can be slower on the first call while Firestore establishes
  // its connection and the backend loads the trained model into memory.
  static const Duration _readTimeout = Duration(seconds: 60);

  static Future<http.Response> fetchAvailablePeriods() {
    return http.get(Uri.parse('$backendUrl/kpis/available-periods')).timeout(_readTimeout);
  }

  static Future<http.Response> fetchKpis({String? startDate, String? endDate}) {
    final params = <String, String>{};
    if (startDate != null) params['start_date'] = startDate;
    if (endDate != null) params['end_date'] = endDate;
    final uri = Uri.parse('$backendUrl/kpis').replace(queryParameters: params.isEmpty ? null : params);
    return http.get(uri).timeout(_readTimeout);
  }

  static Future<http.Response> generateReport({required String periodType, required List<String> periods}) {
    return http
        .post(
          Uri.parse('$backendUrl/reports/generate'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({
            'period_type': periodType,
            'periods': periods,
          }),
        )
        .timeout(const Duration(seconds: 60));
  }
}
