import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:equisplit/services/image_storage_service.dart';
import 'package:equisplit/repositories/expense_repository.dart';
import 'package:equisplit/repositories/user_repository.dart';
import 'dart:io';

class ProfilePage extends StatefulWidget {
  final Map<String, dynamic>? user;
  final Map<String, dynamic>? currentUser; // To check if viewing own profile

  const ProfilePage({
    super.key,
    this.user,
    this.currentUser,
  });

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final ImagePicker _imagePicker = ImagePicker();
  final _expenseRepo = ExpenseRepository();
  final _userRepo = UserRepository();
  final _bioController = TextEditingController();
  
  File? _avatarImage;
  String? _avatarImageUrl;
  String? _userBio;
  List<Map<String, dynamic>> _qrImages = [];
  bool _isLoading = true;
  bool _isBioEditing = false;
  late bool _isOwnProfile;

  @override
  void initState() {
    super.initState();
    _isOwnProfile = _checkIfOwnProfile();
    _loadAvatarAndQRCodes();
  }

  @override
  void dispose() {
    _bioController.dispose();
    super.dispose();
  }

  bool _checkIfOwnProfile() {
    final userId = widget.user?['user_id'] ?? widget.user?['id'];
    final currentUserId = widget.currentUser?['user_id'] ?? widget.currentUser?['id'];
    
    // If currentUser is not provided, assume it's own profile (for backward compatibility)
    if (currentUserId == null) return true;
    
    return userId == currentUserId;
  }

