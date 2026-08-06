import 'package:flutter/material.dart';

class RtfMonitorBadge extends StatelessWidget {
  final double rtf;
  final int latencyMs;
  final int prefetchedCount;
  final int prefetchLimit;
  final bool isDark;

  const RtfMonitorBadge({
    Key? key,
    required this.rtf,
    required this.latencyMs,
    required this.prefetchedCount,
    required this.prefetchLimit,
    required this.isDark,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xEC18181B) : const Color(0xECFFFFFF),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.black12,
        ),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.bolt, size: 14, color: Color(0xFF10B981)),
          const SizedBox(width: 4),
          Text(
            'RTF: ${rtf}x',
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: Color(0xFF10B981),
              fontFamily: 'monospace',
            ),
          ),
          const SizedBox(width: 8),
          Text('|', style: TextStyle(color: isDark ? Colors.white24 : Colors.black26)),
          const SizedBox(width: 8),
          const Icon(Icons.speed, size: 14, color: Colors.amber),
          const SizedBox(width: 4),
          Text(
            'Gen: ${latencyMs}ms',
            style: TextStyle(
              fontSize: 10,
              fontFamily: 'monospace',
              color: isDark ? Colors.white70 : Colors.black.withOpacity(0.8),
            ),
          ),
          const SizedBox(width: 8),
          Text('|', style: TextStyle(color: isDark ? Colors.white24 : Colors.black26)),
          const SizedBox(width: 8),
          const Icon(Icons.layers, size: 14, color: Colors.lightBlue),
          const SizedBox(width: 4),
          Text(
            'Buffer: $prefetchedCount/$prefetchLimit Ready',
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: Colors.lightBlue,
              fontFamily: 'monospace',
            ),
          ),
          const SizedBox(width: 8),
          Text('|', style: TextStyle(color: isDark ? Colors.white24 : Colors.black26)),
          const SizedBox(width: 8),
          const Text(
            'Kokoro-82M',
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.bold,
              color: Color(0xFF10B981),
            ),
          ),
        ],
      ),
    );
  }
}
