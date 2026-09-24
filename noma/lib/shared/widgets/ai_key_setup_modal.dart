import 'dart:ui';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:showcaseview/showcaseview.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/app_color_scheme.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/product_tour_keys.dart';
import '../../core/services/api_key_service.dart';
import '../../core/theme/app_typography.dart';
import 'glass_button.dart';
import 'glass_card.dart';

class AiKeySetupModal extends StatefulWidget {
  final VoidCallback? onKeySaved;
  final VoidCallback? onClose;

  const AiKeySetupModal({super.key, this.onKeySaved, this.onClose});

  static OverlayEntry? _overlayEntry;

  static void show(BuildContext context, {VoidCallback? onKeySaved}) {
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
  final TextEditingController _controller = TextEditingController();

  bool _isCheckingClipboard = false;
  bool _isTesting = false;
  bool _isSaved = false;
  bool _obscure = true;
  String? _detectedKeyInClipboard;
  String? _toastMessage;
  Color _toastColor = AppColors.income;
  double _dragOffset = 0.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadCurrentKey();
    _checkClipboardForKey();
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

  Future<void> _loadCurrentKey() async {
    final key = await ApiKeyService.getGeminiApiKey();
    if (!mounted || key.isEmpty) return;
    setState(() {
      _controller.text = key;
      _isSaved = true;
    });
  }

  Future<void> _checkClipboardForKey() async {
    if (_isCheckingClipboard) return;
    setState(() => _isCheckingClipboard = true);

    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      final text = ApiKeyService.sanitizeKey(data?.text ?? '');
      if (_looksLikeGeminiKey(text) && mounted) {
        setState(() => _detectedKeyInClipboard = text);
      }
    } catch (_) {
      // Clipboard access can fail on some Android versions.
    } finally {
      if (mounted) setState(() => _isCheckingClipboard = false);
    }
  }

  bool _looksLikeGeminiKey(String key) {
    return (key.startsWith('AIzaSy') && key.length >= 30) ||
        (key.startsWith('AQ.') && key.length >= 30);
  }

  void _showToast(String message, {Color color = AppColors.income}) {
    if (!mounted) return;
    setState(() {
      _toastMessage = message;
      _toastColor = color;
    });
    Future.delayed(const Duration(seconds: 4), () {
      if (mounted) setState(() => _toastMessage = null);
    });
  }

