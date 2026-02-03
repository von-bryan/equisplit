import 'package:flutter/material.dart';
import 'package:equisplit/repositories/messaging_repository.dart';
import 'package:equisplit/repositories/friends_repository.dart';
import 'package:equisplit/services/image_storage_service.dart';
import 'dart:io';

class MessagingPage extends StatefulWidget {
  final Map<String, dynamic>? currentUser;

  const MessagingPage({super.key, this.currentUser});

  @override
  State<MessagingPage> createState() => _MessagingPageState();
}

class _MessagingPageState extends State<MessagingPage> {
  final _messagingRepo = MessagingRepository();
  final _friendsRepo = FriendsRepository();
  late List<Map<String, dynamic>> _conversations = [];
  late List<Map<String, dynamic>> _allFriends = [];
  late List<int> _pinnedConversations = [];
  bool _isLoading = true;
  int? _currentUserId;

  @override
  void initState() {
    super.initState();
    _currentUserId = widget.currentUser?['user_id'] as int?;
    _loadData();
  }

  Future<void> _loadData() async {
    if (_currentUserId == null) return;

    setState(() => _isLoading = true);
    try {
      // Load both conversations and all friends
      final conversations = await _messagingRepo.getConversations(
        _currentUserId!,
      );
      final allFriends = await _friendsRepo.getMutualFriends(_currentUserId!);

      // Merge conversations with friends
      final mergedList = _mergeFriendsAndConversations(
        allFriends,
        conversations,
      );

      setState(() {
        _conversations = mergedList;
        _allFriends = allFriends;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading data: $e');
      setState(() => _isLoading = false);
    }
  }

  List<Map<String, dynamic>> _mergeFriendsAndConversations(
    List<Map<String, dynamic>> friends,
    List<Map<String, dynamic>> conversations,
  ) {
    final merged = <Map<String, dynamic>>[];
    final conversationMap = {
      for (var c in conversations) c['other_user_id']: c,
    };

    // Add all friends, preferring conversation data if available
    for (var friend in friends) {
      final friendId = friend['user_id'] as int?;
      if (conversationMap.containsKey(friendId)) {
        // Use conversation data and add friend created_at for sorting
        final conv = conversationMap[friendId]!;
        conv['friend_created_at'] = friend['created_at'];
        merged.add(conv);
      } else {
        // Create conversation-like entry for friend without messages
        merged.add({
          'id': null,
          'other_user_id': friendId,
          'other_user_name': friend['name'],
          'other_user_username': friend['username'],
          'other_user_avatar': friend['avatar_path'],
          'last_message': '',
          'created_at': null,
          'friend_created_at': friend['created_at'],
          'unread_count': 0,
        });
      }
    }

    // Sort by: 1) Pinned first, 2) Latest messages, 3) Longest friendship (oldest friends)
    merged.sort((a, b) {
      // Sort by pinned conversations first
      final aPinned = _pinnedConversations.contains(a['id']);
      final bPinned = _pinnedConversations.contains(b['id']);
      if (aPinned && !bPinned) return -1;
      if (!aPinned && bPinned) return 1;

      // Then sort by latest messages
      final aLastMessageTime = a['created_at'] as DateTime?;
      final bLastMessageTime = b['created_at'] as DateTime?;

      // If both have messages, sort by message timestamp (newest first)
      if (aLastMessageTime != null && bLastMessageTime != null) {
        return bLastMessageTime.compareTo(aLastMessageTime);
      }

      // If only one has messages, that comes first
      if (aLastMessageTime != null && bLastMessageTime == null) return -1;
      if (aLastMessageTime == null && bLastMessageTime != null) return 1;

      // If neither has messages, sort by friendship duration (oldest friends first)
      final aFriendTime = a['friend_created_at'] as DateTime?;
      final bFriendTime = b['friend_created_at'] as DateTime?;
      if (aFriendTime == null || bFriendTime == null) return 0;
      return aFriendTime.compareTo(bFriendTime);
    });

    return merged;
  }

  Future<void> _refreshData() async {
    await _loadData();
  }

  void _togglePin(int? conversationId) {
    if (conversationId == null) return;
    setState(() {
      if (_pinnedConversations.contains(conversationId)) {
        _pinnedConversations.remove(conversationId);
      } else {
        _pinnedConversations.add(conversationId);
      }
      // Re-sort conversations
      _conversations.sort((a, b) {
        final aPinned = _pinnedConversations.contains(a['id']);
        final bPinned = _pinnedConversations.contains(b['id']);
        if (aPinned && !bPinned) return -1;
        if (!aPinned && bPinned) return 1;

        final aTime = a['created_at'] as DateTime?;
        final bTime = b['created_at'] as DateTime?;
        if (aTime == null || bTime == null) return 0;
        return bTime.compareTo(aTime);
      });
    });
  }

  String _formatTime(DateTime? dateTime) {
    if (dateTime == null) return '';

    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d';
    } else {
      return '${dateTime.month}/${dateTime.day}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Messages'),
        backgroundColor: const Color(0xFF1976D2),
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _conversations.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.message_outlined,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No friends yet',
                    style: TextStyle(color: Colors.grey[600], fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Add friends to start messaging',
                    style: TextStyle(color: Colors.grey[500], fontSize: 13),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _refreshData,
              child: ListView.builder(
                itemCount: _conversations.length,
                itemBuilder: (context, index) {
                  final conversation = _conversations[index];
                  final conversationId = conversation['id'] as int?;
                  final otherUserId = conversation['other_user_id'] as int?;
                  final otherUserName =
                      conversation['other_user_name'] as String? ?? 'Unknown';
                  final avatarPath =
                      conversation['other_user_avatar'] as String?;
                  final lastMessage =
                      conversation['last_message'] as String? ?? '';
                  final lastMessageMediaType =
                      conversation['last_message_media_type'] as String?;
                  final messageTime = conversation['created_at'] as DateTime?;
                  final unreadCount = conversation['unread_count'] as int? ?? 0;
                  final lastMessageSenderId =
                      conversation['last_message_sender_id'] as int?;
                  final lastMessageIsRead =
                      conversation['last_message_is_read'] as int?;
                  final isPinned = _pinnedConversations.contains(
                    conversationId,
                  );

                  String? avatarUrl;
                  if (avatarPath != null && avatarPath.isNotEmpty) {
                    avatarUrl = avatarPath.startsWith('/uploads/')
                        ? 'http://${ImageStorageService.SERVER_IP}:${ImageStorageService.SERVER_PORT}$avatarPath'
                        : avatarPath;
                  }

                  // Check if last message is from current user
                  final isLastMessageFromMe =
                      lastMessageSenderId == _currentUserId;

                  // Determine if message is unread from other user
                  final isUnreadFromOther =
                      !isLastMessageFromMe &&
                      lastMessage.isNotEmpty &&
                      lastMessageIsRead == 0;

                  // Display preview message with media indicator
                  String displayMessage = lastMessage;
                  if (lastMessageMediaType == 'image') {
                    displayMessage = '📷 Photo';
                  } else if (lastMessageMediaType == 'video') {
                    displayMessage = '📹 Video';
                  }

                  if (isLastMessageFromMe && lastMessage.isNotEmpty) {
                    displayMessage = 'You: $displayMessage';
                  }

                  return Column(
                    children: [
                      if (index == 0 ||
                          !_pinnedConversations.contains(
                                _conversations[index - 1]['id'] as int?,
                              ) &&
                              isPinned)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              index == 0 && isPinned ? 'Pinned' : 'Messages',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey[600],
                              ),
                            ),
                          ),
                        ),
                      GestureDetector(
                        onTap: () {
                          Navigator.pushNamed(
                            context,
                            '/conversation',
                            arguments: {
                              'otherUser': {
                                'user_id': otherUserId,
                                'name': otherUserName,
                                'avatar_path': avatarPath,
                              },
                              'currentUser': widget.currentUser,
                            },
                          ).then((_) => _refreshData());
                        },
                        onLongPress: conversationId != null
                            ? () {
                                showModalBottomSheet(
                                  context: context,
                                  builder: (context) => Container(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        ListTile(
                                          leading: Icon(
                                            isPinned
                                                ? Icons.close
                                                : Icons.push_pin,
                                            color: const Color(0xFF1976D2),
                                          ),
                                          title: Text(
                                            isPinned ? 'Unpin' : 'Pin',
                                          ),
                                          onTap: () {
                                            Navigator.pop(context);
                                            _togglePin(conversationId);
                                          },
                                        ),
                                        ListTile(
                                          leading: const Icon(
                                            Icons.delete,
                                            color: Colors.red,
                                          ),
                                          title: const Text(
                                            'Delete',
                                            style: TextStyle(color: Colors.red),
                                          ),
                                          onTap: () {
                                            Navigator.pop(context);
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }
                            : null,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          color: unreadCount > 0
                              ? Colors.grey[100]
                              : Colors.transparent,
                          child: Row(
                            children: [
                              Stack(
                                children: [
                                  Container(
                                    width: 56,
                                    height: 56,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Colors.grey[300],
                                      border: Border.all(
                                        color: const Color(0xFF1976D2),
                                        width: 2,
                                      ),
                                      image: avatarUrl != null
                                          ? DecorationImage(
                                              image:
                                                  avatarPath?.startsWith(
                                                        '/uploads/',
                                                      ) ==
                                                      true
                                                  ? NetworkImage(avatarUrl)
                                                  : FileImage(
                                                      File(avatarPath!),
                                                    ),
                                              fit: BoxFit.cover,
                                            )
                                          : null,
                                    ),
                                    child: avatarUrl == null
                                        ? Icon(
                                            Icons.person,
                                            color: Colors.grey[600],
                                            size: 28,
                                          )
                                        : null,
                                  ),
                                  if (isPinned)
                                    Positioned(
                                      top: 0,
                                      right: 0,
                                      child: Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: const BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: Colors.amber,
                                        ),
                                        child: const Icon(
                                          Icons.push_pin,
                                          color: Colors.white,
                                          size: 12,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          otherUserName,
                                          style: TextStyle(
                                            fontWeight: unreadCount > 0
                                                ? FontWeight.w600
                                                : FontWeight.w500,
                                            fontSize: 15,
                                            color: Colors.black87,
                                          ),
                                        ),
                                        Text(
                                          _formatTime(messageTime),
                                          style: TextStyle(
                                            color: Colors.grey[500],
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            lastMessage.isEmpty
                                                ? 'No messages yet'
                                                : displayMessage,
                                            style: TextStyle(
                                              color: lastMessage.isEmpty
                                                  ? Colors.grey[400]
                                                  : isUnreadFromOther
                                                  ? Colors.black87
                                                  : Colors.grey[600],
                                              fontSize: 13,
                                              fontWeight: isUnreadFromOther
                                                  ? FontWeight.w700
                                                  : FontWeight.normal,
                                              fontStyle: lastMessage.isEmpty
                                                  ? FontStyle.italic
                                                  : FontStyle.normal,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        if (unreadCount > 0)
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 2,
                                            ),
                                            decoration: const BoxDecoration(
                                              color: Color(0xFF1976D2),
                                              shape: BoxShape.circle,
                                            ),
                                            child: Text(
                                              unreadCount.toString(),
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Divider(height: 0, color: Colors.grey[200]),
                    ],
                  );
                },
              ),
            ),
    );
  }
}
