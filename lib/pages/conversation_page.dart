import 'package:flutter/material.dart';
import 'package:equisplit/repositories/messaging_repository.dart';
import 'package:equisplit/services/image_storage_service.dart';
import 'package:equisplit/widgets/video_player_widget.dart';
import 'package:equisplit/widgets/custom_loading_indicator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:io';
import 'dart:convert';
import 'dart:async';

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
  final _imagePicker = ImagePicker();

  late int _conversationId;
  int? _currentUserId;
  int? _otherUserId;
  List<Map<String, dynamic>> _messages = [];
  bool _isLoading = true;
  final bool _isSending = false;
  bool _isUploadingMedia = false;
  Timer? _pollingTimer;
  final Set<String> _sendingMessageIds = {}; // Track messages being sent

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
      _startPolling();
    }
  }

  void _startPolling() {
    _pollingTimer = Timer.periodic(const Duration(seconds: 2), (timer) async {
      if (!mounted) {
        timer.cancel();
        return;
      }
      await _checkForNewMessages();
    });
  }

  Future<void> _checkForNewMessages() async {
    final messages = await _messagingRepo.getMessages(_conversationId);
    if (!mounted) return;
    
    if (messages.length > _messages.length) {
      setState(() => _messages = messages);
      _scrollToBottom();
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

    _messageController.clear();
    
    // Create temporary message ID (negative to avoid conflicts)
    final tempId = -DateTime.now().millisecondsSinceEpoch;
    
    // Add message optimistically to UI
    final tempMessage = {
      'id': tempId,
      'sender_id': _currentUserId,
      'content': content,
      'created_at': DateTime.now(),
      'media_type': 'text',
      'media_url': null,
      'is_sending': true, // Mark as sending
    };
    
    setState(() {
      _messages.add(tempMessage);
      _sendingMessageIds.add(tempId.toString());
    });
    _scrollToBottom();

    // Send to server
    final success = await _messagingRepo.sendMessage(
      _conversationId,
      _currentUserId!,
      _otherUserId!,
      content,
    );
    
    if (success) {
      // Reload messages first
      await _loadMessages();
      // Then remove temp message
      setState(() {
        _messages.removeWhere((m) => m['id'] == tempId);
        _sendingMessageIds.remove(tempId.toString());
      });
    } else {
      // If failed, just remove the temp message
      setState(() {
        _messages.removeWhere((m) => m['id'] == tempId);
        _sendingMessageIds.remove(tempId.toString());
      });
    }
  }

  Future<void> _pickAndSendMedia(ImageSource source, bool isVideo) async {
    if (_currentUserId == null || _otherUserId == null) return;

    try {
      setState(() => _isUploadingMedia = true);

      final XFile? pickedFile = isVideo
          ? await _imagePicker.pickVideo(source: source)
          : await _imagePicker.pickImage(source: source);

      if (pickedFile == null) {
        setState(() => _isUploadingMedia = false);
        return;
      }

      // Check video duration if it's a video
      if (isVideo) {
        final videoController = VideoPlayerController.file(File(pickedFile.path));
        try {
          await videoController.initialize();
          final duration = videoController.value.duration;
          
          if (duration.inSeconds > 30) {
            setState(() => _isUploadingMedia = false);
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Video must be 30 seconds or less'),
                  backgroundColor: Colors.red,
                  duration: Duration(seconds: 3),
                ),
              );
            }
            await videoController.dispose();
            return;
          }
          await videoController.dispose();
        } catch (e) {
          await videoController.dispose();
          setState(() => _isUploadingMedia = false);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error checking video duration: $e'),
                backgroundColor: Colors.red,
              ),
            );
          }
          return;
        }
      }

      // Upload to server
      final uri = Uri.parse(
        'http://${ImageStorageService.SERVER_IP}:${ImageStorageService.SERVER_PORT}/api/upload/chat',
      );
      final request = http.MultipartRequest('POST', uri);
      request.files.add(
        await http.MultipartFile.fromPath('file', pickedFile.path),
      );

      final response = await request.send();
      final responseBody = await response.stream.bytesToString();
      final jsonResponse = json.decode(responseBody);

      if (jsonResponse['success'] == true) {
        final filePath = jsonResponse['filePath'];
        final mimeType = jsonResponse['mimeType'] as String?;

        // Determine media type based on isVideo flag, MIME type, or file extension
        String mediaType = isVideo ? 'video' : 'image';
        if (mimeType != null && mimeType.startsWith('video/')) {
          mediaType = 'video';
        } else if (filePath.toLowerCase().endsWith('.mp4') ||
            filePath.toLowerCase().endsWith('.mov') ||
            filePath.toLowerCase().endsWith('.avi') ||
            filePath.toLowerCase().endsWith('.mkv')) {
          mediaType = 'video';
        }

        print('🎬 Media type determined: $mediaType (isVideo=$isVideo, mimeType=$mimeType, filePath=$filePath)');

        // Add message optimistically to UI
        final tempId = -DateTime.now().millisecondsSinceEpoch;
        final tempMessage = {
          'id': tempId,
          'sender_id': _currentUserId,
          'content': isVideo ? '📹 Video' : '📷 Photo',
          'created_at': DateTime.now(),
          'media_type': mediaType,
          'media_url': filePath,
          'is_sending': true,
        };
        
        setState(() {
          _messages.add(tempMessage);
          _sendingMessageIds.add(tempId.toString());
          _isUploadingMedia = false;
        });
        _scrollToBottom();

        // Send message with media (save full path like avatars)
        final success = await _messagingRepo.sendMessage(
          _conversationId,
          _currentUserId!,
          _otherUserId!,
          isVideo ? '📹 Video' : '📷 Photo',
          mediaType: mediaType,
          mediaUrl: filePath,
        );

        if (success) {
          // Reload messages first
          await _loadMessages();
          // Then remove temp message
          setState(() {
            _messages.removeWhere((m) => m['id'] == tempId);
            _sendingMessageIds.remove(tempId.toString());
          });
        } else {
          // If failed, just remove the temp message
          setState(() {
            _messages.removeWhere((m) => m['id'] == tempId);
            _sendingMessageIds.remove(tempId.toString());
          });
        }
      } else {
        setState(() => _isUploadingMedia = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to upload media')),
          );
        }
      }
    } catch (e) {
      print('Error uploading media: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      setState(() => _isUploadingMedia = false);
    }
  }

  Future<void> _pickAndSendFile() async {
    if (_currentUserId == null || _otherUserId == null) return;

    try {
      setState(() => _isUploadingMedia = true);

      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
      );

      if (result == null || result.files.isEmpty) {
        setState(() => _isUploadingMedia = false);
        return;
      }

      final file = result.files.first;
      final filePath = file.path;

      if (filePath == null) {
        setState(() => _isUploadingMedia = false);
        return;
      }

      // Check file size (max 70MB)
      final fileSize = file.size;
      if (fileSize > 70 * 1024 * 1024) {
        setState(() => _isUploadingMedia = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('File must be 70MB or less'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 3),
            ),
          );
        }
        return;
      }

      // Upload to server
      final uri = Uri.parse(
        'http://${ImageStorageService.SERVER_IP}:${ImageStorageService.SERVER_PORT}/api/upload/chat',
      );
      final request = http.MultipartRequest('POST', uri);
      request.files.add(
        await http.MultipartFile.fromPath('file', filePath),
      );

      final response = await request.send();
      final responseBody = await response.stream.bytesToString();
      final jsonResponse = json.decode(responseBody);

      if (jsonResponse['success'] == true) {
        final uploadedPath = jsonResponse['filePath'];
        final fileName = file.name;

        print('📎 File uploaded: $uploadedPath (size: ${_formatFileSize(fileSize)})');

        // Add message optimistically to UI
        final tempId = -DateTime.now().millisecondsSinceEpoch;
        final tempMessage = {
          'id': tempId,
          'sender_id': _currentUserId,
          'content': '📎 $fileName',
          'created_at': DateTime.now(),
          'media_type': 'file',
          'media_url': uploadedPath,
          'is_sending': true,
        };
        
        setState(() {
          _messages.add(tempMessage);
          _sendingMessageIds.add(tempId.toString());
          _isUploadingMedia = false;
        });
        _scrollToBottom();

        // Send message with file
        final success = await _messagingRepo.sendMessage(
          _conversationId,
          _currentUserId!,
          _otherUserId!,
          '📎 $fileName',
          mediaType: 'file',
          mediaUrl: uploadedPath,
        );

        if (success) {
          // Reload messages first
          await _loadMessages();
          // Then remove temp message
          setState(() {
            _messages.removeWhere((m) => m['id'] == tempId);
            _sendingMessageIds.remove(tempId.toString());
          });
        } else {
          // If failed, just remove the temp message
          setState(() {
            _messages.removeWhere((m) => m['id'] == tempId);
            _sendingMessageIds.remove(tempId.toString());
          });
        }
      } else {
        setState(() => _isUploadingMedia = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to upload file')),
          );
        }
      }
    } catch (e) {
      print('Error uploading file: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      setState(() => _isUploadingMedia = false);
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)}GB';
  }

  String _getFileIcon(String fileName) {
    final extension = fileName.split('.').last.toLowerCase();
    switch (extension) {
      case 'pdf':
        return '📄';
      case 'doc':
      case 'docx':
        return '📝';
      case 'xls':
      case 'xlsx':
      case 'csv':
        return '📊';
      case 'ppt':
      case 'pptx':
        return '📽️';
      case 'zip':
      case 'rar':
      case '7z':
        return '🗜️';
      case 'apk':
        return '📦';
      case 'txt':
        return '📃';
      case 'mp3':
      case 'wav':
      case 'flac':
        return '🎵';
      default:
        return '📎';
    }
  }

  Future<void> _downloadFile(String filePath, String fileName) async {
    try {
      print('📥 Downloading file: $fileName from $filePath');

      // Use Downloads folder
      final downloadDir = Directory('/storage/emulated/0/Download');
      
      if (!await downloadDir.exists()) {
        await downloadDir.create(recursive: true);
      }

      final downloadPath = '${downloadDir.path}/$fileName';

      // Check if file already exists
      if (await File(downloadPath).exists()) {
        // Add timestamp to filename
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final fileExt = fileName.split('.').last;
        final baseName = fileName.substring(0, fileName.length - fileExt.length - 1);
        fileName = '${baseName}_$timestamp.$fileExt';
      }

      final finalPath = '${downloadDir.path}/$fileName';

      // Download from server
      final fileUrl = 'http://${ImageStorageService.SERVER_IP}:${ImageStorageService.SERVER_PORT}$filePath';
      final response = await http.get(Uri.parse(fileUrl));

      if (response.statusCode == 200) {
        final file = File(finalPath);
        await file.writeAsBytes(response.bodyBytes);

        // Trigger media scan
        if (Platform.isAndroid) {
          try {
            await Process.run('am', [
              'broadcast',
              '-a',
              'android.intent.action.MEDIA_SCANNER_SCAN_FILE',
              '-d',
              'file://$finalPath'
            ]);
          } catch (e) {
            print('⚠️ Media scan failed: $e');
          }
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ Downloaded: $fileName'),
              backgroundColor: Colors.green,
              action: SnackBarAction(
                label: 'Open Folder',
                textColor: Colors.white,
                onPressed: () async {
                  // Open file manager to downloads folder
                  final uri = Uri.parse('content://com.android.externalstorage.documents/document/primary:Download');
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri);
                  }
                },
              ),
            ),
          );
        }
      } else {
        throw Exception('Failed to download: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Download error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Download failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showMediaOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(
                Icons.photo_library,
                color: Color(0xFF1976D2),
              ),
              title: const Text('Photo Library'),
              onTap: () {
                Navigator.pop(context);
                _pickAndSendMedia(ImageSource.gallery, false);
              },
            ),
            ListTile(
              leading: const Icon(Icons.videocam, color: Color(0xFF1976D2)),
              title: const Text('Video Library'),
              onTap: () {
                Navigator.pop(context);
                _pickAndSendMedia(ImageSource.gallery, true);
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Color(0xFF1976D2)),
              title: const Text('Take Photo'),
              onTap: () {
                Navigator.pop(context);
                _pickAndSendMedia(ImageSource.camera, false);
              },
            ),
            ListTile(
              leading: const Icon(Icons.video_call, color: Color(0xFF1976D2)),
              title: const Text('Record Video'),
              onTap: () {
                Navigator.pop(context);
                _pickAndSendMedia(ImageSource.camera, true);
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.attach_file, color: Color(0xFF1976D2)),
              title: const Text('Send File'),
              subtitle: const Text('PDF, APK, ZIP, etc. (max 70MB)'),
              onTap: () {
                Navigator.pop(context);
                _pickAndSendFile();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteMessage(int messageId) async {
    if (_currentUserId == null) return;

    final success = await _messagingRepo.deleteMessage(
      messageId,
      _currentUserId!,
    );
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
              title: const Text(
                'Delete Message',
                style: TextStyle(color: Colors.red),
              ),
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
      // Format as 12-hour with AM/PM
      int hour = dateTime.hour;
      String period = hour >= 12 ? 'PM' : 'AM';
      hour = hour % 12;
      if (hour == 0) hour = 12;
      return '$hour:${dateTime.minute.toString().padLeft(2, '0')} $period';
    } else if (messageDate == yesterday) {
      return 'Yesterday';
    } else {
      return '${dateTime.month}/${dateTime.day}/${dateTime.year}';
    }
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
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
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
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
                ? Center(child: CustomLoadingIndicator())
                : _messages.isEmpty
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
                          'No messages yet',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Start a conversation',
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(
                      vertical: 16,
                      horizontal: 12,
                    ),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final message = _messages[index];
                      final messageId = message['id'] as int?;
                      final isSent = message['sender_id'] == _currentUserId;

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

                      // Get media info - handle Blob types
                      String? mediaType;
                      final mediaTypeRaw = message['media_type'];
                      if (mediaTypeRaw is String) {
                        mediaType = mediaTypeRaw;
                      } else if (mediaTypeRaw is List<int>) {
                        mediaType = String.fromCharCodes(mediaTypeRaw);
                      }

                      String? mediaUrl;
                      final mediaUrlRaw = message['media_url'];
                      if (mediaUrlRaw is String) {
                        mediaUrl = mediaUrlRaw;
                      } else if (mediaUrlRaw is List<int>) {
                        mediaUrl = String.fromCharCodes(mediaUrlRaw);
                      }

                      final isMediaMessage =
                          mediaType != null &&
                          mediaType != 'text' &&
                          mediaUrl != null;

                      // Debug logging
                      if (mediaType != null || mediaUrl != null) {
                        print(
                          '📸 Message: mediaType=$mediaType, mediaUrl=$mediaUrl, isMediaMessage=$isMediaMessage',
                        );
                      }

                      // Handle both DateTime and String types and add 8 hours for timezone adjustment
                      final createdAt = (message['created_at'] is DateTime
                          ? message['created_at'] as DateTime
                          : DateTime.parse(message['created_at'] as String)).add(const Duration(hours: 8));

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
                                          image:
                                              avatarPath?.startsWith(
                                                    '/uploads/',
                                                  ) ==
                                                  true
                                              ? NetworkImage(avatarUrl)
                                              : FileImage(File(avatarPath!)),
                                          fit: BoxFit.cover,
                                        )
                                      : null,
                                ),
                              ),
                              const SizedBox(width: 8),
                            ],
                            Flexible(
                              child: GestureDetector(
                                onLongPress: isSent
                                    ? () => _showMessageOptions(
                                        messageId ?? 0,
                                        isSent,
                                      )
                                    : null,
                                child: Column(
                                  crossAxisAlignment: isSent
                                      ? CrossAxisAlignment.end
                                      : CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      padding: isMediaMessage
                                          ? const EdgeInsets.all(4)
                                          : const EdgeInsets.symmetric(
                                              vertical: 8,
                                              horizontal: 12,
                                            ),
                                      decoration: BoxDecoration(
                                        color: isSent
                                            ? const Color(0xFF1976D2)
                                            : Colors.grey[300],
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: isMediaMessage
                                          ? Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                if (mediaType == 'image')
                                                  GestureDetector(
                                                    onTap: () {
                                                      // Show full-screen image
                                                      final imageUrl =
                                                          'http://${ImageStorageService.SERVER_IP}:${ImageStorageService.SERVER_PORT}$mediaUrl';
                                                      Navigator.push(
                                                        context,
                                                        PageRouteBuilder(
                                                          opaque: false,
                                                          barrierColor: Colors.black,
                                                          pageBuilder: (context, _, __) => _FullScreenImageViewer(imageUrl: imageUrl),
                                                          transitionsBuilder: (context, animation, secondaryAnimation, child) {
                                                            return FadeTransition(
                                                              opacity: animation,
                                                              child: child,
                                                            );
                                                          },
                                                        ),
                                                      );
                                                    },
                                                    child: ClipRRect(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            8,
                                                          ),
                                                      child: Builder(
                                                        builder: (context) {
                                                          // Use path from database directly like avatars
                                                          final imageUrl =
                                                              'http://${ImageStorageService.SERVER_IP}:${ImageStorageService.SERVER_PORT}$mediaUrl';
                                                          print(
                                                            '🖼️ Loading image: $imageUrl',
                                                          );
                                                          return Image.network(
                                                            imageUrl,
                                                            width: 200,
                                                            height: 150,
                                                            fit: BoxFit.cover,
                                                            errorBuilder:
                                                                (
                                                                  context,
                                                                  error,
                                                                  stackTrace,
                                                                ) {
                                                                  print(
                                                                    '❌ Image load error: $error',
                                                                  );
                                                                  return Container(
                                                                    width: 200,
                                                                    height: 150,
                                                                    color: Colors
                                                                        .grey[400],
                                                                    child: const Icon(
                                                                      Icons
                                                                          .broken_image,
                                                                      size: 50,
                                                                    ),
                                                                  );
                                                                },
                                                            loadingBuilder:
                                                                (
                                                                  context,
                                                                  child,
                                                                  loadingProgress,
                                                                ) {
                                                                  if (loadingProgress ==
                                                                      null) {
                                                                    return child;
                                                                  }
                                                                  return Container(
                                                                    width: 200,
                                                                    height: 150,
                                                                    alignment:
                                                                        Alignment
                                                                            .center,
                                                                    child: CircularProgressIndicator(
                                                                      value:
                                                                          loadingProgress.expectedTotalBytes !=
                                                                              null
                                                                          ? loadingProgress.cumulativeBytesLoaded /
                                                                                loadingProgress.expectedTotalBytes!
                                                                          : null,
                                                                    ),
                                                                  );
                                                                },
                                                          );
                                                        },
                                                      ),
                                                    ),
                                                  )
                                                else if (mediaType == 'video')
                                                  VideoPlayerWidget(
                                                    videoUrl:
                                                        'http://${ImageStorageService.SERVER_IP}:${ImageStorageService.SERVER_PORT}$mediaUrl',
                                                  )
                                                else if (mediaType == 'file')
                                                  GestureDetector(
                                                    onTap: () => _downloadFile(mediaUrl ?? '', content.replaceFirst('📎 ', '')),
                                                    child: Container(
                                                      padding: const EdgeInsets.all(12),
                                                      decoration: BoxDecoration(
                                                        color: isSent
                                                            ? Colors.white.withOpacity(0.2)
                                                            : Colors.white,
                                                        borderRadius: BorderRadius.circular(8),
                                                      ),
                                                      child: Row(
                                                        mainAxisSize: MainAxisSize.min,
                                                        children: [
                                                          Text(
                                                            _getFileIcon(content.replaceFirst('📎 ', '')),
                                                            style: const TextStyle(fontSize: 32),
                                                          ),
                                                          const SizedBox(width: 12),
                                                          Flexible(
                                                            child: Column(
                                                              crossAxisAlignment: CrossAxisAlignment.start,
                                                              children: [
                                                                Text(
                                                                  content.replaceFirst('📎 ', ''),
                                                                  style: TextStyle(
                                                                    color: isSent
                                                                        ? Colors.white
                                                                        : Colors.black87,
                                                                    fontSize: 14,
                                                                    fontWeight: FontWeight.w500,
                                                                  ),
                                                                  maxLines: 2,
                                                                  overflow: TextOverflow.ellipsis,
                                                                ),
                                                                const SizedBox(height: 4),
                                                                Text(
                                                                  'Tap to download',
                                                                  style: TextStyle(
                                                                    color: isSent
                                                                        ? Colors.white70
                                                                        : Colors.grey[600],
                                                                    fontSize: 12,
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                          ),
                                                          const SizedBox(width: 8),
                                                          Icon(
                                                            Icons.download,
                                                            color: isSent ? Colors.white : const Color(0xFF1976D2),
                                                            size: 20,
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                                if (content.isNotEmpty &&
                                                    content != '📷 Photo' &&
                                                    content != '📹 Video' &&
                                                    !content.startsWith('📎 '))
                                                  Padding(
                                                    padding:
                                                        const EdgeInsets.only(
                                                          top: 4,
                                                          left: 8,
                                                          right: 8,
                                                          bottom: 4,
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
                                              ],
                                            )
                                          : Text(
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
                                        horizontal: 8,
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          // Show sending indicator
                                          if (message['is_sending'] == true) ...[
                                            const SizedBox(
                                              width: 12,
                                              height: 12,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 1.5,
                                                valueColor: AlwaysStoppedAnimation<Color>(Colors.grey),
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              'Sending...',
                                              style: TextStyle(
                                                color: Colors.grey[600],
                                                fontSize: 11,
                                                fontStyle: FontStyle.italic,
                                              ),
                                            ),
                                          ] else ...[
                                            Text(
                                              _formatTime(createdAt),
                                              style: TextStyle(
                                                color: Colors.grey[500],
                                                fontSize: 11,
                                              ),
                                            ),
                                            if (isSent) ...[
                                              const SizedBox(width: 6),
                                              Text(
                                                message['is_read'] == 1 ? '• Seen' : '• Delivered',
                                                style: TextStyle(
                                                  color: message['is_read'] == 1 ? Colors.blue[700] : Colors.grey[500],
                                                  fontSize: 10,
                                                  fontWeight: message['is_read'] == 1 ? FontWeight.w500 : FontWeight.normal,
                                                ),
                                              ),
                                            ],
                                          ],
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            if (isSent) const SizedBox(width: 8),
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
              border: Border(top: BorderSide(color: Colors.grey[300]!)),
            ),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  if (_isUploadingMedia)
                    const Padding(
                      padding: EdgeInsets.only(right: 8),
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  else
                    IconButton(
                      icon: const Icon(Icons.attach_file),
                      color: const Color(0xFF1976D2),
                      onPressed: _showMediaOptions,
                    ),
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
                      enabled: !_isUploadingMedia,
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
                      icon: const Icon(Icons.send),
                      color: Colors.white,
                      onPressed: _isUploadingMedia ? null : _sendMessage,
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

// Full-screen image viewer with professional design
class _FullScreenImageViewer extends StatefulWidget {
  final String imageUrl;

  const _FullScreenImageViewer({required this.imageUrl});

  @override
  State<_FullScreenImageViewer> createState() => _FullScreenImageViewerState();
}

class _FullScreenImageViewerState extends State<_FullScreenImageViewer> {
  bool _showControls = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: () {
          setState(() => _showControls = !_showControls);
        },
        child: Stack(
          children: [
            // Image with pinch-to-zoom
            Center(
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 4.0,
                child: Image.network(
                  widget.imageUrl,
                  fit: BoxFit.contain,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Center(
                      child: CircularProgressIndicator(
                        value: loadingProgress.expectedTotalBytes != null
                            ? loadingProgress.cumulativeBytesLoaded /
                                loadingProgress.expectedTotalBytes!
                            : null,
                        color: const Color(0xFF1976D2),
                      ),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) {
                    return const Center(
                      child: Icon(
                        Icons.broken_image,
                        color: Colors.white54,
                        size: 80,
                      ),
                    );
                  },
                ),
              ),
            ),
            // Top gradient with back button
            AnimatedOpacity(
              opacity: _showControls ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 300),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withOpacity(0.7),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: SafeArea(
                  child: Row(
                    children: [
                      Container(
                        margin: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.3),
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          icon: const Icon(
                            Icons.close,
                            color: Colors.white,
                            size: 28,
                          ),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ),
                      const Spacer(),
                      Container(
                        margin: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.3),
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          icon: const Icon(
                            Icons.download_rounded,
                            color: Colors.white,
                            size: 28,
                          ),
                          onPressed: () async {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Downloading image...'),
                                duration: Duration(seconds: 2),
                              ),
                            );
                            try {
                              final response = await http.get(Uri.parse(widget.imageUrl));
                              final directory = await getExternalStorageDirectory();
                              final fileName = 'equisplit_${DateTime.now().millisecondsSinceEpoch}.jpg';
                              final filePath = '${directory!.path}/$fileName';
                              final file = File(filePath);
                              await file.writeAsBytes(response.bodyBytes);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Saved to $filePath'),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                              }
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Download failed: $e'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