  Future<void> _saveKey(String key) async {
    final cleanKey = ApiKeyService.sanitizeKey(key);
    if (cleanKey.isEmpty) {
      _showToast(
        'Masukkan Gemini API Key terlebih dahulu.',
        color: AppColors.expense,
      );
      return;
    }

    if (!_looksLikeGeminiKey(cleanKey)) {
      _showToast(
        'Gunakan Gemini API Key dari Google AI Studio.',
        color: AppColors.warning,
      );
      return;
    }

    setState(() => _isTesting = true);

    try {
      final dio = Dio(BaseOptions(connectTimeout: const Duration(seconds: 10)));
      final encodedKey = Uri.encodeComponent(cleanKey);
      final response = await dio.post(
        'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=$encodedKey',
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

      await ApiKeyService.saveGeminiApiKey(cleanKey);
      if (!mounted) return;
      setState(() => _isSaved = true);
      _showToast(
        response.statusCode == 200
            ? 'Gemini Key valid dan tersimpan.'
            : 'Gemini Key tersimpan.',
      );
      widget.onKeySaved?.call();
    } on DioException catch (e) {
      if (e.response?.statusCode == 400 ||
          e.response?.statusCode == 401 ||
          e.response?.statusCode == 403) {
        _showToast('Gemini API Key tidak valid.', color: AppColors.expense);
        return;
      }

      await ApiKeyService.saveGeminiApiKey(cleanKey);
      if (!mounted) return;
      setState(() => _isSaved = true);
      _showToast('Key tersimpan. Periksa internet jika AI belum merespons.');
      widget.onKeySaved?.call();
    } finally {
      if (mounted) setState(() => _isTesting = false);
    }
  }

  Future<void> _clearKey() async {
    await ApiKeyService.clearApiKey();
    _controller.clear();
    setState(() => _isSaved = false);
    _showToast('Gemini Key berhasil dihapus.', color: AppColors.warning);
  }

  Future<void> _openGeminiConsole() async {
    final uri = Uri.parse('https://aistudio.google.com/app/apikey');
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      _showToast(
        'Tidak bisa membuka Google AI Studio.',
        color: AppColors.expense,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColorScheme.of(context);
    final screenHeight = MediaQuery.of(context).size.height;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final maxModalHeight = (screenHeight - bottomInset) * 0.82;

    return Material(
      type: MaterialType.transparency,
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: widget.onClose,
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                child: Container(color: Colors.black.withValues(alpha: 0.6)),
              ),
            ),
          ),
          Positioned(
            bottom: bottomInset,
            left: 0,
            right: 0,
            child: GestureDetector(
              onVerticalDragUpdate: (details) {
                final delta = details.primaryDelta ?? 0;
                if (delta > 0 || _dragOffset > 0) {
                  setState(() {
                    _dragOffset = (_dragOffset + delta).clamp(0.0, 500.0);
                  });
                }
              },
              onVerticalDragEnd: (details) {
                if (_dragOffset > 90 || (details.primaryVelocity ?? 0) > 250) {
                  widget.onClose?.call();
                } else {
                  setState(() => _dragOffset = 0.0);
                }
              },
              child: Transform.translate(
                offset: Offset(0, _dragOffset),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: maxModalHeight.clamp(280.0, screenHeight * 0.82),
                  ),
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                    decoration: BoxDecoration(
                      color: colors.backgroundSecondary.withValues(alpha: 0.98),
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(28),
                      ),
                      border: Border.all(color: colors.glassBorder, width: 1.5),
                    ),
                    child: SingleChildScrollView(
                      physics: const ClampingScrollPhysics(),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
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
                          if (_toastMessage != null) ...[
                            _ToastBanner(
                              message: _toastMessage!,
                              color: _toastColor,
                            ),
                            const SizedBox(height: 12),
                          ],
                          _Header(colors: colors),
                          const SizedBox(height: 16),
                          if (_detectedKeyInClipboard != null) ...[
                            _ClipboardBanner(
                              onUse: () {
                                _controller.text = _detectedKeyInClipboard!;
                                _saveKey(_detectedKeyInClipboard!);
                              },
                            ),
                            const SizedBox(height: 12),
                          ],
                          GlassCard(
                            padding: const EdgeInsets.all(16),
                            borderRadius: 16,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.auto_awesome_rounded,
                                      color: AppColors.primary,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Gemini API Key',
                                        style: AppTypography.labelLarge
                                            .copyWith(
                                              color: colors.textPrimary,
                                            ),
                                      ),
                                    ),
                                    Showcase(
                                      key: ProductTourKeys.modalGeminiBtn,
                                      title: 'Ambil Gemini Key',
                                      description:
                                          'Buka Google AI Studio, buat API key gratis, lalu salin kuncinya.',
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
                                      child: TextButton.icon(
                                        onPressed: _openGeminiConsole,
                                        icon: const Icon(
                                          Icons.open_in_new_rounded,
                                          size: 16,
                                        ),
                                        label: const Text('Ambil'),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Satu key untuk AI Teks, Nomi AI, dan Scan Struk.',
                                  style: AppTypography.caption.copyWith(
                                    color: colors.textMuted,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Showcase(
                                  key: ProductTourKeys.modalGeminiInput,
                                  title: 'Tempel & Simpan Key',
                                  description:
                                      'Tempelkan Gemini API key di sini lalu tekan Simpan.',
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
                                  child: TextField(
                                    controller: _controller,
                                    obscureText: _obscure,
                                    style: TextStyle(
                                      color: colors.textPrimary,
                                      fontSize: 13,
                                    ),
                                    onChanged: (_) {
                                      if (_isSaved) {
                                        setState(() => _isSaved = false);
                                      }
                                    },
                                    decoration: InputDecoration(
                                      hintText: 'AIzaSy... atau AQ....',
                                      filled: true,
                                      fillColor: colors.background,
                                      suffixIcon: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          if (_controller.text.isNotEmpty)
                                            IconButton(
                                              icon: Icon(
                                                Icons.clear_rounded,
                                                color: colors.textMuted,
                                              ),
                                              onPressed: _clearKey,
                                            ),
                                          IconButton(
                                            icon: Icon(
                                              _obscure
                                                  ? Icons.visibility_off_rounded
                                                  : Icons.visibility_rounded,
                                              color: colors.textSecondary,
                                            ),
                                            onPressed: () => setState(
                                              () => _obscure = !_obscure,
                                            ),
                                          ),
                                        ],
                                      ),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(
                                          color: colors.glassBorder,
                                        ),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: const BorderSide(
                                          color: AppColors.primary,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                GlassButton(
                                  label: _isSaved ? 'Tersimpan' : 'Simpan',
                                  icon: _isSaved
                                      ? Icons.check_circle_rounded
                                      : Icons.save_rounded,
                                  variant: _isSaved
                                      ? GlassButtonVariant.income
                                      : GlassButtonVariant.primary,
                                  isLoading: _isTesting,
                                  onPressed: _isTesting
                                      ? null
                                      : () => _saveKey(_controller.text),
                                ),
                              ],
                            ),
                          ),
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

class _Header extends StatelessWidget {
  final AppColorScheme colors;

  const _Header({required this.colors});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.2),
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
                'Pengaturan Gemini AI',
                style: AppTypography.headingSmall.copyWith(
                  color: colors.textPrimary,
                ),
              ),
              Text(
                'Satu API key untuk seluruh fitur AI Noma',
                style: AppTypography.caption.copyWith(
                  color: colors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ToastBanner extends StatelessWidget {
  final String message;
  final Color color;

  const _ToastBanner({required this.message, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded, color: Colors.white, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: AppTypography.labelMedium.copyWith(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

class _ClipboardBanner extends StatelessWidget {
  final VoidCallback onUse;

  const _ClipboardBanner({required this.onUse});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.income.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.income.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.content_paste_rounded,
            color: AppColors.income,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Gemini key terdeteksi di clipboard.',
              style: AppTypography.caption,
            ),
          ),
          TextButton(onPressed: onUse, child: const Text('Pakai')),
        ],
      ),
    );
  }
}
