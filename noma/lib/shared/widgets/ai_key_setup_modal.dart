import 'dart:ui';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:showcaseview/showcaseview.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:url_launcher/url_launcher_string.dart';
import '../../core/constants/app_color_scheme.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/product_tour_keys.dart';
import '../../core/services/api_key_service.dart';
import '../../core/services/gemini_api_service.dart';
import '../../core/theme/app_typography.dart';
import 'glass_button.dart';
import 'glass_card.dart';

class AiKeySetupModal extends StatefulWidget {
  final VoidCallback? onKeySaved;
  final VoidCallback? onClose;

  const AiKeySetupModal({super.key, this.onKeySaved, this.onClose});

  /// Tampilkan modal menggunakan OverlayEntry di dalam tree ShowCaseWidget
  /// sehingga Showcase key di dalamnya bisa ditemukan oleh ShowcaseView.
  static OverlayEntry? _overlayEntry;

  static void show(BuildContext context, {VoidCallback? onKeySaved}) {
    // Cegah double-show
    if (_overlayEntry != null) return;
    final overlayState = Overlay.of(context);
    _overlayEntry = OverlayEntry(
      builder: (ctx) => AiKeySetupModal(
        onKeySaved: onKeySaved,
        onClose: () {
          _overlayEntry?.remove();
          _overlayEntry = null;
        },
      ),
    );
    overlayState.insert(_overlayEntry!);
  }

  static void dismiss() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  @override
  State<AiKeySetupModal> createState() => _AiKeySetupModalState();
}

