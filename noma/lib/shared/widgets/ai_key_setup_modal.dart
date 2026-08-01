import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher_string.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/api_key_service.dart';
import '../../core/theme/app_typography.dart';
import 'glass_button.dart';
import 'glass_card.dart';

class AiKeySetupModal extends StatefulWidget {
  final VoidCallback? onKeySaved;

  const AiKeySetupModal({super.key, this.onKeySaved});

  static Future<void> show(BuildContext context, {VoidCallback? onKeySaved}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => AiKeySetupModal(onKeySaved: onKeySaved),
    );
  }

  @override
  State<AiKeySetupModal> createState() => _AiKeySetupModalState();
}

class _AiKeySetupModalState extends State<AiKeySetupModal> with WidgetsBindingObserver {
  final TextEditingController _controller = TextEditingController();
  String? _detectedKeyInClipboard;
  bool _isCheckingClipboard = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadCurrentKey();
    _checkClipboardForKey();
  }

  Future<void> _loadCurrentKey() async {
    final currentKey = await ApiKeyService.getApiKey();
    if (currentKey.isNotEmpty && currentKey != 'your_gemini_api_key_here') {
      if (mounted) {
        setState(() {
          _controller.text = currentKey;
        });
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkClipboardForKey();
    }
  }

  Future<void> _checkClipboardForKey() async {
    if (_isCheckingClipboard) return;
    setState(() => _isCheckingClipboard = true);

    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      final text = data?.text?.trim() ?? '';

      // Gemini API Key format pattern check
      if (text.startsWith('AIzaSy') && text.length >= 35) {
        if (mounted) {
          setState(() {
            _detectedKeyInClipboard = text;
          });
        }
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isCheckingClipboard = false);
    }
  }

  bool _isTesting = false;

  Future<void> _testAndApplyKey(String key) async {
    final cleanKey = ApiKeyService.sanitizeKey(key);
    if (cleanKey.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Masukkan atau tempel API Key terlebih dahulu.'),
          backgroundColor: AppColors.expense,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isTesting = true);

    try {
      final dio = Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 15),
        ),
      );

      Response response;
      if (cleanKey.startsWith('gsk_')) {
        // Test Groq API Key
        response = await dio.post(
          'https://api.groq.com/openai/v1/chat/completions',
          data: {
            'model': 'llama-3.3-70b-versatile',
            'messages': [
              {'role': 'user', 'content': 'ping'}
            ]
          },
          options: Options(
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $cleanKey',
            },
          ),
        );
      } else if (cleanKey.startsWith('sk-or')) {
        // Test OpenRouter API Key
        response = await dio.post(
          'https://openrouter.ai/api/v1/chat/completions',
          data: {
            'model': 'meta-llama/llama-3.3-70b-instruct:free',
            'messages': [
              {'role': 'user', 'content': 'ping'}
            ]
          },
          options: Options(
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $cleanKey',
            },
          ),
        );
      } else {
        // Test Gemini API Key
        final url = 'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=$cleanKey';
        response = await dio.post(
          url,
          data: {
            'contents': [
              {
                'parts': [
                  {'text': 'ping'}
                ]
              }
            ]
          },
          options: Options(
            headers: {
              'Content-Type': 'application/json',
              'x-goog-api-key': cleanKey,
            },
          ),
        );
      }

      if (response.statusCode == 200) {
        await ApiKeyService.saveApiKey(cleanKey);

        if (!mounted) return;
        Navigator.of(context).pop();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle_rounded, color: Colors.white),
                SizedBox(width: 10),
                Expanded(child: Text('API Key Teruji Valid & Berhasil Disimpan! 🚀')),
              ],
            ),
            backgroundColor: AppColors.income,
            behavior: SnackBarBehavior.floating,
          ),
        );

        widget.onKeySaved?.call();
      }
    } on DioException catch (e) {
      if (!mounted) return;
      String errStr = 'Gagal terhubung ke Google AI.';
      final data = e.response?.data;
      if (data is Map && data.containsKey('error')) {
        final errObj = data['error'];
        if (errObj is Map && errObj.containsKey('message')) {
          errStr = errObj['message'].toString();
        }
      } else if (e.message != null) {
        errStr = e.message!;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error Test Key: $errStr'),
          backgroundColor: AppColors.expense,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 6),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: AppColors.expense,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isTesting = false);
    }
  }

  Future<void> _applyKey(String key) async {
    await _testAndApplyKey(key);
  }

  Future<void> _openGoogleAiStudio() async {
    const url = 'https://aistudio.google.com/apikey';
    try {
      await launchUrlString(url, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Buka browser ke: https://aistudio.google.com/apikey'),
          backgroundColor: AppColors.primary,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: bottomInset + 24,
      ),
      decoration: BoxDecoration(
        color: AppColors.backgroundSecondary.withValues(alpha: 0.95),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(color: AppColors.glassBorder, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.2),
            blurRadius: 30,
            spreadRadius: 5,
          ),
        ],
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle Bar
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.glassBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Header Banner
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.primary),
                  ),
                  child: const Icon(Icons.auto_awesome, color: AppColors.primary, size: 26),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Aktifkan Asisten AI Noma', style: AppTypography.headingSmall),
                      Text(
                        '100% Gratis Selamanya dari Google Gemini',
                        style: AppTypography.caption.copyWith(color: AppColors.income),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // AUTO DETECT CLIPBOARD BANNER (Magic UX)
            if (_detectedKeyInClipboard != null) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.income.withValues(alpha: 0.25),
                      AppColors.primary.withValues(alpha: 0.25),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.income, width: 1.5),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.stars_rounded, color: AppColors.income, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Kunci Google Gemini Terdeteksi!',
                          style: AppTypography.labelLarge.copyWith(color: AppColors.income),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Aplikasi mendeteksi salinan kunci dari HP-mu. Tekan tombol di bawah untuk langsung aktifkan.',
                      style: AppTypography.caption,
                    ),
                    const SizedBox(height: 12),
                    GlassButton(
                      label: 'Tempel Otomatis & Aktifkan AI 🚀',
                      icon: Icons.flash_on_rounded,
                      variant: GlassButtonVariant.income,
                      height: 44,
                      onPressed: () => _applyKey(_detectedKeyInClipboard!),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],

            // 3-STEP EASY GUIDED CARDS
            Text('Panduan Mudah 30 Detik:', style: AppTypography.labelMedium),
            const SizedBox(height: 10),

            _buildStepTile(
              stepNum: '1',
              title: 'Dapatkan Kunci Gratis',
              desc: 'Klik tombol di bawah untuk membuka Google AI Studio.',
              child: Padding(
                padding: const EdgeInsets.only(top: 8),
                child: GlassButton(
                  label: '🌐 Ambil Key Gratis dari Google',
                  icon: Icons.open_in_new_rounded,
                  variant: GlassButtonVariant.primary,
                  height: 42,
                  onPressed: _openGoogleAiStudio,
                ),
              ),
            ),
            const SizedBox(height: 10),

            _buildStepTile(
              stepNum: '2',
              title: 'Tekan "Create API Key" lalu Copy',
              desc: 'Login akun Google HP-mu, tekan Create API Key, lalu tekan Copy.',
            ),
            const SizedBox(height: 10),

            _buildStepTile(
              stepNum: '3',
              title: 'Kembali ke Aplikasi Noma',
              desc: 'Kunci akan terdeteksi otomatis! Atau tempel manual di bawah.',
            ),
            const SizedBox(height: 20),

            const Divider(color: AppColors.glassBorder),
            const SizedBox(height: 14),

            // MANUAL PASTE INPUT
            Text('Atau Tempel Kunci Manual:', style: AppTypography.caption),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'AIzaSy...',
                      hintStyle: TextStyle(color: AppColors.textMuted.withValues(alpha: 0.5)),
                      filled: true,
                      fillColor: AppColors.background,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.glassBorder),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                GlassButton(
                  label: _isTesting ? 'Menguji...' : 'Tes & Simpan',
                  variant: GlassButtonVariant.income,
                  width: 110,
                  height: 44,
                  onPressed: _isTesting ? null : () => _applyKey(_controller.text),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepTile({
    required String stepNum,
    required String title,
    required String desc,
    Widget? child,
  }) {
    return GlassCard(
      padding: const EdgeInsets.all(12),
      borderRadius: 14,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: const BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                stepNum,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTypography.labelLarge.copyWith(fontSize: 14)),
                const SizedBox(height: 2),
                Text(desc, style: AppTypography.caption),
                if (child != null) child,
              ],
            ),
          ),
        ],
      ),
    );
  }
}
