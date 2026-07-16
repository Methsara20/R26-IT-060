import 'package:flutter/material.dart';

import 'widgets/sidebar.dart';
import 'widgets/prediction_form.dart';
import 'widgets/result_section.dart';
import 'widgets/chatbot_panel.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int selectedIndex = 0;

  Map<String, dynamic>? predictionResult;

  //  Prediction state
  bool isPredictionReady = false;

  //  BUILD CHAT CONTEXT

  Map<String, dynamic>? buildChatContext() {
    if (!isPredictionReady || predictionResult == null) {
      return null;
    }

    return {
      "predicted_demand": predictionResult?["predicted_demand"],

      "confidence": predictionResult?["confidence"],

      "brand": predictionResult?["payload"]?["brand"],

      "gender": predictionResult?["payload"]?["gender"],

      "subcategory": predictionResult?["payload"]?["subcategory"],

      "status": predictionResult?["status"],

      "action": predictionResult?["action"],

      "current_stock": predictionResult?["current_stock"],

      "from_store": predictionResult?["from_store"],

      "transfer_qty": predictionResult?["transfer_qty"],

      "forecast_7_days": predictionResult?["forecast_7_days"],

      "forecast_7_days_list": predictionResult?["forecast_7_days_list"],

      "trend": predictionResult?["trend"],

      "payload": predictionResult?["payload"],

      "explanation": predictionResult?["explanation"],
    };
  }

  //  DASHBOARD KPI CARD

  Widget dashboardCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(18),

        decoration: BoxDecoration(
          color: Colors.white,

          borderRadius: BorderRadius.circular(18),

          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),

              blurRadius: 16,

              offset: const Offset(0, 8),
            ),
          ],
        ),

        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,

          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,

              children: [
                Text(
                  title,

                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w600,
                  ),
                ),

                Container(
                  padding: const EdgeInsets.all(8),

                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),

                    borderRadius: BorderRadius.circular(10),
                  ),

                  child: Icon(icon, color: color, size: 18),
                ),
              ],
            ),

            const SizedBox(height: 16),

            Text(
              value,

              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Color(0xFF111827),
              ),
            ),
          ],
        ),
      ),
    );
  }

  //  HEADER

  Widget buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),

      decoration: BoxDecoration(
        color: Colors.white,

        borderRadius: BorderRadius.circular(20),

        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),

            blurRadius: 20,

            offset: const Offset(0, 8),
          ),
        ],
      ),

      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,

        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,

            children: [
              const Text(
                "Smart Inventory & Stock Flow Optimization",

                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF111827),
                ),
              ),

              const SizedBox(height: 4),

              Text(
                "AI-powered retail demand forecasting dashboard",

                style: TextStyle(color: Colors.grey[600], fontSize: 13),
              ),
            ],
          ),

          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),

                decoration: BoxDecoration(
                  color: const Color(0xFFDCFCE7),

                  borderRadius: BorderRadius.circular(14),
                ),

                child: const Row(
                  children: [
                    CircleAvatar(radius: 4, backgroundColor: Color(0xFF16A34A)),

                    SizedBox(width: 8),

                    Text(
                      "AI Forecast Engine Active",

                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,

                        color: Color(0xFF166534),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 12),

              Container(
                padding: const EdgeInsets.all(10),

                decoration: BoxDecoration(
                  color: Colors.grey.shade100,

                  borderRadius: BorderRadius.circular(12),
                ),

                child: const Icon(Icons.notifications_none, size: 22),
              ),
            ],
          ),
        ],
      ),
    );
  }

  //  PAGE CONTENT

  Widget getContent() {
    switch (selectedIndex) {
      //  DASHBOARD OVERVIEW

      case 0:
        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,

            children: [
              buildHeader(),

              const SizedBox(height: 24),

              // KPI ROW
              Row(
                children: [
                  dashboardCard(
                    title: "Active Stores",

                    value: "3",

                    icon: Icons.storefront_outlined,

                    color: const Color(0xFF2563EB),
                  ),

                  const SizedBox(width: 16),

                  dashboardCard(
                    title: "Tracked Products",

                    value: "250",

                    icon: Icons.inventory_2_outlined,

                    color: const Color(0xFF7C3AED),
                  ),

                  const SizedBox(width: 16),

                  dashboardCard(
                    title: "AI Accuracy",

                    value: "92%",

                    icon: Icons.analytics_outlined,

                    color: const Color(0xFF16A34A),
                  ),

                  const SizedBox(width: 16),

                  dashboardCard(
                    title: "Forecast Status",

                    value: "LIVE",

                    icon: Icons.bolt_outlined,

                    color: const Color(0xFFD97706),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              //  INVENTORY KPI ROW
              Row(
                children: [
                  dashboardCard(
                    title: "Stock Out %",

                    value: "12%",

                    icon: Icons.warning_amber_rounded,

                    color: const Color(0xFFDC2626),
                  ),

                  const SizedBox(width: 16),

                  dashboardCard(
                    title: "Days On Hand",

                    value: "8 Days",

                    icon: Icons.access_time_rounded,

                    color: const Color(0xFF2563EB),
                  ),

                  const SizedBox(width: 16),

                  dashboardCard(
                    title: "Closing Inventory",

                    value: "145",

                    icon: Icons.inventory_2_outlined,

                    color: const Color(0xFF7C3AED),
                  ),

                  const SizedBox(width: 16),

                  dashboardCard(
                    title: "Stock Health",

                    value: "Healthy",

                    icon: Icons.favorite_outline,

                    color: const Color(0xFF16A34A),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              //  PRODUCT ACTIVITY ROW
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(22),

                      decoration: BoxDecoration(
                        color: Colors.white,

                        borderRadius: BorderRadius.circular(20),

                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),

                            blurRadius: 20,

                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),

                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(14),

                            decoration: BoxDecoration(
                              color: const Color(0xFFDBEAFE),

                              borderRadius: BorderRadius.circular(14),
                            ),

                            child: const Icon(
                              Icons.local_mall_outlined,

                              color: Color(0xFF2563EB),

                              size: 24,
                            ),
                          ),

                          const SizedBox(width: 18),

                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,

                            children: [
                              Text(
                                "Active Styles",

                                style: TextStyle(
                                  color: Colors.grey[600],

                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),

                              const SizedBox(height: 6),

                              const Text(
                                "182",

                                style: TextStyle(
                                  fontSize: 30,
                                  fontWeight: FontWeight.bold,

                                  color: Color(0xFF111827),
                                ),
                              ),

                              const SizedBox(height: 4),

                              const Text(
                                "Products currently moving",

                                style: TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF6B7280),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Welcome card

              // Welcome card
              Container(
                width: double.infinity,

                padding: const EdgeInsets.all(28),

                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1E3A5F), Color(0xFF2563EB)],
                  ),

                  borderRadius: BorderRadius.circular(24),
                ),

                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,

                  children: [
                    const Text(
                      "AI Retail Intelligence Platform",

                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),

                    const SizedBox(height: 12),

                    const Text(
                      "Monitor inventory movement, forecast future demand, and optimize stock flow using machine learning and AI-driven retail analytics.",

                      style: TextStyle(
                        fontSize: 14,
                        height: 1.7,
                        color: Colors.white70,
                      ),
                    ),

                    const SizedBox(height: 24),

                    Row(
                      children: [
                        _miniStatus("Demand AI", "ACTIVE"),

                        const SizedBox(width: 14),

                        _miniStatus("Forecasting", "LIVE"),

                        const SizedBox(width: 14),

                        _miniStatus("Chat Assistant", "READY"),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );

      //  PREDICTION PAGE

      case 1:
        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,

            children: [
              buildHeader(),

              const SizedBox(height: 24),

              PredictionForm(
                onResult: (data) {
                  setState(() {
                    if (data.isEmpty) {
                      predictionResult = null;

                      isPredictionReady = false;
                    } else {
                      predictionResult = data;

                      isPredictionReady = true;
                    }
                  });
                },
              ),

              const SizedBox(height: 24),

              ResultSection(result: predictionResult),

              const SizedBox(height: 24),

              ChatbotPanel(
                key: ValueKey(
                  isPredictionReady.toString() + predictionResult.toString(),
                ),

                context: buildChatContext(),

                isActive: isPredictionReady,
              ),
            ],
          ),
        );

      //  REPORTS

      case 2:
        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,

            children: [
              buildHeader(),

              const SizedBox(height: 24),

              Container(
                width: double.infinity,

                padding: const EdgeInsets.all(40),

                decoration: BoxDecoration(
                  color: Colors.white,

                  borderRadius: BorderRadius.circular(24),

                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),

                      blurRadius: 20,

                      offset: const Offset(0, 8),
                    ),
                  ],
                ),

                child: const Column(
                  children: [
                    Icon(Icons.bar_chart, size: 70, color: Color(0xFF2563EB)),

                    SizedBox(height: 18),

                    Text(
                      "Advanced Reports Coming Soon",

                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    SizedBox(height: 10),

                    Text(
                      "Inventory analytics, AI insights, and forecasting reports will be available in future versions.",
                      textAlign: TextAlign.center,

                      style: TextStyle(height: 1.6, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );

      // CHAT PAGE

      case 3:
        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,

            children: [
              buildHeader(),

              const SizedBox(height: 24),

              ChatbotPanel(
                context: buildChatContext(),

                isActive: isPredictionReady,
              ),
            ],
          ),
        );

      default:
        return const SizedBox();
    }
  }

  //  MINI STATUS CHIP

  Widget _miniStatus(String title, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),

      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),

        borderRadius: BorderRadius.circular(14),
      ),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [
          Text(
            title,

            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),

          const SizedBox(height: 4),

          Text(
            value,

            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  //  MAIN UI

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),

      body: Row(
        children: [
          // SIDEBAR
          Sidebar(
            selectedIndex: selectedIndex,

            onItemSelected: (index) {
              setState(() {
                selectedIndex = index;
              });
            },
          ),

          // MAIN CONTENT
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(24),

              child: getContent(),
            ),
          ),
        ],
      ),
    );
  }
}
