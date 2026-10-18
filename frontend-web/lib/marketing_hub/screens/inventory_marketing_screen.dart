import 'package:flutter/material.dart';

import 'inventory_analysis_screen.dart';
import 'inventory_screen.dart';

class InventoryMarketingScreen extends StatelessWidget {
  const InventoryMarketingScreen({super.key, this.onCreatePoster});
  final ValueChanged<Map<String, dynamic>>? onCreatePoster;

  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: 2,
    child: Column(
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 8, 20, 4),
          child: TabBar(
            tabs: [
              Tab(
                icon: Icon(Icons.insights_outlined),
                text: 'Inventory Insights',
              ),
              Tab(
                icon: Icon(Icons.fact_check_outlined),
                text: 'Check with Inventory',
              ),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            children: [
              InventoryInsightsScreen(onCreatePoster: onCreatePoster),
              const InventoryAnalysisScreen(),
            ],
          ),
        ),
      ],
    ),
  );
}