class _AiKeySetupModalState extends State<AiKeySetupModal>
    with WidgetsBindingObserver {
  final TextEditingController _groqController = TextEditingController();
  final TextEditingController _geminiController = TextEditingController();

  String? _detectedKeyInClipboard;
  bool _isCheckingClipboard = false;
  bool _isTestingGroq = false;
  bool _isTestingGemini = false;
  bool _isGroqSaved = false;
  bool _isGeminiSaved = false;
  bool _obscureGroq = true;
  bool _obscureGemini = true;

  double _dragOffset = 0.0;

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
      _showModalToast(
        'Masukkan Groq API Key terlebih dahulu.',
        color: AppColors.expense,
      );
      return;
    }

    if (cleanKey.startsWith('AIzaSy') || cleanKey.startsWith('AQ.')) {
      _showModalToast(
        'Ini Kunci Gemini. Pasang di kolom Gemini di bawah.',
        color: AppColors.warning,
      );
      return;
    }

    setState(() => _isTestingGroq = true);

    try {
      final dio = Dio(BaseOptions(connectTimeout: const Duration(seconds: 12)));
      final response = await dio.post(
        'https://api.groq.com/openai/v1/chat/completions',
        data: {
          'model': GeminiApiService.groqTextModel,
          'messages': [
            {'role': 'user', 'content': 'ping'},
          ],
        },
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $cleanKey',
          },
        ),
      );

      if (response.statusCode == 200) {
        await ApiKeyService.saveApiKey(cleanKey);
        if (!mounted) return;
        setState(() => _isGroqSaved = true);
        _showModalToast('Groq Key Valid & Tersimpan!', color: AppColors.income);
        widget.onKeySaved?.call();
      }
    } on DioException catch (e) {
      if (!mounted) return;
      String errMsg = 'Gagal verifikasi Groq Key.';
      if (e.response?.statusCode == 401 || e.response?.statusCode == 403) {
        errMsg =
            'API Key Groq tidak valid. Periksa kembali kunci dari console.groq.com';
      } else if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.connectionError) {
        errMsg = 'Koneksi timeout. Menyimpan kunci Groq secara lokal...';
        await ApiKeyService.saveApiKey(cleanKey);
        setState(() => _isGroqSaved = true);
        _showModalToast('Groq Key Tersimpan!', color: AppColors.income);
        widget.onKeySaved?.call();
        return;
      }
      _showModalToast(errMsg, color: AppColors.expense);
    } catch (e) {
      if (!mounted) return;
      _showModalToast(
        'Error Groq Key: ${e.toString().replaceAll('Exception: ', '')}',
        color: AppColors.expense,
      );
    } finally {
      if (mounted) setState(() => _isTestingGroq = false);
    }
  }

  Future<void> _saveGeminiKey(String key) async {
    final cleanKey = ApiKeyService.sanitizeKey(key);
    if (cleanKey.isEmpty) {
      _showModalToast(
        'Masukkan Gemini API Key terlebih dahulu.',
        color: AppColors.expense,
      );
      return;
    }

    if (cleanKey.startsWith('gsk_')) {
      _showModalToast(
        'Ini Kunci Groq. Pasang di kolom Groq di atas.',
        color: AppColors.warning,
      );
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
                    {'text': 'ping'},
                  ],
                },
              ],
            },
            options: Options(
              headers: {
                'Content-Type': 'application/json',
                'x-goog-api-key': cleanKey,
              },
            ),
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
      _showModalToast(
        isValid
            ? 'Gemini Key Valid & Tersimpan!'
            : 'Gemini Key Berhasil Disimpan!',
        color: AppColors.income,
      );
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

  Future<void> _clearGroqKey() async {
    await ApiKeyService.saveApiKey('');
    _groqController.clear();
    setState(() => _isGroqSaved = false);
    _showModalToast('Groq Key berhasil dihapus', color: AppColors.warning);
  }

  Future<void> _clearGeminiKey() async {
    await ApiKeyService.saveGeminiApiKey('');
    _geminiController.clear();
    setState(() => _isGeminiSaved = false);
    _showModalToast('Gemini Key berhasil dihapus', color: AppColors.warning);
  }

  Future<void> _openGroqConsole() async {
    const urlStr = 'https://console.groq.com/keys';
    final Uri uri = Uri.parse(urlStr);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        await launchUrl(uri);
      }
    } catch (_) {
      try {
        await launchUrlString(urlStr, mode: LaunchMode.externalApplication);
      } catch (_) {}
    }
  }

  Future<void> _openGeminiConsole() async {
    const urlStr = 'https://aistudio.google.com/app/apikey';
    final Uri uri = Uri.parse(urlStr);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        await launchUrl(uri);
      }
    } catch (_) {
      try {
        await launchUrlString(urlStr, mode: LaunchMode.externalApplication);
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColorScheme.of(context);
    final screenHeight = MediaQuery.of(context).size.height;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final maxModalHeight = (screenHeight - bottomInset) * 0.88;

    return Material(
      type: MaterialType.transparency,
      child: Stack(
        children: [
          // Glass Scrim — tap to dismiss
          Positioned.fill(
            child: GestureDetector(
              onTap: widget.onClose,
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                child: Container(color: Colors.black.withValues(alpha: 0.6)),
              ),
            ),
          ),
          // Modal panel pinned to bottom (elevates with keyboard & supports drag-down to dismiss)
          Positioned(
            bottom: bottomInset,
            left: 0,
            right: 0,
            child: GestureDetector(
              onVerticalDragUpdate: (details) {
                if (details.primaryDelta != null && details.primaryDelta! > 0) {
                  setState(() {
                    _dragOffset += details.primaryDelta!;
                  });
                } else if (details.primaryDelta != null &&
                    details.primaryDelta! < 0 &&
                    _dragOffset > 0) {
                  setState(() {
                    _dragOffset = (_dragOffset + details.primaryDelta!).clamp(
                      0.0,
                      500.0,
                    );
                  });
                }
              },
              onVerticalDragEnd: (details) {
                if (_dragOffset > 90 || (details.primaryVelocity ?? 0) > 250) {
                  widget.onClose?.call();
                } else {
                  setState(() {
                    _dragOffset = 0.0;
                  });
                }
              },
              child: Transform.translate(
                offset: Offset(0, _dragOffset),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: maxModalHeight.clamp(280.0, screenHeight * 0.88),
                  ),
                  child: Container(
                    padding: const EdgeInsets.only(
                      left: 20,
                      right: 20,
                      top: 16,
                      bottom: 20,
                    ),
                    decoration: BoxDecoration(
                      color: colors.backgroundSecondary.withValues(alpha: 0.98),
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(28),
                      ),
                      border: Border.all(color: colors.glassBorder, width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: AppColorScheme.isLight(context)
                              ? Colors.black.withValues(alpha: 0.1)
                              : AppColors.primary.withValues(alpha: 0.25),
                          blurRadius: 35,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: SingleChildScrollView(
                      physics: const ClampingScrollPhysics(),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Center Handle Bar
                          Center(
                            child: Container(
                              width: 48,
                              height: 5,
                              margin: const EdgeInsets.only(bottom: 12),
                              decoration: BoxDecoration(
                                color: colors.textMuted.withValues(alpha: 0.6),
                                borderRadius: BorderRadius.circular(2.5),
                              ),
                            ),
                          ),

                          // Toast Banner
                          if (_modalToastMessage != null) ...[
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 250),
                              margin: const EdgeInsets.only(bottom: 14),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: _modalToastColor,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: _modalToastColor.withValues(
                                      alpha: 0.4,
                                    ),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    _modalToastColor == AppColors.income
                                        ? Icons.check_circle_rounded
                                        : (_modalToastColor == AppColors.warning
                                              ? Icons.warning_amber_rounded
                                              : Icons.error_outline_rounded),
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      _modalToastMessage!,
                                      style: AppTypography.labelMedium.copyWith(
                                        color: Colors.white,
                                      ),
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
                                  color: AppColors.primary.withValues(
                                    alpha: 0.2,
                                  ),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: AppColors.primary),
                                ),
                                child: const Icon(
                                  Icons.key_rounded,
                                  color: AppColors.primary,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Pengaturan API Key AI',
                                      style: AppTypography.headingSmall
                                          .copyWith(color: colors.textPrimary),
                                    ),
                                    Text(
                                      'Input Kunci Groq & Gemini Terpisah',
                                      style: AppTypography.caption.copyWith(
                                        color: colors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Clipboard Auto-Detect Banner
                          if (_detectedKeyInClipboard != null) ...[
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppColors.income.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: AppColors.income.withValues(
                                    alpha: 0.5,
                                  ),
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.content_paste_rounded,
                                    color: AppColors.income,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Kunci Terdeteksi dari Clipboard',
                                          style: AppTypography.labelMedium
                                              .copyWith(
                                                color: AppColors.income,
                                              ),
                                        ),
                                        Text(
                                          _detectedKeyInClipboard!.startsWith(
                                                'gsk_',
                                              )
                                              ? 'Format Groq Key (Chatbot & Analisis)'
                                              : 'Format Gemini Key (Scan Struk)',
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
                                      if (_detectedKeyInClipboard!.startsWith(
                                        'gsk_',
                                      )) {
                                        _groqController.text =
                                            _detectedKeyInClipboard!;
                                        _saveGroqKey(_detectedKeyInClipboard!);
                                      } else {
                                        _geminiController.text =
                                            _detectedKeyInClipboard!;
                                        _saveGeminiKey(
                                          _detectedKeyInClipboard!,
                                        );
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
                            padding: const EdgeInsets.all(16),
                            borderRadius: 16,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Row(
                                        children: [
                                          const Icon(
                                            Icons.chat_bubble_outline_rounded,
                                            color: AppColors.income,
                                            size: 18,
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              'Groq Key',
                                              style: AppTypography.labelLarge,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Showcase(
                                      key: ProductTourKeys.modalGroqBtn,
                                      title: '1. Ambil Groq Key Gratis',
                                      description:
                                          'Ketuk tombol ini → console.groq.com terbuka.\n'
                                          'Buat API Key baru gratis lalu salin (copy) kuncinya.',
                                      targetBorderRadius: BorderRadius.circular(
                                        20,
                                      ),
                                      targetPadding: const EdgeInsets.all(4),
                                      tooltipBackgroundColor: const Color(
                                        0xE61A1A2E,
                                      ),
                                      titleTextStyle: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                      ),
                                      descTextStyle: const TextStyle(
                                        color: Color(0xD9FFFFFF),
                                        fontSize: 13,
                                        height: 1.4,
                                      ),
                                      child: InkWell(
                                        borderRadius: BorderRadius.circular(20),
                                        onTap: _openGroqConsole,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 5,
                                          ),
                                          decoration: BoxDecoration(
                                            color: AppColors.primary.withValues(
                                              alpha: 0.15,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              20,
                                            ),
                                            border: Border.all(
                                              color: AppColors.primary
                                                  .withValues(alpha: 0.4),
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                'Ambil Key',
                                                style: AppTypography.caption
                                                    .copyWith(
                                                      color: AppColors.primary,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                              ),
                                              const SizedBox(width: 4),
                                              const Icon(
                                                Icons.open_in_new_rounded,
                                                size: 13,
                                                color: AppColors.primary,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Kunci untuk Chatbot Nomi AI & Analisis Finansial (console.groq.com)',
                                  style: AppTypography.caption,
                                ),
                                const SizedBox(height: 12),
                                Showcase(
                                  key: ProductTourKeys.modalGroqInput,
                                  title: '2. Tempel & Simpan Groq Key',
                                  description:
                                      'Tempelkan kunci gsk_... di kolom ini lalu tekan Simpan.',
                                  targetBorderRadius: BorderRadius.circular(14),
                                  targetPadding: const EdgeInsets.all(2),
                                  tooltipBackgroundColor: const Color(
                                    0xE61A1A2E,
                                  ),
                                  titleTextStyle: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                  descTextStyle: const TextStyle(
                                    color: Color(0xD9FFFFFF),
                                    fontSize: 13,
                                    height: 1.4,
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: TextField(
                                          controller: _groqController,
                                          obscureText: _obscureGroq,
                                          style: TextStyle(
                                            color: colors.textPrimary,
                                            fontSize: 13,
                                          ),
                                          onChanged: (val) {
                                            if (_isGroqSaved) {
                                              setState(
                                                () => _isGroqSaved = false,
                                              );
                                            }
                                          },
                                          decoration: InputDecoration(
                                            hintText: 'gsk_...',
                                            hintStyle: TextStyle(
                                              color: colors.textMuted
                                                  .withValues(alpha: 0.5),
                                            ),
                                            filled: true,
                                            fillColor: colors.background,
                                            contentPadding:
                                                const EdgeInsets.symmetric(
                                                  horizontal: 12,
                                                  vertical: 10,
                                                ),
                                            suffixIcon: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                if (_groqController
                                                    .text
                                                    .isNotEmpty)
                                                  IconButton(
                                                    icon: Icon(
                                                      Icons.clear_rounded,
                                                      size: 16,
                                                      color: colors.textMuted,
                                                    ),
                                                    onPressed: _clearGroqKey,
                                                  ),
                                                IconButton(
                                                  icon: Icon(
                                                    _obscureGroq
                                                        ? Icons
                                                              .visibility_off_rounded
                                                        : Icons
                                                              .visibility_rounded,
                                                    size: 18,
                                                    color: colors.textSecondary,
                                                  ),
                                                  onPressed: () => setState(
                                                    () => _obscureGroq =
                                                        !_obscureGroq,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            border: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              borderSide: BorderSide(
                                                color: colors.glassBorder,
                                              ),
                                            ),
                                            focusedBorder: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              borderSide: const BorderSide(
                                                color: AppColors.primary,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      GlassButton(
                                        label: _isTestingGroq
                                            ? '...'
                                            : (_isGroqSaved
                                                  ? 'Tersimpan'
                                                  : 'Simpan'),
                                        variant: _isGroqSaved
                                            ? GlassButtonVariant.income
                                            : GlassButtonVariant.warning,
                                        width: 90,
                                        height: 42,
                                        onPressed: _isTestingGroq
                                            ? null
                                            : () => _saveGroqKey(
                                                _groqController.text,
                                              ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),

                          // 2. INPUT GEMINI API KEY SECTION
                          GlassCard(
                            padding: const EdgeInsets.all(16),
                            borderRadius: 16,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Row(
                                        children: [
                                          const Icon(
                                            Icons.camera_alt_outlined,
                                            color: AppColors.primary,
                                            size: 18,
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              'Gemini Key',
                                              style: AppTypography.labelLarge,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Showcase(
                                      key: ProductTourKeys.modalGeminiBtn,
                                      title: '3. Ambil Gemini Key Gratis',
                                      description:
                                          'Ketuk tombol ini → aistudio.google.com terbuka.\n'
                                          'Buat API Key gratis lalu salin kuncinya.',
                                      targetBorderRadius: BorderRadius.circular(
                                        20,
                                      ),
                                      targetPadding: const EdgeInsets.all(4),
                                      tooltipBackgroundColor: const Color(
                                        0xE61A1A2E,
                                      ),
                                      titleTextStyle: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                      ),
                                      descTextStyle: const TextStyle(
                                        color: Color(0xD9FFFFFF),
                                        fontSize: 13,
                                        height: 1.4,
                                      ),
                                      child: InkWell(
                                        borderRadius: BorderRadius.circular(20),
                                        onTap: _openGeminiConsole,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 5,
                                          ),
                                          decoration: BoxDecoration(
                                            color: AppColors.primary.withValues(
                                              alpha: 0.15,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              20,
                                            ),
                                            border: Border.all(
                                              color: AppColors.primary
                                                  .withValues(alpha: 0.4),
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                'Ambil Key',
                                                style: AppTypography.caption
                                                    .copyWith(
                                                      color: AppColors.primary,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                              ),
                                              const SizedBox(width: 4),
                                              const Icon(
                                                Icons.open_in_new_rounded,
                                                size: 13,
                                                color: AppColors.primary,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Kunci penglihatan AI untuk Scan Struk (aistudio.google.com)',
                                  style: AppTypography.caption,
                                ),
                                const SizedBox(height: 10),
                                Showcase(
                                  key: ProductTourKeys.modalGeminiInput,
                                  title: '4. Tempel & Simpan Gemini Key',
                                  description:
                                      'Tempelkan kunci Gemini ke kolom ini lalu tekan Simpan.',
                                  targetBorderRadius: BorderRadius.circular(14),
                                  targetPadding: const EdgeInsets.all(2),
                                  tooltipBackgroundColor: const Color(
                                    0xE61A1A2E,
                                  ),
                                  titleTextStyle: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                  descTextStyle: const TextStyle(
                                    color: Color(0xD9FFFFFF),
                                    fontSize: 13,
                                    height: 1.4,
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: TextField(
                                          controller: _geminiController,
                                          obscureText: _obscureGemini,
                                          style: TextStyle(
                                            color: colors.textPrimary,
                                            fontSize: 13,
                                          ),
                                          onChanged: (val) {
                                            if (_isGeminiSaved) {
                                              setState(
                                                () => _isGeminiSaved = false,
                                              );
                                            }
                                          },
                                          decoration: InputDecoration(
                                            hintText: 'AIzaSy... atau AQ....',
                                            hintStyle: TextStyle(
                                              color: colors.textMuted
                                                  .withValues(alpha: 0.5),
                                            ),
                                            filled: true,
                                            fillColor: colors.background,
                                            contentPadding:
                                                const EdgeInsets.symmetric(
                                                  horizontal: 12,
                                                  vertical: 10,
                                                ),
                                            suffixIcon: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                if (_geminiController
                                                    .text
                                                    .isNotEmpty)
                                                  IconButton(
                                                    icon: Icon(
                                                      Icons.clear_rounded,
                                                      size: 16,
                                                      color: colors.textMuted,
                                                    ),
                                                    onPressed: _clearGeminiKey,
                                                  ),
                                                IconButton(
                                                  icon: Icon(
                                                    _obscureGemini
                                                        ? Icons
                                                              .visibility_off_rounded
                                                        : Icons
                                                              .visibility_rounded,
                                                    size: 18,
                                                    color: colors.textSecondary,
                                                  ),
                                                  onPressed: () => setState(
                                                    () => _obscureGemini =
                                                        !_obscureGemini,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            border: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              borderSide: BorderSide(
                                                color: colors.glassBorder,
                                              ),
                                            ),
                                            focusedBorder: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              borderSide: const BorderSide(
                                                color: AppColors.primary,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      GlassButton(
                                        label: _isTestingGemini
                                            ? '...'
                                            : (_isGeminiSaved
                                                  ? 'Tersimpan'
                                                  : 'Simpan'),
                                        variant: _isGeminiSaved
                                            ? GlassButtonVariant.income
                                            : GlassButtonVariant.warning,
                                        width: 90,
                                        height: 42,
                                        onPressed: _isTestingGemini
                                            ? null
                                            : () => _saveGeminiKey(
                                                _geminiController.text,
                                              ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
