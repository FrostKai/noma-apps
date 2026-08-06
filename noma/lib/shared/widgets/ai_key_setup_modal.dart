import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
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
      enableDrag: true,
      isDismissible: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => AiKeySetupModal(onKeySaved: onKeySaved),
    );
  }

  @override
  State<AiKeySetupModal> createState() => _AiKeySetupModalState();
}

class _AiKeySetupModalState extends State<AiKeySetupModal> with WidgetsBindingObserver {
  final TextEditingController _groqController = TextEditingController();
  final TextEditingController _geminiController = TextEditingController();

  String? _detectedKeyInClipboard;
  bool _isCheckingClipboard = false;
  bool _isTestingGroq = false;
  bool _isTestingGemini = false;
  bool _isGroqSaved = false;
  bool _isGeminiSaved = false;

  String? _modalToastMessage;
  Color _modalToastColor = AppColors.income;

  void _showModalToast(String msg, {Color color = AppColors.income}) {
    if (!mounted) return;
    setState(() {
      _modalToastMessage = msg;
      _modalToastColor = color;
    });
    Future.delayed(const Duration(seconds: 4), () {
      if (mounted) {
        setState(() {
          _modalToastMessage = null;
        });
      }
    });
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadCurrentKeys();
    _checkClipboardForKey();
  }

