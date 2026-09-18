import 'package:flutter/material.dart';

class ThermoPropertiesGrid extends StatelessWidget {
  final List<Map<String, dynamic>> metrics;

  const ThermoPropertiesGrid({
    super.key,
    required this.metrics,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: Text('Comprehensive Thermodynamic Properties',
                  style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
            ),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 220,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                mainAxisExtent: 70, // Fixed height for tiles instead of aspect ratio
              ),
              itemCount: metrics.length,
              itemBuilder: (context, index) {
                final m = metrics[index];
                return _buildMetricTile(m['title'], m['value'], m['icon'], m['color']);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricTile(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 13),
              const SizedBox(width: 6),
              Expanded(
                child: Text(title,
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.55), fontSize: 10),
                    overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value,
                style: TextStyle(color: color, fontSize: 15, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
