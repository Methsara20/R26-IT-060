import 'dart:convert';
import 'package:http/http.dart' as http;

class PredictionService {

  static const String baseUrl =
      "http://127.0.0.1:8000";

  
  //  PREDICT
  

  static Future<Map<String, dynamic>>
      predict({

    required String productId,
    required String storeId,
    required int currentStock,
    required double price,
    required double promotionPercent

  }) async {

    final url =
        Uri.parse(
      "$baseUrl/predict-and-decide",
    );

    final response =
        await http.post(

      url,

      headers: {
        "Content-Type":
            "application/json",
      },

      body: jsonEncode({

        "product_id": productId,

        "store_id": storeId,

        "current_stock":
            currentStock,

        "price_lkr": price,

        "promotion_percent":
            promotionPercent,
      }),
    );

    if (response.statusCode == 200) {

      return jsonDecode(response.body);

    } else {

      throw Exception("API Error");
    }
  }

  
  // DROPDOWN DATA
 

  static Future<Map<String, dynamic>>
      getDropdownData() async {

    final response =
        await http.get(
      Uri.parse(
        "$baseUrl/dropdown-data",
      ),
    );

    if (response.statusCode == 200) {

      return jsonDecode(response.body);

    } else {

      throw Exception(
        "Failed to fetch dropdown data",
      );
    }
  }

  
  //  PRODUCT + STORE INFO
  

  static Future<Map<String, dynamic>>
      getProductStoreInfo({

    required String productId,
    required String storeId,

  }) async {

    final response =
        await http.get(

      Uri.parse(
        "$baseUrl/product-store-info"
        "?store_id=$storeId"
        "&product_id=$productId",
      ),
    );

    if (response.statusCode == 200) {

      return jsonDecode(response.body);

    } else {

      throw Exception(
        "Failed to fetch product info",
      );
    }
  }
}