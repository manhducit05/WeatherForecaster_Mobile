import 'package:flutter/material.dart';

class RoutesSelector extends StatelessWidget {
  final List<Map<String, dynamic>> routes;
  final int selectedIndex;
  final Function(int) onSelect;

  const RoutesSelector({
    super.key,
    required this.routes,
    required this.selectedIndex,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 6,
      borderRadius: BorderRadius.circular(12),
      color: Colors.white,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(routes.length, (i) {
              final route = routes[i];

              // ✅ LẤY ĐÚNG DỮ LIỆU
              final legs = route["legs"] as List<dynamic>?;
              final leg = legs != null && legs.isNotEmpty ? legs.first : null;

              final distanceText = leg?["distance"]?["text"] ?? "N/A";
              final durationText = leg?["duration"]?["text"] ?? "";

              return GestureDetector(
                onTap: () => onSelect(i),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: selectedIndex == i ? Colors.blue : Colors.grey[300],
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    "$distanceText • $durationText",
                    style: TextStyle(
                      color: selectedIndex == i ? Colors.white : Colors.black87,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}
