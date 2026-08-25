import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_color_scheme.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/ai_key_setup_modal.dart';
import '../../../shared/widgets/ai_thinking_widget.dart';
import '../../../shared/widgets/bouncy_tap.dart';
import '../../../shared/widgets/glass_card.dart';
import 'providers/chatbot_provider.dart';
import 'widgets/chat_bubble.dart';

class ChatbotScreen extends ConsumerStatefulWidget {
  final bool isTabPage;

  const ChatbotScreen({super.key, this.isTabPage = false});

  @override
  ConsumerState<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends ConsumerState<ChatbotScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent + 100,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    _controller.clear();
    ref.read(chatbotControllerProvider.notifier).sendMessage(text);
    Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);
  }

  void _sendQuickPrompt(String text) {
    ref.read(chatbotControllerProvider.notifier).sendMessage(text);
    Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<void>>(chatbotControllerProvider, (prev, next) {
      if (next.hasError && !next.isLoading) {
        final errorMsg = (next.error ?? '').toString().replaceAll(
          'Exception: ',
          '',
        );
        if (errorMsg.isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorMsg),
              backgroundColor: AppColors.expense,
              behavior: SnackBarBehavior.floating,
            ),
          );

          if (errorMsg.contains('API Key') ||
              errorMsg.contains('API_KEY_INVALID') ||
              errorMsg.contains('invalid_api_key')) {
            AiKeySetupModal.show(context);
          }
        }
      }
    });

    final colors = AppColorScheme.of(context);
    final messagesAsync = ref.watch(chatMessagesStreamProvider);
    final controllerState = ref.watch(chatbotControllerProvider);
    final mediaQuery = MediaQuery.of(context);
    final keyboardHeight = mediaQuery.viewInsets.bottom;
    final isKeyboardActive = keyboardHeight > 0;

    final bottomMargin = widget.isTabPage
        ? (isKeyboardActive
              ? keyboardHeight + 12.0
              : 88.0 + mediaQuery.padding.bottom)
        : (isKeyboardActive
              ? keyboardHeight + 12.0
              : 16.0 + mediaQuery.padding.bottom);

    return Scaffold(
      backgroundColor: colors.background,
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.auto_awesome, color: AppColors.primary, size: 20),
            const SizedBox(width: 8),
            Text('Nomi — Asisten AI', style: AppTypography.headingMedium.copyWith(color: colors.textPrimary)),
          ],
        ),
        automaticallyImplyLeading: !widget.isTabPage,
        leading: widget.isTabPage
            ? null
            : IconButton(
                icon: Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: colors.textPrimary,
                ),
                onPressed: () => Navigator.of(context).pop(),
              ),
        actions: [
          IconButton(
            icon: Icon(
              Icons.delete_sweep_rounded,
              color: colors.textSecondary,
            ),
            tooltip: 'Hapus Obrolan',
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Hapus Riwayat Chat?'),
                  content: const Text(
                    'Semua percakapan dengan Nomi AI akan dihapus dari HP.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Batal'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text(
                        'Hapus',
                        style: TextStyle(color: AppColors.expense),
                      ),
                    ),
                  ],
                ),
              );
              if (confirm == true) {
                ref.read(chatbotControllerProvider.notifier).clearHistory();
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Chat Messages Area
          Expanded(
            child: messagesAsync.when(
              data: (messages) {
                if (messages.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.auto_awesome,
                              size: 48,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Halo! Saya Nomi',
                            style: AppTypography.headingLarge.copyWith(color: colors.textPrimary),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Tanyakan seputar saldo, pengeluaran, budgeting, dan tips hemat berdasarkan data Noma.\n(Riwayat chat dibersihkan otomatis setiap 24 jam)',
                            textAlign: TextAlign.center,
                            style: AppTypography.caption.copyWith(color: colors.textMuted),
                          ),
                          const SizedBox(height: 18),
                          _buildQuickPrompts(context),
                        ],
                      ),
                    ),
                  );
                }

                WidgetsBinding.instance.addPostFrameCallback(
                  (_) => _scrollToBottom(),
                );

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.only(
                    left: 20,
                    right: 20,
                    top: 20,
                    bottom: 16,
                  ),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final msg = messages[index];
                    return ChatBubble(
                      message: msg.content,
                      isUser: msg.role == 'user',
                      timestamp: DateTime.fromMillisecondsSinceEpoch(
                        msg.createdAt,
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
              error: (err, _) => Center(child: Text('Error: $err', style: AppTypography.caption.copyWith(color: colors.textSecondary))),
            ),
          ),

          // Loading Typing Indicator (AI Thinking Animation)
          if (controllerState.isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: AiThinkingWidget(
                  isCompact: true,
                  text: 'Nomi AI sedang memproses jawaban',
                ),
              ),
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
              child: Row(
                children: [
                  'Berapa saldo saya?',
                  'Pengeluaran bulan ini',
                  'Kategori terbesar',
                  '5 transaksi terakhir',
                  'Beri saran hemat',
                ].map((prompt) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ActionChip(
                      label: Text(prompt),
                      avatar: const Icon(
                        Icons.auto_awesome_rounded,
                        size: 14,
                        color: AppColors.primary,
                      ),
                      backgroundColor: colors.glassSurface,
                      side: BorderSide(
                        color: AppColors.primary.withValues(alpha: 0.3),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      labelStyle: AppTypography.caption.copyWith(
                        color: colors.textPrimary,
                        fontSize: 11,
                      ),
                      onPressed: () => _sendQuickPrompt(prompt),
                    ),
                  );
                }).toList(),
              ),
            ),

          // Floating Glassmorphic Input Bar
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            margin: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 8,
              bottom: bottomMargin,
            ),
            child: GlassCard(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              borderRadius: 28,
              backgroundColor: colors.backgroundSecondary.withValues(
                alpha: 0.9,
              ),
              borderColor: colors.glassBorder,
              shadows: [
                BoxShadow(
                  color: AppColorScheme.isLight(context)
                      ? Colors.black.withValues(alpha: 0.08)
                      : Colors.black.withValues(alpha: 0.3),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
              child: Row(
                children: [
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.auto_awesome,
                    color: AppColors.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      style: AppTypography.bodyMedium.copyWith(color: colors.textPrimary),
                      decoration: InputDecoration(
                        hintText: 'Tanyakan seputar keuanganmu...',
                        hintStyle: TextStyle(
                          color: colors.textMuted,
                          fontSize: 14,
                        ),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  BouncyTap(
                    onTap: controllerState.isLoading ? null : _send,
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        gradient: AppColors.primaryGradient,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.4),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.send_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickPrompts(BuildContext context) {
    final colors = AppColorScheme.of(context);
    final prompts = [
      'Berapa saldo saya?',
      'Pengeluaran bulan ini',
      'Kategori terbesar',
      'Beri saran hemat',
    ];

    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 8,
      runSpacing: 8,
      children: prompts.map((prompt) {
        return ActionChip(
          label: Text(prompt),
          avatar: const Icon(Icons.auto_awesome_rounded, size: 16),
          backgroundColor: colors.glassSurface,
          side: BorderSide(color: AppColors.primary.withValues(alpha: 0.35)),
          labelStyle: AppTypography.caption.copyWith(
            color: colors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
          onPressed: () => _sendQuickPrompt(prompt),
        );
      }).toList(),
    );
  }
}