  Future<void> _loadAvatarAndQRCodes() async {
    setState(() => _isLoading = true);
    
    try {
      // Test server connectivity first
      print('🔌 Testing server connectivity...');
      final isConnected = await ImageStorageService.testServerConnection();
      if (!isConnected) {
        print('⚠️ Server may not be reachable');
      }
      
      // Handle both 'user_id' and 'id' field names
      final userId = widget.user?['user_id'] ?? widget.user?['id'];
      print('🔍 Loading profile for user: $userId, user data: ${widget.user}');
      print('🔐 Is own profile: $_isOwnProfile');
      
      if (userId != null) {
        // Load avatar from user_avatars table
        final avatarPath = await _userRepo.getUserAvatarPath(userId);
        print('📸 Avatar path from DB: $avatarPath');
        
        if (avatarPath != null && avatarPath.isNotEmpty) {
          // Check if it's a server path (starts with /uploads/) or local path
          if (avatarPath.startsWith('/uploads/')) {
            // Server path - construct full URL
            final imageUrl = ImageStorageService.getImageUrl(avatarPath);
            print('🌐 Loading from server: $imageUrl');
            setState(() {
              _avatarImage = null;
              _avatarImageUrl = imageUrl;
            });
          } else {
            // Local file path - load from device
            final avatarFile = File(avatarPath);
            final exists = await avatarFile.exists();
            print('📁 Avatar file exists: $exists at path: ${avatarFile.path}');
            
            if (exists) {
              setState(() {
                _avatarImage = avatarFile;
                _avatarImageUrl = null;
              });
            } else {
              print('⚠️ Avatar file NOT found at: ${avatarFile.path}');
            }
          }
        } else {
          print('⚠️ No avatar path found in database');
        }
        
        // Load user bio
        final bio = await _userRepo.getUserBio(userId);
        setState(() {
          _userBio = bio;
          _bioController.text = bio ?? '';
        });
        
        // Load QR codes
        final qrCodes = await _expenseRepo.getUserQRCodes(userId);
        
        List<Map<String, dynamic>> loadedQRs = [];
        for (var qrCode in qrCodes) {
          final imagePath = qrCode['image_path'];
          final isDefault = (qrCode['is_default'] as int?) ?? 0;
          
          // Check if it's a server path or local file
          if (imagePath.startsWith('/uploads/')) {
            // Server path - store the URL
            final imageUrl = ImageStorageService.getImageUrl(imagePath);
            loadedQRs.add({
              'id': qrCode['qr_code_id'],
              'label': qrCode['label'],
              'image': null,
              'imageUrl': imageUrl,
              'path': imagePath,
              'isDefault': isDefault == 1,
            });
          } else {
            // Local file path
            final file = File(imagePath);
            if (await file.exists()) {
              loadedQRs.add({
                'id': qrCode['qr_code_id'],
                'label': qrCode['label'],
                'image': file,
                'imageUrl': null,
                'path': imagePath,
                'isDefault': isDefault == 1,
              });
            }
          }
        }
        
        setState(() {
          _qrImages = loadedQRs;
        });
      } else {
        print('❌ No user ID found in widget.user');
      }
    } catch (e) {
      print('Error loading avatar and QR codes: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _pickAvatarImage() async {
    try {
      final XFile? pickedFile =
          await _imagePicker.pickImage(source: ImageSource.gallery);
      if (pickedFile != null) {
        final imageFile = File(pickedFile.path);
        
        // Show loading dialog
        if (mounted) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => const Center(
              child: CircularProgressIndicator(),
            ),
          );
        }
        
        try {
          final savedPath = await ImageStorageService.saveImage(imageFile, 'avatars');
          
          if (mounted) Navigator.pop(context); // Close loading dialog
          
          if (savedPath != null) {
            final userId = widget.user?['user_id'] ?? widget.user?['id'];
            if (userId != null) {
              // Save avatar path to database
              final success = await _userRepo.updateUserAvatar(userId, savedPath);
              
              if (success) {
                // If it's a server path, set the URL; otherwise set the local file
                if (savedPath.startsWith('/uploads/')) {
                  setState(() {
                    _avatarImage = null;
                    _avatarImageUrl = ImageStorageService.getImageUrl(savedPath);
                  });
                } else {
                  setState(() {
                    _avatarImage = File(savedPath);
                    _avatarImageUrl = null;
                  });
                }
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('✅ Avatar uploaded successfully!'),
                      backgroundColor: Color(0xFF1976D2),
                      duration: Duration(seconds: 2),
                    ),
                  );
                }
              } else {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('❌ Failed to save avatar to database'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            }
          } else {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('❌ Failed to upload avatar. Check server connection.'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          }
        } catch (e) {
          if (mounted) Navigator.pop(context); // Close loading dialog
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('❌ Error: $e'),
                backgroundColor: Colors.red,
              ),
            );
          }
          print('❌ Avatar upload error: $e');
        }
      }
    } catch (e) {
      print('❌ Error picking image: $e');
    }
  }

  Future<void> _saveBio() async {
    final userId = widget.user?['user_id'] ?? widget.user?['id'];
    if (userId == null) return;

    final success = await _userRepo.updateUserBio(userId, _bioController.text);
    if (success) {
      setState(() {
        _userBio = _bioController.text;
        _isBioEditing = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Bio updated successfully!'),
            backgroundColor: Color(0xFF1976D2),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ Failed to update bio'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _pickQRImage() async {
    final XFile? pickedFile =
        await _imagePicker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      _showQRLabelDialog(File(pickedFile.path));
    }
  }

  void _showQRLabelDialog(File imageFile) {
    final labelController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Label QR Code'),
        content: TextField(
          controller: labelController,
          decoration: InputDecoration(
            hintText: 'e.g., GCash, PayMaya, Bank...',
            prefixIcon: const Icon(Icons.label),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              if (labelController.text.isNotEmpty) {
                final savedPath = await ImageStorageService.saveImage(imageFile, 'qrcodes');
                
                if (savedPath != null) {
                  final userId = widget.user?['user_id'] ?? widget.user?['id'];
                  if (userId != null) {
                    final success = await _expenseRepo.addUserQRCode(
                      userId: userId,
                      label: labelController.text,
                      imagePath: savedPath,
                    );
                    
                    if (success) {
                      await _loadAvatarAndQRCodes();
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('QR Code added successfully!'),
                            backgroundColor: Color(0xFF1976D2),
                          ),
                        );
                        Navigator.pop(context);
                      }
                    }
                  }
                }
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteQRCode(int qrCodeId, int index) async {
    final success = await _expenseRepo.deleteQRCode(qrCodeId);
    if (success) {
      setState(() {
        _qrImages.removeAt(index);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('QR Code deleted'),
          backgroundColor: Color(0xFF1976D2),
        ),
      );
    }
  }

  void _showQRSelectionDialog(Map<String, dynamic> qrData) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('QR Code Options'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: qrData['imageUrl'] != null
                  ? Image.network(
                      qrData['imageUrl'],
                      height: 200,
                      width: 200,
                      fit: BoxFit.cover,
                    )
                  : Image.file(
                      qrData['image'],
                      height: 200,
                      width: 200,
                      fit: BoxFit.cover,
                    ),
            ),
            const SizedBox(height: 16),
            Text(
              'Label: ${qrData['label']}',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('View'),
          ),
          if (!(qrData['isDefault'] ?? false))
            TextButton(
              onPressed: () async {
                final userId = widget.user?['user_id'] ?? widget.user?['id'];
                if (userId != null) {
                  final success = await _expenseRepo.setDefaultQRCode(userId, qrData['id']);
                  if (success && mounted) {
                    await _loadAvatarAndQRCodes();
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('✅ Set as default payment method'),
                        backgroundColor: Color(0xFF1976D2),
                      ),
                    );
                  }
                }
              },
              child: const Text('Set as Default'),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final userName = widget.user?['name'] ?? 'User';
    final userUsername = widget.user?['username'] ?? 'username';
    
    // Handle null user gracefully
    if (widget.user == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Profile'),
          backgroundColor: const Color(0xFF1976D2),
        ),
        body: const Center(
          child: Text('No user data available'),
        ),
      );
    }

    // View-only mode for other users (Instagram-style with app theme)
    if (!_isOwnProfile) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Profile'),
          backgroundColor: const Color(0xFF1976D2),
          elevation: 0,
          foregroundColor: Colors.white,
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24.0),
                      child: Center(
                        child: Column(
                          children: [
                            // Avatar (Larger)
                            Container(
                              width: 140,
                              height: 140,
                              decoration: BoxDecoration(
                                color: const Color(0xFFF5F5F5),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: const Color(0xFF1976D2),
                                  width: 3,
                                ),
                              ),
                              child: _avatarImage != null
                                  ? ClipOval(
                                      child: Image.file(
                                        _avatarImage!,
                                        fit: BoxFit.cover,
                                      ),
                                    )
                                  : _avatarImageUrl != null
                                      ? ClipOval(
                                          child: Container(
                                            color: Colors.grey[100],
                                            child: Image.network(
                                              _avatarImageUrl!,
                                              fit: BoxFit.cover,
                                              errorBuilder: (context, error, stackTrace) {
                                                return Container(
                                                  decoration: BoxDecoration(
                                                    shape: BoxShape.circle,
                                                    color: Colors.grey[300],
                                                  ),
                                                  child: Icon(
                                                    Icons.person,
                                                    color: Colors.grey[600],
                                                    size: 60,
                                                  ),
                                                );
                                              },
                                            ),
                                          ),
                                        )
                                      : Container(
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: Colors.grey[300],
                                          ),
                                          child: Icon(
                                            Icons.person,
                                            color: Colors.grey[600],
                                            size: 60,
                                          ),
                                        ),
                            ),
                            const SizedBox(height: 16),
                            // Full Name
                            Text(
                              userName,
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1976D2),
                              ),
                            ),
                            const SizedBox(height: 16),
                            // Bio Section
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'About',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF1976D2),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                _userBio != null && _userBio!.isNotEmpty
                                    ? Text(
                                        _userBio!,
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey[700],
                                          height: 1.5,
                                        ),
                                      )
                                    : Text(
                                        'No bio yet',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey[400],
                                          fontStyle: FontStyle.italic,
                                        ),
                                      ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            // Action Buttons (Message Icon)
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: const Color(0xFF1976D2),
                                  ),
                                  child: IconButton(
                                    onPressed: () {
                                      final otherUserId = widget.user?['user_id'] ?? widget.user?['id'];
                                      Navigator.pushNamed(
                                        context,
                                        '/conversation',
                                        arguments: {
                                          'otherUser': {
                                            'user_id': otherUserId,
                                            'name': userName,
                                            'avatar_path': widget.user?['avatar_path'],
                                          },
                                          'currentUser': widget.currentUser,
                                        },
                                      );
                                    },
                                    icon: const Icon(
                                      Icons.message,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
      );
    }

    // Edit mode for own profile
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        backgroundColor: const Color(0xFF1976D2),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Column(
                children: [
                  GestureDetector(
                    onTap: _pickAvatarImage,
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F5F5),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFF1976D2),
                          width: 3,
                        ),
                      ),
                      child: _avatarImage != null
                          ? ClipOval(
                              child: Image.file(
                                _avatarImage!,
                                fit: BoxFit.cover,
                              ),
                            )
                          : _avatarImageUrl != null
                              ? ClipOval(
                                  child: Container(
                                    color: Colors.grey[100],
                                    child: Image.network(
                                      _avatarImageUrl!,
                                      fit: BoxFit.cover,
                                      loadingBuilder: (context, child, loadingProgress) {
                                        if (loadingProgress == null) {
                                          print('✅ Avatar image loaded successfully');
                                          return child;
                                        }
                                        return Center(
                                          child: CircularProgressIndicator(
                                            value: loadingProgress.expectedTotalBytes != null
                                                ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                                                : null,
                                          ),
                                        );
                                      },
                                      errorBuilder: (context, error, stackTrace) {
                                        print('❌ Avatar load error: $error');
                                        print('🔗 URL: $_avatarImageUrl');
                                        print('📋 Stack: $stackTrace');
                                        return Container(
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: Colors.grey[300],
                                          ),
                                          child: Column(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Icon(
                                                Icons.cloud_off,
                                                color: Colors.grey[600],
                                                size: 30,
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                'Load failed',
                                                style: TextStyle(
                                                  color: Colors.grey[600],
                                                  fontSize: 10,
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                )
                              : Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(
                                      Icons.camera_alt,
                                      color: Color(0xFF1976D2),
                                      size: 40,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      userName[0].toUpperCase(),
                                      style: const TextStyle(
                                        color: Color(0xFF1976D2),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 36,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Tap to change avatar',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            const Text(
              'User Information',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    _buildInfoRow('Name', userName),
                    const Divider(),
                    _buildInfoRow('Username', userUsername),
                    const Divider(),
                    _buildInfoRow('User ID', (widget.user?['user_id'] ?? widget.user?['id']).toString()),
                    const Divider(),
                    _buildInfoRow('User Type', widget.user?['user_type'] ?? 'Employee'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),

            // Bio Section
            const Text(
              'About Me',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            if (_isBioEditing)
              Column(
                children: [
                  TextField(
                    controller: _bioController,
                    maxLines: 4,
                    maxLength: 200,
                    decoration: InputDecoration(
                      hintText: 'Tell your friends about yourself...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      prefixIcon: const Padding(
                        padding: EdgeInsets.only(top: 12),
                        child: Icon(Icons.edit),
                      ),
                      counterText: '${_bioController.text.length}/200',
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _isBioEditing = false;
                            _bioController.text = _userBio ?? '';
                          });
                        },
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: _saveBio,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1976D2),
                        ),
                        child: const Text('Save'),
                      ),
                    ],
                  ),
                ],
              )
            else
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        _userBio?.isEmpty ?? true ? 'Add a bio...' : _userBio!,
                        style: TextStyle(
                          fontSize: 14,
                          color: (_userBio?.isEmpty ?? true) ? Colors.grey[400] : Colors.grey[700],
                          fontStyle: (_userBio?.isEmpty ?? true) ? FontStyle.italic : FontStyle.normal,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit, color: Color(0xFF1976D2)),
                      onPressed: () {
                        setState(() => _isBioEditing = true);
                      },
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 32),

            const Text(
              'Payment QR Codes',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _pickQRImage,
              icon: const Icon(Icons.add),
              label: const Text('Add QR Code'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1976D2),
              ),
            ),
            const SizedBox(height: 16),
            if (_isOwnProfile)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  border: Border.all(color: Colors.blue.shade200),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info, color: Colors.blue, size: 16),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Tap a QR code to set it as your default payment method',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.blue,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 16),
            if (_isLoading)
              const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1976D2)),
                ),
              )
            else if (_qrImages.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 32.0),
                  child: Text(
                    'No QR codes added yet\nAdd payment methods like GCash, PayMaya',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              )
            else
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                itemCount: _qrImages.length,
                itemBuilder: (context, index) {
                  final qrData = _qrImages[index];
                  final isDefault = qrData['isDefault'] ?? false;
                  
                  return Stack(
                    children: [
                      GestureDetector(
                        onTap: () {
                          if (_isOwnProfile) {
                            // Show selection dialog
                            _showQRSelectionDialog(qrData);
                          } else {
                            // Just show the image
                            showDialog(
                              context: context,
                              builder: (context) => Dialog(
                                child: qrData['imageUrl'] != null
                                    ? Image.network(qrData['imageUrl'])
                                    : Image.file(qrData['image']),
                              ),
                            );
                          }
                        },
                        child: Card(
                          elevation: 3,
                          color: isDefault ? Colors.blue.shade50 : Colors.white,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(
                                child: ClipRRect(
                                  borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(4),
                                  ),
                                  child: qrData['imageUrl'] != null
                                      ? Image.network(
                                          qrData['imageUrl'],
                                          fit: BoxFit.cover,
                                          loadingBuilder: (context, child, loadingProgress) {
                                            if (loadingProgress == null) {
                                              print('✅ QR image loaded: ${qrData["imageUrl"]}');
                                              return child;
                                            }
                                            return Container(
                                              color: Colors.grey[200],
                                              child: Center(
                                                child: CircularProgressIndicator(
                                                  value: loadingProgress.expectedTotalBytes != null
                                                      ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                                                      : null,
                                                ),
                                              ),
                                            );
                                          },
                                          errorBuilder: (context, error, stackTrace) {
                                            print('❌ QR load error: $error');
                                            print('🔗 URL: ${qrData["imageUrl"]}');
                                            return Container(
                                              color: Colors.grey[300],
                                              child: Column(
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                children: [
                                                  const Icon(Icons.error, color: Colors.red),
                                                  Text(
                                                    'Error: $error',
                                                    style: const TextStyle(fontSize: 8, color: Colors.red),
                                                    textAlign: TextAlign.center,
                                                  ),
                                                ],
                                              ),
                                            );
                                          },
                                        )
                                      : Image.file(
                                          qrData['image'],
                                          fit: BoxFit.cover,
                                        ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Column(
                                  children: [
                                    if (isDefault)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.blue,
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: const Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.check, color: Colors.white, size: 12),
                                            SizedBox(width: 4),
                                            Text(
                                              'Default',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    const SizedBox(height: 4),
                                    Text(
                                      qrData['label'],
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                      textAlign: TextAlign.center,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Positioned(
                        top: 4,
                        right: 4,
                        child: GestureDetector(
                          onTap: () {
                            _deleteQRCode(qrData['id'], index);
                          },
                          child: Container(
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                            padding: const EdgeInsets.all(4),
                            child: const Icon(
                              Icons.close,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.w500,
            color: Colors.grey,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
