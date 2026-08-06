import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../ffi/isolate_bridge.dart';

final isolateBridgeProvider = Provider<CornigrumIsolateBridge>((ref) {
  final bridge = CornigrumIsolateBridge();
  ref.onDispose(() {
    bridge.dispose();
  });
  return bridge;
});
