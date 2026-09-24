import 'package:flutter/material.dart';

/// GlobalKey statis untuk setiap step Product Tour.
/// Menggunakan static agar dapat diakses dari HomeScreen, MainShellScreen & SettingsScreen.
class ProductTourKeys {
  ProductTourKeys._();

  // ── Fase 1: Beranda (Step 1) ──
  static GlobalKey balanceCard = GlobalKey(debugLabel: 'tour_balance_card');

  // ── Fase 2: Pengaturan & Modal Setup AI (Step 2-9) ──
  static GlobalKey navPengaturan = GlobalKey(debugLabel: 'tour_nav_pengaturan');
  static GlobalKey settingsAiKey = GlobalKey(
    debugLabel: 'tour_settings_ai_key',
  );
  static GlobalKey modalGeminiBtn = GlobalKey(
    debugLabel: 'tour_modal_gemini_btn',
  );
  static GlobalKey modalGeminiInput = GlobalKey(
    debugLabel: 'tour_modal_gemini_input',
  );
  static GlobalKey settingsCategory = GlobalKey(
    debugLabel: 'tour_settings_category',
  );
  static GlobalKey settingsNotification = GlobalKey(
    debugLabel: 'tour_settings_notification',
  );

  // ── Fase 3: Fitur Utama Beranda (Step 10-14) ──
  static GlobalKey navBeranda = GlobalKey(debugLabel: 'tour_nav_beranda');
  static GlobalKey dashboardChart = GlobalKey(
    debugLabel: 'tour_dashboard_chart',
  );
  static GlobalKey aiSmartInput = GlobalKey(debugLabel: 'tour_ai_smart_input');
  static GlobalKey recentTx = GlobalKey(debugLabel: 'tour_recent_transactions');

  // ── Fase 4: Navigasi (Step 15-17) ──
  static GlobalKey navNomiAI = GlobalKey(debugLabel: 'tour_nav_nomi_ai');
  static GlobalKey navTambah = GlobalKey(debugLabel: 'tour_nav_tambah');
  static GlobalKey navLaporan = GlobalKey(debugLabel: 'tour_nav_laporan');

  static void refreshKeys() {
    balanceCard = GlobalKey(debugLabel: 'tour_balance_card');
    navPengaturan = GlobalKey(debugLabel: 'tour_nav_pengaturan');
    settingsAiKey = GlobalKey(debugLabel: 'tour_settings_ai_key');
    modalGeminiBtn = GlobalKey(debugLabel: 'tour_modal_gemini_btn');
    modalGeminiInput = GlobalKey(debugLabel: 'tour_modal_gemini_input');
    settingsCategory = GlobalKey(debugLabel: 'tour_settings_category');
    settingsNotification = GlobalKey(debugLabel: 'tour_settings_notification');
    navBeranda = GlobalKey(debugLabel: 'tour_nav_beranda');
    dashboardChart = GlobalKey(debugLabel: 'tour_dashboard_chart');
    aiSmartInput = GlobalKey(debugLabel: 'tour_ai_smart_input');
    recentTx = GlobalKey(debugLabel: 'tour_recent_transactions');
    navNomiAI = GlobalKey(debugLabel: 'tour_nav_nomi_ai');
    navTambah = GlobalKey(debugLabel: 'tour_nav_tambah');
    navLaporan = GlobalKey(debugLabel: 'tour_nav_laporan');
  }

  /// Urutan lengkap 17 tour steps
  static List<GlobalKey> get orderedKeys => [
    balanceCard, // Step 1
    navPengaturan, // Step 2
    settingsAiKey, // Step 3
    modalGeminiBtn, // Step 4  (modal terbuka di step ini)
    modalGeminiInput, // Step 5
    settingsCategory, // Step 8  (modal ditutup di step ini)
    settingsNotification, // Step 9
    navBeranda, // Step 10
    dashboardChart, // Step 11
    aiSmartInput, // Step 12
    recentTx, // Step 13
    navNomiAI, // Step 14
    navTambah, // Step 15
    navLaporan, // Step 16
  ];
}