  Future<void> _loadCurrentKeys() async {
    final groqKey = await ApiKeyService.getApiKey();
    final geminiKey = await ApiKeyService.getGeminiApiKey();

    if (mounted) {
      setState(() {
        if (groqKey.startsWith('gsk_')) {
          _groqController.text = groqKey;
          _isGroqSaved = true;
        }
        if (geminiKey.isNotEmpty && !geminiKey.startsWith('gsk_')) {
          _geminiController.text = geminiKey;
          _isGeminiSaved = true;
        }
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _groqController.dispose();
    _geminiController.dispose();
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

      if ((text.startsWith('gsk_') && text.length >= 20) ||
          (text.startsWith('AIzaSy') && text.length >= 30) ||
          (text.startsWith('AQ.') && text.length >= 30)) {
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

  Future<void> _saveGroqKey(String key) async {
    final cleanKey = ApiKeyService.sanitizeKey(key);
    if (cleanKey.isEmpty) {
      _showModalToast('Masukkan Groq API Key terlebih dahulu.', color: AppColors.expense);
      return;
    }

    setState(() => _isTestingGroq = true);

    try {
      final dio = Dio(BaseOptions(connectTimeout: const Duration(seconds: 12)));
      final response = await dio.post(
        'https://api.groq.com/openai/v1/chat/completions',
        data: {
          'model': 'llama-3.3-70b-versatile',
          'messages': [
            {'role': 'user', 'content': 'ping'}
          ]
        },
        options: Options(headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $cleanKey',
        }),
      );

      if (response.statusCode == 200) {
        await ApiKeyService.saveApiKey(cleanKey);
        if (!mounted) return;
        setState(() => _isGroqSaved = true);
        _showModalToast('Groq Key Valid & Tersimpan!', color: AppColors.income);
        widget.onKeySaved?.call();
      }
    } catch (e) {
      if (!mounted) return;
      _showModalToast('Error Groq Key: ${e.toString().replaceAll('Exception: ', '')}', color: AppColors.expense);
    } finally {
      if (mounted) setState(() => _isTestingGroq = false);
    }
  }

  Future<void> _saveGeminiKey(String key) async {
    final cleanKey = ApiKeyService.sanitizeKey(key);
    if (cleanKey.isEmpty) {
      _showModalToast('Masukkan Gemini API Key terlebih dahulu.', color: AppColors.expense);
      return;
    }

    setState(() => _isTestingGemini = true);

    try {
      final dio = Dio(BaseOptions(connectTimeout: const Duration(seconds: 10)));
      final encodedKey = Uri.encodeComponent(cleanKey);
      final endpoints = [
        'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=$encodedKey',
        'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=$encodedKey',
        'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=$encodedKey',
      ];

      bool isValid = false;
      for (final url in endpoints) {
        try {
          final response = await dio.post(
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
            options: Options(headers: {
              'Content-Type': 'application/json',
              'x-goog-api-key': cleanKey,
            }),
          );
          if (response.statusCode == 200) {
            isValid = true;
            break;
          }
        } catch (_) {}
      }

      await ApiKeyService.saveGeminiApiKey(cleanKey);
      if (!mounted) return;

      setState(() => _isGeminiSaved = true);
      _showModalToast(isValid ? 'Gemini Key Valid & Tersimpan!' : 'Gemini Key Berhasil Disimpan!', color: AppColors.income);
      widget.onKeySaved?.call();
    } catch (_) {
      await ApiKeyService.saveGeminiApiKey(cleanKey);
      if (!mounted) return;

      setState(() => _isGeminiSaved = true);
      _showModalToast('Gemini Key Berhasil Disimpan!', color: AppColors.income);
      widget.onKeySaved?.call();
    } finally {
      if (mounted) setState(() => _isTestingGemini = false);
    }
  }

  Future<void> _openGroqConsole() async {
    const urlStr = 'https://console.groq.com/keys';
    final Uri uri = Uri.parse(urlStr);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.platformDefault);
      } else {
        await launchUrl(uri);
      }
    } catch (_) {
      try {
        await launchUrlString(urlStr);
      } catch (_) {}
    }
  }

  Future<void> _openGeminiConsole() async {
    const urlStr = 'https://aistudio.google.com/app/apikey';
    final Uri uri = Uri.parse(urlStr);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.platformDefault);
      } else {
        await launchUrl(uri);
      }
    } catch (_) {
      try {
        await launchUrlString(urlStr);
      } catch (_) {}
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
            // Handle Bar & Close Button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const SizedBox(width: 32),
                Container(
                  width: 48,
                  height: 5,
                  decoration: BoxDecoration(
                    color: AppColors.textMuted.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(2.5),
                  ),
                ),
                InkWell(
                  onTap: () => Navigator.of(context).pop(),
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close_rounded,
                      color: AppColors.textSecondary,
                      size: 18,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // PROMINENT IN-MODAL TOAST BANNER (DISPLAYED IN FRONT AT THE VERY TOP OF MODAL)
            if (_modalToastMessage != null) ...[
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                margin: const EdgeInsets.only(bottom: 14),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: _modalToastColor,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: _modalToastColor.withValues(alpha: 0.4),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Icon(
                      _modalToastColor == AppColors.income ? Icons.check_circle_rounded : Icons.error_outline_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _modalToastMessage!,
                        style: AppTypography.labelMedium.copyWith(color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            ],

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
                  child: const Icon(Icons.key_rounded, color: AppColors.primary, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Pengaturan API Key AI', style: AppTypography.headingSmall),
                      Text(
                        'Input Kunci Groq & Gemini Terpisah',
                        style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // Clipboard Auto-Detect Banner
            if (_detectedKeyInClipboard != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.income.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.income.withValues(alpha: 0.5)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.content_paste_rounded, color: AppColors.income, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Kunci Terdeteksi', style: AppTypography.labelMedium.copyWith(color: AppColors.income)),
                          Text(
                            _detectedKeyInClipboard!.startsWith('gsk_') ? 'Format Groq Key' : 'Format Gemini Key',
                            style: AppTypography.caption,
                          ),
                        ],
                      ),
                    ),
                    GlassButton(
                      label: 'Tempel',
                      variant: GlassButtonVariant.income,
                      height: 34,
                      width: 70,
                      onPressed: () {
                        if (_detectedKeyInClipboard!.startsWith('gsk_')) {
                          _groqController.text = _detectedKeyInClipboard!;
                          _saveGroqKey(_detectedKeyInClipboard!);
                        } else {
                          _geminiController.text = _detectedKeyInClipboard!;
                          _saveGeminiKey(_detectedKeyInClipboard!);
                        }
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // 1. INPUT GROQ API KEY SECTION
            GlassCard(
              padding: const EdgeInsets.all(14),
              borderRadius: 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.chat_bubble_outline_rounded, color: AppColors.income, size: 18),
                          const SizedBox(width: 8),
                          Text('1. Groq Key (Chat & Analisis)', style: AppTypography.labelLarge),
                        ],
                      ),
                      InkWell(
                        onTap: _openGroqConsole,
                        child: Text(
                          'Ambil Key',
                          style: AppTypography.caption.copyWith(color: AppColors.primary, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text('Kunci untuk Chatbot Nomi AI & Analisis Finansial (console.groq.com)', style: AppTypography.caption),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _groqController,
                          style: const TextStyle(color: Colors.white, fontSize: 13),
                          onChanged: (val) {
                            if (_isGroqSaved) {
                              setState(() => _isGroqSaved = false);
                            }
                          },
                          decoration: InputDecoration(
                            hintText: 'gsk_...',
                            hintStyle: TextStyle(color: AppColors.textMuted.withValues(alpha: 0.5)),
                            filled: true,
                            fillColor: AppColors.background,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: AppColors.glassBorder),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      GlassButton(
                        label: _isTestingGroq ? '...' : (_isGroqSaved ? 'Tersimpan' : 'Simpan'),
                        variant: _isGroqSaved ? GlassButtonVariant.income : GlassButtonVariant.warning,
                        width: 90,
                        height: 42,
                        onPressed: _isTestingGroq ? null : () => _saveGroqKey(_groqController.text),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // 2. INPUT GEMINI API KEY SECTION
            GlassCard(
              padding: const EdgeInsets.all(14),
              borderRadius: 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.camera_alt_outlined, color: AppColors.primary, size: 18),
                          const SizedBox(width: 8),
                          Text('2. Gemini Key (Scan Struk Foto)', style: AppTypography.labelLarge),
                        ],
                      ),
                      InkWell(
                        onTap: _openGeminiConsole,
                        child: Text(
                          'Ambil Key',
                          style: AppTypography.caption.copyWith(color: AppColors.primary, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text('Kunci penglihatan AI untuk Scan Struk (aistudio.google.com)', style: AppTypography.caption),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _geminiController,
                          style: const TextStyle(color: Colors.white, fontSize: 13),
                          onChanged: (val) {
                            if (_isGeminiSaved) {
                              setState(() => _isGeminiSaved = false);
                            }
                          },
                          decoration: InputDecoration(
                            hintText: 'AIzaSy... atau AQ....',
                            hintStyle: TextStyle(color: AppColors.textMuted.withValues(alpha: 0.5)),
                            filled: true,
                            fillColor: AppColors.background,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: AppColors.glassBorder),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      GlassButton(
                        label: _isTestingGemini ? '...' : (_isGeminiSaved ? 'Tersimpan' : 'Simpan'),
                        variant: _isGeminiSaved ? GlassButtonVariant.income : GlassButtonVariant.warning,
                        width: 90,
                        height: 42,
                        onPressed: _isTestingGemini ? null : () => _saveGeminiKey(_geminiController.text),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}
