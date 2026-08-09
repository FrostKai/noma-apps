import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final productTourTriggerProvider = StateProvider<int>((ref) => 0);

class ProductTourService {
  static const String _keyHasSeenTour = 'has_seen_product_tour';

  /// Cek apakah user sudah melihat product tour
  static Future<bool> hasSeenTour() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyHasSeenTour) ?? false;
  }

  /// Tandai product tour sebagai selesai
  static Future<void> markTourAsCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyHasSeenTour, true);
  }

  /// Reset tour (untuk tombol "Ulangi Tour" di Settings)
  static Future<void> resetTour() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyHasSeenTour);
  }
}
