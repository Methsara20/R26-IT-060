import 'package:http/http.dart' as http;
import '../core/constants/api_constants.dart';

class CustomerService {
  static Future<http.Response> fetchCustomerIntelligence({required int atRiskDays}) {
    return http
        .get(Uri.parse('$backendUrl/customer-intelligence?at_risk_days=$atRiskDays'))
        .timeout(const Duration(seconds: 15));
  }
}
