import 'package:flutter/material.dart';

class Sidebar extends StatelessWidget {
  final int selectedIndex;

  final Function(int) onItemSelected;

  const Sidebar({
    super.key,

    required this.selectedIndex,

    required this.onItemSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 270,

      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,

          end: Alignment.bottomCenter,

          colors: [Color(0xFF111827), Color(0xFF1F2937)],
        ),
      ),

      child: Column(
        children: [
          
          // LOGO / BRAND
          
          Container(
            width: double.infinity,

            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 30),

            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),

                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.08),

                    borderRadius: BorderRadius.circular(16),
                  ),

                  child: const Icon(
                    Icons.auto_graph_rounded,

                    color: Colors.white,
                    size: 26,
                  ),
                ),

                const SizedBox(width: 14),

                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,

                    children: [
                      Text(
                        "Smart Retail AI",

                        style: TextStyle(
                          color: Colors.white,

                          fontSize: 18,

                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      SizedBox(height: 4),

                      Text(
                        "Inventory Intelligence",

                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),

          
          //  NAVIGATION
          
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),

              child: Column(
                children: [
                  _navItem(
                    index: 0,

                    title: "Dashboard",

                    icon: Icons.dashboard_outlined,
                  ),

                  _navItem(
                    index: 1,

                    title: "Demand Forecast",

                    icon: Icons.analytics_outlined,
                  ),

                  _navItem(
                    index: 2,

                    title: "Reports",

                    icon: Icons.bar_chart_outlined,
                  ),

                  _navItem(
                    index: 3,

                    title: "AI Assistant",

                    icon: Icons.smart_toy_outlined,
                  ),

                  const SizedBox(height: 20),

                  Divider(color: Colors.white.withOpacity(0.08)),

                  const SizedBox(height: 20),

                  
                  //  AI STATUS CARD
                  
                  Container(
                    width: double.infinity,

                    padding: const EdgeInsets.all(18),

                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),

                      borderRadius: BorderRadius.circular(18),

                      border: Border.all(color: Colors.white.withOpacity(0.06)),
                    ),

                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,

                      children: [
                        Row(
                          children: [
                            Container(
                              width: 10,
                              height: 10,

                              decoration: const BoxDecoration(
                                color: Color(0xFF22C55E),

                                shape: BoxShape.circle,
                              ),
                            ),

                            const SizedBox(width: 8),

                            const Text(
                              "AI Engine Active",

                              style: TextStyle(
                                color: Colors.white,

                                fontWeight: FontWeight.bold,

                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 14),

                        const Text(
                          "Retail forecasting system is currently operational and generating live predictions.",

                          style: TextStyle(
                            color: Colors.white70,

                            height: 1.5,

                            fontSize: 12,
                          ),
                        ),

                        const SizedBox(height: 16),

                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),

                          decoration: BoxDecoration(
                            color: const Color(0xFF2563EB),

                            borderRadius: BorderRadius.circular(10),
                          ),

                          child: const Row(
                            mainAxisSize: MainAxisSize.min,

                            children: [
                              Icon(Icons.bolt, size: 14, color: Colors.white),

                              SizedBox(width: 6),

                              Text(
                                "92% Accuracy",

                                style: TextStyle(
                                  color: Colors.white,

                                  fontWeight: FontWeight.bold,

                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          
          //  FOOTER
          
          Container(
            width: double.infinity,

            padding: const EdgeInsets.all(22),

            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,

                  backgroundColor: Colors.white.withOpacity(0.08),

                  child: const Icon(Icons.person_outline, color: Colors.white),
                ),

                const SizedBox(width: 12),

                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,

                    children: [
                      Text(
                        "Admin User",

                        style: TextStyle(
                          color: Colors.white,

                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      SizedBox(height: 4),

                      Text(
                        "Retail Operations",

                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                ),

                Icon(
                  Icons.logout_rounded,

                  color: Colors.white.withOpacity(0.7),

                  size: 20,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  
  //  NAV ITEM
  

  Widget _navItem({
    required int index,

    required String title,

    required IconData icon,
  }) {
    final isSelected = selectedIndex == index;

    return GestureDetector(
      onTap: () => onItemSelected(index),

      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),

        margin: const EdgeInsets.only(bottom: 10),

        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),

        decoration: BoxDecoration(
          color: isSelected
              ? Colors.white.withOpacity(0.10)
              : Colors.transparent,

          borderRadius: BorderRadius.circular(16),

          border: Border.all(
            color: isSelected
                ? Colors.white.withOpacity(0.12)
                : Colors.transparent,
          ),
        ),

        child: Row(
          children: [
            Icon(
              icon,

              color: isSelected ? Colors.white : Colors.white70,

              size: 22,
            ),

            const SizedBox(width: 14),

            Expanded(
              child: Text(
                title,

                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.white70,

                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,

                  fontSize: 14,
                ),
              ),
            ),

            if (isSelected)
              Container(
                width: 8,
                height: 8,

                decoration: const BoxDecoration(
                  color: Color(0xFF3B82F6),

                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
