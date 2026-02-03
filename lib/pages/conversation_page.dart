import 'package:flutter/material.dart';
import 'package:equisplit/repositories/messaging_repository.dart';
import 'package:equisplit/services/image_storage_service.dart';
import 'dart:io';

class ConversationPage extends StatefulWidget {
  final Map<String, dynamic> otherUser;
  final Map<String, dynamic>? currentUser;

  const ConversationPage({
    super.key,
    required this.otherUser,
    this.currentUser,
  });

  @override
  State<ConversationPage> createState() => _ConversationPageState();
}

class _ConversationPageState extends State<ConversationPage> {
  final _messagingRepo = MessagingRepository();
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();

  late int _conversationId;
  int? _currentUserId;
  int? _otherUserId;
  List<Map<String, dynamic>> _messages = [];
  bool _isLoading = true;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _currentUserId = widget.currentUser?['user_id'] as int?;
    _otherUserId = widget.otherUser['user_id'] as int?;
    _initializeConversation();
  }

  Future<void> _initializeConversation() async {
    if (_currentUserId == null || _otherUserId == null) return;

    final conversation = await _messagingRepo.getOrCreateConversation(
      _currentUserId!,
      _otherUserId!,
    );

    if (conversation != null) {
      setState(() => _conversationId = conversation['id'] as int);
      await _loadMessages();
      await _messagingRepo.markMessagesAsRead(_conversationId, _currentUserId!);
    }
  }

  Future<void> _loadMessages() async {
    final messages = await _messagingRepo.getMessages(_conversationId);
    setState(() {
      _messages = messages;
      _isLoading = false;
    });
    _scrollToBottom();
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final content = _messageController.text.trim();
    if (content.isEmpty || _currentUserId == null || _otherUserId == null) {
      return;
    }

    setState(() => _isSending = true);
    _messageController.clear();

    final success = await _messagingRepo.sendMessage(
      _conversationId,
      _currentUserId!,
      _otherUserId!,
      content,
    );

    if (success) {
      await _loadMessages();
    }

    setState(() => _isSending = false);
  }

  Future<void> _deleteMessage(int messageId) async {
    if (_currentUserId == null) return;
    
    final success = await _messagingRepo.deleteMessage(messageId, _currentUserId!);
    if (success) {
      await _loadMessages();
    }
  }

  void _showMessageOptions(int messageId, bool isSent) {
    if (!isSent) return; // Only allow deleting own messages
    
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Delete Message', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                _deleteMessage(messageId);
              },
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final messageDate = DateTime(dateTime.year, dateTime.month, dateTime.day);

    if (messageDate == today) {
      return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } else if (messageDate == yesterday) {
      return 'Yesterday';
    } else {
      return '${dateTime.month}/${dateTime.day}/${dateTime.year}';
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final otherUserName = widget.otherUser['name'] as String? ?? 'User';
    final avatarPath = widget.otherUser['avatar_path'] as String?;

    String? avatarUrl;
    if (avatarPath != null && avatarPath.isNotEmpty) {
      avatarUrl = avatarPath.startsWith('/uploads/')
          ? 'http://${ImageStorageService.SERVER_IP}:${ImageStorageService.SERVER_PORT}$avatarPath'
          : avatarPath;
    }

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.grey[300],
                border: Border.all(color: Colors.white, width: 1),
                image: avatarUrl != null
                    ? DecorationImage(
                        image: avatarPath?.startsWith('/uploads/') == true
                            ? NetworkImage(avatarUrl)
                            : FileImage(File(avatarPath!)),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: avatarUrl == null
                  ? Icon(Icons.person, color: Colors.grey[600], size: 20)
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    otherUserName,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  Text(
                    'Active now',
                    style: TextStyle(fontSize: 12, color: Colors.grey[300]),
                  ),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF1976D2),
        elevation: 0,
      ),
      body: Column(
        children: [
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _messages.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.message_outlined,
                                size: 64, color: Colors.grey[400]),
                            const SizedBox(height: 16),
                            Text(
                              'No messages yet',
                              style: TextStyle(
                                  color: Colors.grey[600], fontSize: 16),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Start a conversation',
                              style: TextStyle(
                                  color: Colors.grey[500], fontSize: 13),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(
                            vertical: 16, horizontal: 12),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          final message = _messages[index];
                          final messageId = message['id'] as int?;
                          final isSent =
                              message['sender_id'] == _currentUserId;
                          
                          // Handle both String and Blob types
                          String content = '';
                          final contentRaw = message['content'];
                          if (contentRaw is String) {
                            content = contentRaw;
                          } else if (contentRaw is List<int>) {
                            // Blob/binary data - convert to String
                            content = String.fromCharCodes(contentRaw);
                          } else {
                            content = contentRaw?.toString() ?? '';
                          }
                          
                          // Handle both DateTime and String types
                          final createdAt = message['created_at'] is DateTime
                              ? message['created_at'] as DateTime
                              : DateTime.parse(message['created_at'] as String);

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              mainAxisAlignment: isSent
                                  ? MainAxisAlignment.end
                                  : MainAxisAlignment.start,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                if (!isSent) ...[
                                  Container(
                                    width: 30,
                                    height: 30,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Colors.grey[300],
                                      image: avatarUrl != null
                                          ? DecorationImage(
                                              image: avatarPath
                                                      ?.startsWith('/uploads/') ==
                                                  true
                                                  ? NetworkImage(avatarUrl)
                                                  : FileImage(
                                                      File(avatarPath!)),
                                              fit: BoxFit.cover,
                                            )
                                          : null,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                ],
                                Flexible(
                                  child: GestureDetector(
                                    onLongPress: isSent ? () => _showMessageOptions(messageId ?? 0, isSent) : null,
                                    child: Column(
                                      crossAxisAlignment: isSent
                                          ? CrossAxisAlignment.end
                                          : CrossAxisAlignment.start,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 8, horizontal: 12),
                                          decoration: BoxDecoration(
                                            color: isSent
                                                ? const Color(0xFF1976D2)
                                                : Colors.grey[300],
                                            borderRadius: BorderRadius.circular(
                                                12),
                                          ),
                                          child: Text(
                                            content,
                                            style: TextStyle(
                                              color: isSent
                                                  ? Colors.white
                                                  : Colors.black87,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Padding(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8),
                                          child: Text(
                                            _formatTime(createdAt),
                                            style: TextStyle(
                                              color: Colors.grey[500],
                                              fontSize: 11,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                if (isSent)
                                  const SizedBox(width: 8),
                              ],
                            ),
                          );
                        },
                      ),
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(
                top: BorderSide(color: Colors.grey[300]!),
              ),
            ),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      decoration: InputDecoration(
                        hintText: 'Type a message...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: const BorderSide(
                            color: Color(0xFF1976D2),
                            width: 2,
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 10,
                          horizontal: 16,
                        ),
                      ),
                      enabled: !_isSending,
                      maxLines: null,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFF1976D2),
                    ),
                    child: IconButton(
                      icon: _isSending
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Icon(Icons.send),
                      color: Colors.white,
                      onPressed: _isSending ? null : _sendMessage,
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
}
