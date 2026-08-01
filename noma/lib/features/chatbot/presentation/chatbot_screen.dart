import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/ai_key_setup_modal.dart';
import '../../../shared/widgets/ai_thinking_widget.dart';
import '../../../shared/widgets/glass_card.dart';
import 'providers/chatbot_provider.dart';
import 'widgets/chat_bubble.dart';

class ChatbotScreen extends ConsumerStatefulWidget {
  const ChatbotScreen({super.key});

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

  @override
  Widget build(BuildContext context) {
    ref.listen(chatbotControllerProvider, (prev, next) {
      if (next.hasError && !next.isLoading) {
        final errorMsg = next.error.toString().replaceAll('Exception: ', '');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMsg),
            backgroundColor: AppColors.expense,
            behavior: SnackBarBehavior.floating,
          ),
        );

        if (errorMsg.contains('API Key') || errorMsg.contains('API_KEY_INVALID')) {
          AiKeySetupModal.show(context);
        }
      }
    });

    final messagesAsync = ref.watch(chatMessagesStreamProvider);
    final controllerState = ref.watch(chatbotControllerProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.auto_awesome, color: AppColors.primary, size: 20),
            const SizedBox(width: 8),
            Text('Nomi — Asisten AI', style: AppTypography.headingMedium),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep_rounded, color: AppColors.textSecondary),
            tooltip: 'Hapus Obrolan',
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Hapus Riwayat Chat?'),
                  content: const Text('Semua percakapan dengan Nomi AI akan dihapus dari HP.'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Batal'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Hapus', style: TextStyle(color: AppColors.expense)),
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
                            'Halo! Saya Nomi 👋',
                            style: AppTypography.headingLarge,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Tanyakan apa saja seputar keuanganmu. Misal:\n"Berapa total pengeluaranku?" atau "Beri saran penghematan"',
                            textAlign: TextAlign.center,
                            style: AppTypography.caption,
                          ),
                        ],
                      ),
                    ),
                  );
                }

                WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(20),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final msg = messages[index];
                    return ChatBubble(
                      message: msg.content,
                      isUser: msg.role == 'user',
                      timestamp: DateTime.fromMillisecondsSinceEpoch(msg.createdAt),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
              error: (err, _) => Center(child: Text('Error: $err')),
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
            ),

          // Bottom Input Bar
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: AppColors.backgroundSecondary,
              border: Border(top: BorderSide(color: AppColors.glassBorder)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: GlassCard(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    borderRadius: 24,
                    child: TextField(
                      controller: _controller,
                      style: AppTypography.bodyMedium,
                      decoration: const InputDecoration(
                        hintText: 'Tanyakan sesuatu pada Nomi AI...',
                        hintStyle: TextStyle(color: AppColors.textMuted),
                        border: InputBorder.none,
                      ),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                InkWell(
                  onTap: controllerState.isLoading ? null : _send,
                  borderRadius: BorderRadius.circular(24),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.send_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
