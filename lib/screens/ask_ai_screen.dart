import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_colors.dart';
import '../providers/app_provider.dart';
import '../services/nurtura_api.dart';

class AskAiScreen extends StatefulWidget {
  const AskAiScreen({super.key, this.showBackButton = true});

  final bool showBackButton;

  @override
  State<AskAiScreen> createState() => _AskAiScreenState();
}

class _AskAiScreenState extends State<AskAiScreen> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final _api = NurturaApi();
  final _focusNode = FocusNode();

  List<Map<String, dynamic>> _threads = [];
  List<Map<String, dynamic>> _messages = [];
  List<String> _prompts = [];
  int? _activeThreadId;
  String _activeThreadTitle = 'Ask Nurtura AI';
  bool _loading = true;
  bool _sending = false;
  String? _loadError;
  String _streamingText = '';
  bool _awaitingFirstToken = false;

  @override
  void initState() {
    super.initState();
    _loadInitial();
  }

  Future<void> _loadInitial() async {
    final userId = context.read<AppProvider>().userId;
    if (userId == null) return;

    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final results = await Future.wait([
        _api.getChatThreads(userId),
        _api.getChatPrompts(),
      ]);
      if (!mounted) return;

      var threads = results[0] as List<Map<String, dynamic>>;
      if (threads.isEmpty) {
        final created = await _api.createChatThread(userId);
        threads = [created];
      }

      final active = threads.first;
      final threadId = active['id'] as int;
      final messages = await _api.getChatMessages(userId, threadId);

      if (!mounted) return;
      setState(() {
        _threads = threads;
        _prompts = results[1] as List<String>;
        _activeThreadId = threadId;
        _activeThreadTitle = active['title']?.toString() ?? 'New chat';
        _messages = messages;
        _loadError = null;
      });
      _scrollToBottom(animated: false);
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadError = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _closeDrawerIfOpen() {
    final state = _scaffoldKey.currentState;
    if (state?.isDrawerOpen ?? false) {
      Navigator.of(context).pop();
    } else if (state?.isEndDrawerOpen ?? false) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _selectThread(Map<String, dynamic> thread) async {
    if (_sending) return;
    if (thread['id'] == _activeThreadId) {
      _closeDrawerIfOpen();
      return;
    }

    final userId = context.read<AppProvider>().userId;
    if (userId == null) return;

    final threadId = thread['id'] as int;
    setState(() {
      _loading = true;
      _activeThreadId = threadId;
      _activeThreadTitle = thread['title']?.toString() ?? 'New chat';
      _messages = [];
    });
    _closeDrawerIfOpen();

    try {
      final messages = await _api.getChatMessages(userId, threadId);
      if (!mounted) return;
      setState(() => _messages = messages);
      _scrollToBottom(animated: false);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _createThread() async {
    if (_sending) return;
    final userId = context.read<AppProvider>().userId;
    if (userId == null) return;

    try {
      final thread = await _api.createChatThread(userId);
      if (!mounted) return;
      setState(() {
        _threads = [thread, ..._threads];
        _activeThreadId = thread['id'] as int;
        _activeThreadTitle = thread['title']?.toString() ?? 'New chat';
        _messages = [];
      });
      _closeDrawerIfOpen();
      _focusNode.requestFocus();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), behavior: SnackBarBehavior.floating),
        );
      }
    }
  }

  Future<void> _deleteThread(Map<String, dynamic> thread) async {
    final userId = context.read<AppProvider>().userId;
    if (userId == null || _sending) return;

    final threadId = thread['id'] as int;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete chat?'),
        content: Text('Delete "${thread['title']}"? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await _api.deleteChatThread(userId, threadId);
      if (!mounted) return;

      final remaining = _threads.where((t) => t['id'] != threadId).toList();
      if (remaining.isEmpty) {
        final created = await _api.createChatThread(userId);
        if (!mounted) return;
        setState(() {
          _threads = [created];
          _activeThreadId = created['id'] as int;
          _activeThreadTitle = created['title']?.toString() ?? 'New chat';
          _messages = [];
        });
        return;
      }

      setState(() => _threads = remaining);
      if (_activeThreadId == threadId) {
        await _selectThread(remaining.first);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), behavior: SnackBarBehavior.floating),
        );
      }
    }
  }

  void _scrollToBottom({bool animated = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      final target = _scrollController.position.maxScrollExtent;
      if (animated) {
        _scrollController.animateTo(
          target,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      } else {
        _scrollController.jumpTo(target);
      }
    });
  }

  Future<void> _send([String? text]) async {
    final userId = context.read<AppProvider>().userId;
    final threadId = _activeThreadId;
    final message = (text ?? _controller.text).trim();
    if (userId == null || threadId == null || message.isEmpty || _sending) return;

    _controller.clear();
    setState(() {
      _sending = true;
      _awaitingFirstToken = true;
      _streamingText = '';
      _messages.add({'message': message, 'isUser': true, 'id': 'local-${DateTime.now().millisecondsSinceEpoch}'});
    });
    _scrollToBottom();

    var streamStarted = false;
    try {
      var completed = false;

      await for (final event in _api.streamChatMessage(userId, threadId, message)) {
        streamStarted = true;
        if (!mounted) return;
        if (event.error != null) throw ApiException(event.error!);
        if (event.delta != null) {
          setState(() {
            _awaitingFirstToken = false;
            _streamingText += event.delta!;
          });
          _scrollToBottom();
        }
        if (event.done && event.aiMessage != null) {
          completed = true;
          setState(() {
            _messages.add(event.aiMessage!);
            _streamingText = '';
            _awaitingFirstToken = false;
          });
          _scrollToBottom();
          await _refreshThreads(userId, threadId, message);
        }
      }

      if (streamStarted && !completed && mounted) {
        await _reloadMessages(userId, threadId);
      }
    } catch (_) {
      if (!mounted) return;
      if (streamStarted) {
        await _reloadMessages(userId, threadId);
      } else {
        setState(() => _messages.removeLast());
        await _sendFallback(userId, threadId, message);
      }
    } finally {
      if (mounted) {
        setState(() {
          _sending = false;
          _streamingText = '';
          _awaitingFirstToken = false;
        });
      }
    }
  }

  Future<void> _refreshThreads(int userId, int threadId, String message) async {
    final threads = await _api.getChatThreads(userId);
    if (!mounted) return;
    final active = threads.firstWhere((t) => t['id'] == threadId, orElse: () => threads.first);
    setState(() {
      _threads = threads;
      _activeThreadTitle = active['title']?.toString() ?? message;
    });
  }

  Future<void> _reloadMessages(int userId, int threadId) async {
    final messages = await _api.getChatMessages(userId, threadId);
    if (!mounted) return;
    setState(() {
      _messages = messages;
      _streamingText = '';
      _awaitingFirstToken = false;
    });
    _scrollToBottom();
  }

  Future<void> _sendFallback(int userId, int threadId, String message) async {
    try {
      final result = await _api.sendChatMessage(userId, threadId, message);
      if (!mounted) return;
      setState(() {
        _messages.add({'message': message, 'isUser': true});
        _messages.add(result['aiMessage'] as Map<String, dynamic>);
      });
      _scrollToBottom();
      await _refreshThreads(userId, threadId, message);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), behavior: SnackBarBehavior.floating),
        );
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Widget _buildDrawer() {
    return Drawer(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Text('Chats', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primary)),
            ),
            ListTile(
              leading: const Icon(Icons.add_comment_outlined, color: AppColors.primary),
              title: const Text('New chat'),
              onTap: _createThread,
            ),
            const Divider(height: 1),
            Expanded(
              child: _threads.isEmpty
                  ? const Center(child: Text('No chats yet'))
                  : ListView.builder(
                      itemCount: _threads.length,
                      itemBuilder: (context, i) {
                        final thread = _threads[i];
                        final id = thread['id'] as int;
                        final selected = id == _activeThreadId;
                        return Dismissible(
                          key: ValueKey(id),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            color: Colors.red.shade400,
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 20),
                            child: const Icon(Icons.delete_outline, color: Colors.white),
                          ),
                          confirmDismiss: (_) async {
                            await _deleteThread(thread);
                            return false;
                          },
                          child: ListTile(
                            selected: selected,
                            selectedTileColor: AppColors.primary.withValues(alpha: 0.08),
                            title: Text(
                              thread['title']?.toString() ?? 'New chat',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            onTap: () => _selectThread(thread),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final itemCount = _messages.length +
        (_awaitingFirstToken ? 1 : 0) +
        (_streamingText.isNotEmpty ? 1 : 0);

    return Scaffold(
      key: _scaffoldKey,
      drawer: widget.showBackButton ? null : _buildDrawer(),
      endDrawer: widget.showBackButton ? _buildDrawer() : null,
      appBar: AppBar(
        leading: widget.showBackButton
            ? IconButton(
                icon: const Icon(Icons.arrow_back_ios_new, size: 20),
                onPressed: () => Navigator.pop(context),
              )
            : IconButton(
                icon: const Icon(Icons.menu),
                onPressed: () => _scaffoldKey.currentState?.openDrawer(),
              ),
        title: Text(
          _activeThreadTitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            tooltip: 'New chat',
            onPressed: _sending ? null : _createThread,
            icon: const Icon(Icons.add_comment_outlined),
          ),
          if (widget.showBackButton)
            IconButton(
              tooltip: 'Chat history',
              onPressed: () => _scaffoldKey.currentState?.openEndDrawer(),
              icon: const Icon(Icons.history),
            ),
        ],
      ),
      body: Column(
        children: [
          if (_prompts.isNotEmpty)
            SizedBox(
              height: 44,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _prompts.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, i) {
                  final prompt = _prompts[i];
                  return ActionChip(
                    label: Text(prompt, style: const TextStyle(fontSize: 12)),
                    onPressed: _sending ? null : () => _send(prompt),
                  );
                },
              ),
            ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                : _loadError != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.cloud_off, size: 48, color: AppColors.textMuted.withValues(alpha: 0.6)),
                              const SizedBox(height: 16),
                              Text(
                                _loadError!,
                                textAlign: TextAlign.center,
                                style: TextStyle(color: AppColors.textMuted, fontSize: 14, height: 1.4),
                              ),
                              const SizedBox(height: 20),
                              FilledButton(
                                onPressed: _loadInitial,
                                child: const Text('Retry'),
                              ),
                            ],
                          ),
                        ),
                      )
                : _messages.isEmpty && !_sending
                    ? Center(
                        child: Text(
                          'Start a new conversation',
                          style: TextStyle(color: AppColors.textMuted, fontSize: 15),
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(16),
                        itemCount: itemCount,
                        itemBuilder: (context, i) {
                          if (i < _messages.length) {
                            final m = _messages[i];
                            return _ChatBubble(
                              key: ValueKey(m['id'] ?? i),
                              text: m['message']?.toString() ?? '',
                              isUser: m['isUser'] == true,
                            );
                          }
                          if (_awaitingFirstToken && i == _messages.length) {
                            return const _TypingBubble();
                          }
                          return _ChatBubble(
                            text: _streamingText,
                            isUser: false,
                            streaming: true,
                          );
                        },
                      ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    focusNode: _focusNode,
                    enabled: !_sending && _activeThreadId != null,
                    textInputAction: TextInputAction.send,
                    onSubmitted: _sending ? null : (_) => _send(),
                    decoration: InputDecoration(
                      hintText: 'Type your question...',
                      filled: true,
                      fillColor: AppColors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(28),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                CircleAvatar(
                  radius: 26,
                  backgroundColor: AppColors.primary,
                  child: _sending
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : IconButton(
                          icon: const Icon(Icons.send_rounded, color: AppColors.white, size: 20),
                          onPressed: () => _send(),
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

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({
    super.key,
    required this.text,
    required this.isUser,
    this.streaming = false,
  });

  final String text;
  final bool isUser;
  final bool streaming;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
        decoration: BoxDecoration(
          color: isUser ? AppColors.askAi : AppColors.white,
          borderRadius: BorderRadius.circular(18),
          border: isUser ? null : Border.all(color: AppColors.cardBorder),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: isUser ? AppColors.white : AppColors.textDark,
            fontSize: 14,
            height: 1.4,
          ),
        ),
      ),
    );
  }
}

class _TypingBubble extends StatefulWidget {
  const _TypingBubble();

  @override
  State<_TypingBubble> createState() => _TypingBubbleState();
}

class _TypingBubbleState extends State<_TypingBubble> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(3, (i) {
                final active = (_controller.value * 3).floor() == i;
                return Container(
                  width: 8,
                  height: 8,
                  margin: EdgeInsets.only(right: i == 2 ? 0 : 6),
                  decoration: BoxDecoration(
                    color: active ? AppColors.primary : AppColors.textMuted.withValues(alpha: 0.35),
                    shape: BoxShape.circle,
                  ),
                );
              }),
            );
          },
        ),
      ),
    );
  }
}
