import 'package:flutter/material.dart';
import 'package:equisplit/services/image_storage_service.dart';
import 'package:equisplit/repositories/expense_repository.dart';
import 'package:equisplit/repositories/user_repository.dart';
import 'package:equisplit/widgets/custom_loading_indicator.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

class ExpenseDetailsPage extends StatefulWidget {
  final int expenseId;
  final Map<String, dynamic>? currentUser;

  const ExpenseDetailsPage({
    super.key,
    required this.expenseId,
    this.currentUser,
  });

  @override
  State<ExpenseDetailsPage> createState() => _ExpenseDetailsPageState();
}

class _ExpenseDetailsPageState extends State<ExpenseDetailsPage>
    with TickerProviderStateMixin {
  late ExpenseRepository _expenseRepo;
  late UserRepository _userRepo;
  late TabController _tabController;

  Map<String, dynamic>? expenseDetails;
  List<Map<String, dynamic>> participants = [];
  List<Map<String, dynamic>> transactions = [];
  bool isLoading = true;
  int? currentUserId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _initializeServices();
    _loadExpenseDetails();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _initializeServices() {
    _expenseRepo = ExpenseRepository();
    _userRepo = UserRepository();
    // Get current user ID from widget
    if (widget.currentUser != null) {
      currentUserId = widget.currentUser!['id'] ?? widget.currentUser!['user_id'];
    }
    print('Current User ID: $currentUserId');
  }

  Future<void> _loadExpenseDetails() async {
    try {
      // Get expense details (includes creator_name from LEFT JOIN)
      final expense = await _expenseRepo.getExpenseById(widget.expenseId);
      
      if (expense != null) {
        print('Creator name: ${expense['creator_name']}');
      }

      // Get all participants and their contributions
      final participantsList = await _expenseRepo.getExpenseParticipants(widget.expenseId);
      print('Loaded participants: ${participantsList.length}');
      for (var p in participantsList) {
        print('Participant: ${p['name']}, avatar: ${p['avatar_path']}');
      }

      // Get all transactions for this expense
      final transactionsList = await _expenseRepo.getExpenseTransactions(widget.expenseId);
      print('Loaded transactions: ${transactionsList.length}');
      for (var t in transactionsList) {
        print('Transaction: ${t['payer_name']} -> ${t['payee_name']}');
        print('  Payer avatar: ${t['payer_avatar']}');
        print('  Payee avatar: ${t['payee_avatar']}');
      }

      if (mounted) {
        setState(() {
          expenseDetails = expense;
          participants = participantsList;
          transactions = transactionsList;
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading expense details: $e')),
        );
        setState(() => isLoading = false);
      }
    }
  }

  Future<int> _getAndroidVersion() async {
    if (!Platform.isAndroid) return 0;
    try {
      final androidVersion = await _getAndroidInfo();
      return androidVersion;
    } catch (e) {
      print('Error getting Android version: $e');
      return 30; // Default to Android 11+ to be safe
    }
  }

  Future<int> _getAndroidInfo() async {
    // This is a placeholder - in a real app you'd use device_info_plus
    // For now, we'll assume Android 11+ if on Android
    if (Platform.isAndroid) {
      return 30; // Default to assume Android 11+
    }
    return 0;
  }

  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return '${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}/${date.year}';
    } catch (e) {
      return dateString;
    }
  }

  String _getExpenseTypeLabel(String expenseType) {
    switch (expenseType.toLowerCase()) {
      case 'borrowed':
        return 'Borrowed Money';
      case 'partial':
        return 'Non-Contributors Pay';
      case 'evenly':
      default:
        return 'Evenly Split';
    }
  }

  Future<void> _downloadQRCode(String qrImagePath, String payeeName) async {
    try {
      print('📥 Starting download from: $qrImagePath');
      
      // Request permission for Android
      if (Platform.isAndroid) {
        final androidVersion = await _getAndroidVersion();
        print('📱 Android API Level: $androidVersion');
        
        // First check current permission status BEFORE requesting
        PermissionStatus currentStatus;
        if (androidVersion >= 30) {
          currentStatus = await Permission.manageExternalStorage.status;
          print('📋 Current MANAGE_EXTERNAL_STORAGE status: $currentStatus');
        } else {
          currentStatus = await Permission.storage.status;
          print('📋 Current WRITE_EXTERNAL_STORAGE status: $currentStatus');
        }
        
        // Show current permission status in logs
        if (currentStatus.isDenied) {
          print('❌ Permission is DENIED - will request now');
        } else if (currentStatus.isGranted) {
          print('✅ Permission is ALREADY GRANTED');
        } else if (currentStatus.isPermanentlyDenied) {
          print('🔒 Permission is PERMANENTLY DENIED');
        } else if (currentStatus.isRestricted) {
          print('⚠️ Permission is RESTRICTED');
        } else if (currentStatus.isLimited) {
          print('⚠️ Permission is LIMITED');
        }
        
        // Request permission
        PermissionStatus status;
        if (androidVersion >= 30) {
          print('📱 Android 11+: Requesting MANAGE_EXTERNAL_STORAGE...');
          status = await Permission.manageExternalStorage.request();
        } else {
          print('📱 Android 10 or below: Requesting WRITE_EXTERNAL_STORAGE...');
          status = await Permission.storage.request();
        }
        
        print('📋 Permission request result: $status');
        
        if (status.isDenied) {
          print('❌ User DENIED the permission');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text(
                  '❌ Permission Denied\n\n'
                  'You need to allow storage access to download the QR code.\n'
                  'Please tap "Allow" when asked.',
                ),
                duration: const Duration(seconds: 4),
                backgroundColor: Colors.red,
              ),
            );
          }
          return;
        }
        
        if (status.isPermanentlyDenied) {
          print('🔒 User PERMANENTLY DENIED - opening settings');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text(
                  '🔒 Permission Permanently Denied\n\n'
                  'Go to Settings → Apps → EquisSplit → Permissions → Storage\n'
                  'and toggle "Allow access to all files" ON',
                ),
                action: SnackBarAction(
                  label: '📱 Open Settings',
                  onPressed: () {
                    print('🔓 Opening app settings...');
                    openAppSettings();
                  },
                ),
                duration: const Duration(seconds: 6),
                backgroundColor: Colors.red[700],
              ),
            );
          }
          return;
        }
        
        if (status.isGranted) {
          print('✅ Permission GRANTED - proceeding with download');
        } else {
          print('⚠️ Permission status: $status (unexpected)');
        }
      }
      
      print('✅ Permission check complete - proceeding to download');
      
      // Get the Downloads directory - use direct path to public Downloads folder
      Directory downloadDir = Directory('/storage/emulated/0/Download');
      print('📂 Using public Downloads folder: ${downloadDir.path}');
      
      // Ensure directory exists
      if (!await downloadDir.exists()) {
        print('📂 Creating Download directory...');
        try {
          await downloadDir.create(recursive: true);
          print('✅ Download directory created');
        } catch (e) {
          print('❌ Failed to create directory: $e');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Cannot create downloads folder: $e')),
            );
          }
          return;
        }
      }

      // Create filename with today's date
      final now = DateTime.now();
      final dateFormat = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      final timeFormat = '${now.hour.toString().padLeft(2, '0')}-${now.minute.toString().padLeft(2, '0')}-${now.second.toString().padLeft(2, '0')}';
      final fileName = 'QRCode_${payeeName}_${dateFormat}_$timeFormat.png';
      final downloadPath = '${downloadDir.path}/$fileName';
      print('💾 Final save location: $downloadPath');

      // Check if it's a server path
      if (qrImagePath.startsWith('/uploads/')) {
        // Server path - download from server
        final imageUrl = ImageStorageService.getImageUrl(qrImagePath);
        print('🌐 Downloading from server: $imageUrl');
        
        try {
          final response = await http.get(Uri.parse(imageUrl)).timeout(
            const Duration(seconds: 30),
            onTimeout: () {
              throw Exception('Download timeout - server might not be reachable');
            },
          );
          
          if (response.statusCode == 200) {
            // Write to file
            final file = File(downloadPath);
            print('📝 Writing ${response.bodyBytes.length} bytes to file...');
            await file.writeAsBytes(response.bodyBytes);
            
            // Verify file was created
            final fileExists = await file.exists();
            final fileSize = await file.length();
            print('✅ File created: $fileExists, Size: $fileSize bytes');
            print('📍 Full path: $downloadPath');
            
            if (fileExists && fileSize > 0) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('✅ QR Code Downloaded!', style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text('File: $fileName', style: const TextStyle(fontSize: 12)),
                        const SizedBox(height: 2),
                        const Text('Location: Downloads folder', style: TextStyle(fontSize: 12)),
                      ],
                    ),
                    duration: const Duration(seconds: 5),
                    backgroundColor: Colors.green[700],
                  ),
                );
              }
            } else {
              print('❌ File size issue: exists=$fileExists, size=$fileSize');
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('❌ File was saved but appears empty or corrupted'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            }
          } else {
            print('❌ Server error: ${response.statusCode}');
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Server error: ${response.statusCode}')),
              );
            }
          }
        } catch (e) {
          print('❌ Download error: $e');
          print('Stack trace: $e');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('❌ Download failed: $e'),
                duration: const Duration(seconds: 4),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
        return;
      }

      // Local file path
      final sourceFile = File(qrImagePath);
      
      if (!await sourceFile.exists()) {
        print('❌ Source file does not exist: $qrImagePath');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('QR Code file not found')),
          );
        }
        return;
      }

      await sourceFile.copy(downloadPath);
      print('✅ Downloaded to: $downloadPath');

      if (mounted) {
        Navigator.pop(context); // Close the dialog
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Saved to Downloads!'),
            duration: Duration(seconds: 3),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('❌ Download error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _uploadProofOfPayment(Map<String, dynamic> transaction) async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 50, // Higher compression for faster upload (50% quality)
      );

      if (image == null) return;

      // Show preview modal without uploading yet
      if (mounted) {
        _showProofReviewModal(transaction, image);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  void _showProofReviewModal(Map<String, dynamic> transaction, XFile image) {
    final transactionId = transaction['transaction_id'] as int;
    final payeeName = transaction['payee_name'] ?? 'Unknown';
    final amount = (transaction['amount'] as num).toDouble();
    bool isUploading = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Review Proof of Payment'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Proof image preview
                Container(
                  width: double.infinity,
                  height: 300,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Image.file(
                    File(image.path),
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return const Center(
                        child: Icon(Icons.image_not_supported, size: 50, color: Colors.grey),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
                // Payment details
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Payment Details',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('To:'),
                          Text(
                            payeeName,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Amount:'),
                          Text(
                            '₱${amount.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
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
          actions: [
            TextButton(
              onPressed: isUploading ? null : () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton.icon(
              onPressed: isUploading
                  ? null
                  : () async {
                      setDialogState(() => isUploading = true);

                      try {
                        // Upload image to server (compressed)
                        final proofImagePath =
                            await ImageStorageService.saveProofOfPayment(File(image.path));

                        if (proofImagePath == null) {
                          if (mounted) {
                            setDialogState(() => isUploading = false);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Failed to upload image')),
                            );
                          }
                          return;
                        }

                        // Save to database only when approved
                        final success = await _expenseRepo.addProofOfPayment(
                          transactionId: transactionId,
                          imagePath: proofImagePath,
                          uploadedBy: currentUserId!,
                        );

                        if (success) {
                          if (mounted) {
                            Navigator.pop(context); // Close dialog
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('✅ Proof sent for approval!'),
                                backgroundColor: Colors.green,
                                duration: Duration(seconds: 2),
                              ),
                            );
                            // Reload transactions to show updated status
                            _loadExpenseDetails();

                            // Pop with result to trigger dashboard refresh
                            Navigator.pop(context, {'proof_sent': true});
                          }
                        } else {
                          if (mounted) {
                            setDialogState(() => isUploading = false);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Failed to save proof')),
                            );
                          }
                        }
                      } catch (e) {
                        if (mounted) {
                          setDialogState(() => isUploading = false);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error: $e')),
                          );
                        }
                      }
                    },
              icon: isUploading ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.send),
              label: Text(isUploading ? 'Uploading...' : 'Send for Approval'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showPaymentQR(String payeeName, double amount, Map<String, dynamic> transaction) async {
    // Fetch QR codes from database
    final payeeId = transaction['payee_id'] as int;
    final qrCodesList = await _expenseRepo.getUserQRCodes(payeeId);
    
    if (qrCodesList.isEmpty) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Pay ₱${amount.toStringAsFixed(2)} to $payeeName'),
          content: const Text('No payment methods available for this user.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      );
      return;
    }
    
    // Get default QR code or first available
    final defaultQR = qrCodesList.firstWhere(
      (qr) => qr['is_default'] == 1,
      orElse: () => qrCodesList[0],
    );
    
    final qrCodeMap = <String, String>{
      'id': defaultQR['qr_code_id'].toString(),
      'path': defaultQR['image_path'].toString(),
      'label': defaultQR['label'].toString(),
      'isDefault': defaultQR['is_default'].toString(),
    };
    
    _showSingleQR(payeeName, amount, qrCodeMap, transaction);
  }

  void _showSingleQR(String payeeName, double amount, Map<String, String> qrCode, Map<String, dynamic> transaction) {
    final isServerPath = qrCode['path']!.startsWith('/uploads/');
    final imageUrl = isServerPath ? ImageStorageService.getImageUrl(qrCode['path']!) : null;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Pay ₱${amount.toStringAsFixed(2)} to $payeeName'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 250,
                height: 250,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: isServerPath
                    ? Image.network(
                        imageUrl!,
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Container(
                            color: Colors.grey[100],
                            child: const Center(
                              child: CustomLoadingIndicator(size: 30),
                            ),
                          );
                        },
                        errorBuilder: (context, error, stackTrace) {
                          print('❌ Network image error: $error');
                          print('🔗 URL: $imageUrl');
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.cloud_off, size: 50, color: Colors.grey),
                                const SizedBox(height: 8),
                                Text(
                                  'Failed to load\n$imageUrl',
                                  style: const TextStyle(color: Colors.grey, fontSize: 10),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          );
                        },
                      )
                    : Image.file(
                        File(qrCode['path']!),
                        fit: BoxFit.cover,
                      ),
              ),
              const SizedBox(height: 16),
              Text(
                'Method: ${qrCode['label']}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            onPressed: () => _downloadQRCode(qrCode['path']!, '${qrCode['label']}'),
            icon: const Icon(Icons.download),
            label: const Text('Download'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue[600],
              foregroundColor: Colors.white,
            ),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _uploadProofOfPayment(transaction);
            },
            icon: const Icon(Icons.upload_file),
            label: const Text('Upload Proof'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green[600],
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Expense Details',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: const Color(0xFF1976D2),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: isLoading
          ? Center(child: CustomLoadingIndicator())
          : expenseDetails == null
              ? const Center(
                  child: Text('Expense not found'),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Expense Header and Details (Non-scrollable)
                    SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Expense Header
                          Card(
                            elevation: 2,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            margin: const EdgeInsets.all(16),
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFF1976D2),
                                    Color(0xFF0288D1),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    expenseDetails!['expense_name'] ?? 'N/A',
                                    style: const TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                  // Description - small font below title
                                  if (expenseDetails!['description'] != null && 
                                      expenseDetails!['description'].toString().isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 6),
                                      child: Text(
                                        expenseDetails!['description'].toString(),
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.white.withValues(alpha: 0.8),
                                          fontStyle: FontStyle.italic,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  const SizedBox(height: 12),
                                  // Created by info
                                  if (expenseDetails!['creator_name'] != null)
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 12),
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.person,
                                            size: 14,
                                            color: Colors.white.withValues(alpha: 0.7),
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            'Created by ${expenseDetails!['creator_name']}',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.white.withValues(alpha: 0.7),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Date Created',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.white.withValues(alpha: 0.8),
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            _formatDate(
                                              expenseDetails!['created_date']
                                                      ?.toString() ??
                                                  '',
                                            ),
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ],
                                      ),
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Total Amount',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.white.withValues(alpha: 0.8),
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            '₱${double.parse(expenseDetails!['total_amount']?.toString() ?? '0').toStringAsFixed(2)}',
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ],
                                      ),
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.end,
                                        children: [
                                          Text(
                                            'Type',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.white.withValues(alpha: 0.8),
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.white.withValues(alpha: 0.2),
                                              borderRadius: BorderRadius.circular(4),
                                              border: Border.all(
                                                color: Colors.white.withValues(alpha: 0.5),
                                                width: 1,
                                              ),
                                            ),
                                            child: Text(
                                              _getExpenseTypeLabel(
                                                expenseDetails!['expense_type']?.toString() ?? 'evenly',
                                              ),
                                              style: const TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),

                          // Description and Creator removed - now in card header
                        ],
                      ),
                    ),

                    // Tabs and Tab Content (Scrollable)
                    Expanded(
                      child: Column(
                        children: [
                          Container(
                            color: Colors.grey[100],
                            child: TabBar(
                              controller: _tabController,
                              tabs: const [
                                Tab(text: 'Participants'),
                                Tab(text: 'Transactions'),
                              ],
                              indicatorColor: const Color(0xFF1976D2),
                              labelColor: const Color(0xFF1976D2),
                              unselectedLabelColor: Colors.grey,
                            ),
                          ),
                          Expanded(
                            child: TabBarView(
                              controller: _tabController,
                              children: [
                                // Tab 1: Participants & Contribution
                                _buildParticipantsTab(),
                                // Tab 2: Transactions
                                _buildTransactionsTab(),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildParticipantsTab() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: participants.isEmpty
          ? const Center(
              child: Text(
                'No participants',
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 14,
                ),
              ),
            )
          : ListView.builder(
              itemCount: participants.length,
              itemBuilder: (context, index) {
                final participant = participants[index];
                final userName = participant['name'] ?? participant['user_name'] ?? 'Unknown';
                final avatarPath = participant['avatar_path'];
                final amount = double.parse(
                  participant['amount'] ?? participant['contribution_amount']?.toString() ?? '0',
                );

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            // Avatar
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.grey[300],
                                image: avatarPath != null && avatarPath.toString().isNotEmpty
                                    ? DecorationImage(
                                        image: avatarPath.toString().startsWith('/uploads/')
                                            ? NetworkImage(ImageStorageService.getImageUrl(avatarPath.toString()))
                                            : FileImage(File(avatarPath.toString())),
                                        fit: BoxFit.cover,
                                      )
                                    : null,
                              ),
                              child: avatarPath == null || avatarPath.toString().isEmpty
                                  ? Icon(
                                      Icons.person,
                                      color: Colors.grey[600],
                                      size: 24,
                                    )
                                  : null,
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  userName.toString(),
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Contributed: ₱${amount.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  Widget _buildTransactionsTab() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: transactions.isEmpty
          ? const Center(
              child: Text(
                'No transactions',
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 14,
                ),
              ),
            )
          : ListView.builder(
              itemCount: transactions.length,
              itemBuilder: (context, index) {
                final transaction = transactions[index];
                final payerName = transaction['payer_name'] ?? 'Unknown';
                final payeeName = transaction['payee_name'] ?? 'Unknown';
                final payerId = transaction['payer_id'] as int?;
                final payerAvatar = transaction['payer_avatar'];
                final payeeAvatar = transaction['payee_avatar'];
                final amount = double.parse(
                  transaction['amount']?.toString() ?? '0',
                );
                final isPaid = transaction['status'] == 'paid';
                
                // Check if current user is the one who owes (payer)
                final currentUserOwes = payerId == currentUserId;
                
                print('Transaction: $payerName → $payeeName | PayerId: $payerId | CurrentUserId: $currentUserId | Owes: $currentUserOwes');
                print('💾 Avatar Data - Payer: $payerAvatar | Payee: $payeeAvatar');

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  color: currentUserOwes && !isPaid ? Colors.amber[50] : null,
                  child: Container(
                    decoration: currentUserOwes && !isPaid
                        ? BoxDecoration(
                            border: Border.all(
                              color: Colors.amber[400]!,
                              width: 2,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          )
                        : null,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment:
                                MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        // Payer Avatar
                                        Container(
                                          width: 36,
                                          height: 36,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: Colors.grey[300],
                                            image: payerAvatar != null && payerAvatar.toString().isNotEmpty
                                                ? DecorationImage(
                                                    image: payerAvatar.toString().startsWith('/uploads/')
                                                        ? NetworkImage(ImageStorageService.getImageUrl(payerAvatar.toString()))
                                                        : FileImage(File(payerAvatar.toString())),
                                                    fit: BoxFit.cover,
                                                  )
                                                : null,
                                          ),
                                          child: payerAvatar == null || payerAvatar.toString().isEmpty
                                              ? Icon(
                                                  Icons.person,
                                                  color: Colors.grey[600],
                                                  size: 20,
                                                )
                                              : null,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            payerName.toString(),
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        const Icon(Icons.arrow_forward,
                                            size: 16, color: Colors.grey),
                                        const SizedBox(width: 8),
                                        // Payee Avatar
                                        Container(
                                          width: 36,
                                          height: 36,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: Colors.grey[300],
                                            image: payeeAvatar != null && payeeAvatar.toString().isNotEmpty
                                                ? DecorationImage(
                                                    image: payeeAvatar.toString().startsWith('/uploads/')
                                                        ? NetworkImage(ImageStorageService.getImageUrl(payeeAvatar.toString()))
                                                        : FileImage(File(payeeAvatar.toString())),
                                                    fit: BoxFit.cover,
                                                  )
                                                : null,
                                          ),
                                          child: payeeAvatar == null || payeeAvatar.toString().isEmpty
                                              ? Icon(
                                                  Icons.person,
                                                  color: Colors.grey[600],
                                                  size: 20,
                                                )
                                              : null,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            payeeName.toString(),
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      isPaid
                                          ? 'Paid'
                                          : 'Pending payment',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: isPaid
                                            ? Colors.green
                                            : Colors.orange,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF5F5F5),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '₱${amount.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF1976D2),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (currentUserOwes && !isPaid)
                            Padding(
                              padding: const EdgeInsets.only(top: 12),
                              child: ElevatedButton.icon(
                                onPressed: () =>
                                    _showPaymentQR(payeeName.toString(), amount, transaction),
                                icon: const Icon(Icons.qr_code),
                                label: const Text('Pay'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green.shade600,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
