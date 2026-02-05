import 'package:flutter/material.dart';
import 'package:equisplit/repositories/expense_repository.dart';
import 'package:equisplit/services/image_storage_service.dart';
import 'package:equisplit/widgets/custom_loading_indicator.dart';
import 'dart:io';
import 'dart:async';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;

class TransactionsPage extends StatefulWidget {
  final Map<String, dynamic> currentUser;

  const TransactionsPage({super.key, required this.currentUser});

  @override
  State<TransactionsPage> createState() => _TransactionsPageState();
}

class _TransactionsPageState extends State<TransactionsPage> {
  final _expenseRepo = ExpenseRepository();
  late Future<List<List<Map<String, dynamic>>>> _combinedTransactionsFuture;

  @override
  void initState() {
    super.initState();
    _loadTransactions();
  }

  void _loadTransactions() {
    _combinedTransactionsFuture = Future.wait([
      _expenseRepo.getPendingPaymentsForUser(widget.currentUser['user_id']),
      _expenseRepo.getPendingPaymentsOwedToUser(widget.currentUser['user_id']),
    ]);
  }

  Future<void> _markTransactionAsPaid(int transactionId) async {
    final success = await _expenseRepo.markTransactionAsPaid(transactionId);
    if (success) {
      setState(() {
        _loadTransactions();
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Payment marked as completed'),
            backgroundColor: Color(0xFF424242), // Updated to professional theme
          ),
        );
      }
    }
  }

  Future<void> _showPayerQRCodes(String payerName, int payerId) async {
    try {
      final qrCodes = await _expenseRepo.getUserQRCodes(payerId);
      
      print('');
      print('========== QR CODE DEBUG ==========');
      print('Payer: $payerName (ID: $payerId)');
      print('Total QR codes from DB: ${qrCodes.length}');
      for (var i = 0; i < qrCodes.length; i++) {
        print('  [$i] Label: ${qrCodes[i]['label']}');
        print('      Path: ${qrCodes[i]['image_path']}');
        print('      ID: ${qrCodes[i]['qr_code_id']}');
      }
      print('==================================');
      print('');
      
      if (!mounted) return;
      
      if (qrCodes.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$payerName has not added any QR codes yet'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      // Load QR code images
      List<Map<String, dynamic>> qrWithImages = [];
      for (var qr in qrCodes) {
        final imagePath = qr['image_path'];
        print('📸 QR Code - Path: $imagePath');
        
        // Check if it's a server path or local file
        if (imagePath != null && imagePath.isNotEmpty) {
          if (imagePath.startsWith('/uploads/')) {
            // Server path
            final imageUrl = ImageStorageService.getImageUrl(imagePath);
            print('🌐 Server URL: $imageUrl');
            qrWithImages.add({
              'id': qr['qr_code_id'],
              'label': qr['label'],
              'image': null,
              'imageUrl': imageUrl,
              'path': imagePath,
            });
          } else {
            // Local file path - still add it even if file doesn't exist
            // Let the UI handle the error
            print('📁 Local file path: $imagePath');
            qrWithImages.add({
              'id': qr['qr_code_id'],
              'label': qr['label'],
              'image': File(imagePath),
              'imageUrl': null,
              'path': imagePath,
            });
          }
        } else {
          print('⚠️ QR code has empty path');
        }
      }

      if (!mounted) return;

      print('📋 Total QR codes loaded: ${qrWithImages.length}');
      
      if (qrWithImages.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$payerName has not added any accessible QR codes'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('$payerName\'s Payment Methods'),
          content: SizedBox(
            width: double.maxFinite,
            child: qrWithImages.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32.0),
                      child: Text('No QR codes available'),
                    ),
                  )
                : SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: qrWithImages.map((qrData) {
                        return GestureDetector(
                          onTap: () {
                            Navigator.pop(context);
                            _showQRDetail(payerName, qrData);
                          },
                          child: Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Container(
                                    height: 120,
                                    decoration: BoxDecoration(
                                      border: Border.all(color: Colors.grey[300]!),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(4),
                                      child: qrData['imageUrl'] != null
                                          ? Image.network(
                                              qrData['imageUrl'],
                                              fit: BoxFit.cover,
                                              errorBuilder: (context, error, stackTrace) {
                                                print('❌ Transaction QR error: $error');
                                                print('🔗 URL: ${qrData["imageUrl"]}');
                                                return Container(
                                                  color: Colors.grey[300],
                                                  child: Column(
                                                    mainAxisAlignment: MainAxisAlignment.center,
                                                    children: [
                                                      const Icon(Icons.error, color: Colors.red),
                                                      Text('Error: $error', style: const TextStyle(fontSize: 8)),
                                                    ],
                                                  ),
                                                );
                                              },
                                              loadingBuilder: (context, child, loadingProgress) {
                                                if (loadingProgress == null) return child;
                                                return Container(
                                                  color: Colors.grey[100],
                                                  child: const Center(
                                                    child: CustomLoadingIndicator(size: 30),
                                                  ),
                                                );
                                              },
                                            )
                                          : Image.file(
                                              qrData['image'],
                                              fit: BoxFit.cover,
                                              errorBuilder: (context, error, stackTrace) {
                                                print('❌ File error: $error');
                                                return Container(
                                                  color: Colors.grey[100],
                                                  child: Center(
                                                    child: Column(
                                                      mainAxisAlignment: MainAxisAlignment.center,
                                                      children: [
                                                        const Icon(Icons.file_present, color: Colors.grey, size: 40),
                                                        const SizedBox(height: 8),
                                                        Text(
                                                          'File not found\n${qrData['path']}',
                                                          textAlign: TextAlign.center,
                                                          style: const TextStyle(fontSize: 10, color: Colors.grey),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                );
                                              },
                                            ),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    qrData['label'] ?? 'Payment Method',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    qrData['imageUrl'] != null ? '📱 From Server' : '💾 Local File',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading QR codes: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showQRDetail(String payerName, Map<String, dynamic> qrData) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${qrData['label']} - From $payerName'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: qrData['imageUrl'] != null
                  ? Image.network(
                      qrData['imageUrl'],
                      width: 250,
                      height: 250,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          width: 250,
                          height: 250,
                          color: Colors.grey[300],
                          child: const Icon(Icons.error),
                        );
                      },
                    )
                  : Image.file(
                      qrData['image'],
                      width: 250,
                      height: 250,
                      fit: BoxFit.cover,
                    ),
            ),
            const SizedBox(height: 16),
            Text(
              'Payment Method: ${qrData['label']}',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Take a screenshot or tap Download to save',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          ElevatedButton.icon(
            onPressed: () => _downloadQRCode(qrData, payerName),
            icon: const Icon(Icons.download),
            label: const Text('Download'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1976D2),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _downloadQRCode(Map<String, dynamic> qrData, String payerName) async {
    try {
      print('📥 Downloading QR code: ${qrData['label']}');
      
      // Use DCIM/Camera folder
      final downloadDir = Directory('/storage/emulated/0/DCIM/Camera');
      print('📂 Using DCIM/Camera folder: ${downloadDir.path}');
      
      // Create directory if it doesn't exist
      if (!await downloadDir.exists()) {
        print('📂 Creating DCIM/Camera directory...');
        await downloadDir.create(recursive: true);
        print('✅ Directory created');
      }

      // Create filename
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final label = qrData['label'].toString().replaceAll(' ', '_');
      final fileName = '${payerName}_${label}_$timestamp.png';
      final downloadPath = '${downloadDir.path}/$fileName';

      // Determine if this is a server or local file
      final qrImagePath = qrData['image']?.path ?? '';
      
      if (qrImagePath.startsWith('/uploads/')) {
        // Server image - download via HTTP
        print('🌐 Downloading from server: $qrImagePath');
        try {
          final imageUrl = ImageStorageService.getImageUrl(qrImagePath);
          final response = await http.get(Uri.parse(imageUrl))
            .timeout(const Duration(seconds: 30), onTimeout: () {
            throw TimeoutException('Download timeout after 30 seconds');
          });
          
          if (response.statusCode == 200) {
            final file = File(downloadPath);
            await file.writeAsBytes(response.bodyBytes);
            print('✅ Downloaded from server to: $downloadPath');
            
            // Trigger media scan so file appears in gallery
            print('📸 Triggering media scan for gallery...');
            try {
              if (Platform.isAndroid) {
                await Process.run('am', [
                  'broadcast',
                  '-a',
                  'android.intent.action.MEDIA_SCANNER_SCAN_FILE',
                  '-d',
                  'file://$downloadPath'
                ]);
              }
            } catch (scanError) {
              print('⚠️ Media scan failed: $scanError');
            }
            
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('📸 QR Code saved to DCIM/Camera!'),
                  backgroundColor: Colors.green,
                  duration: const Duration(seconds: 2),
                ),
              );
              Navigator.pop(context);
            }
          } else {
            throw Exception('HTTP ${response.statusCode}: Failed to download from server');
          }
        } catch (e) {
          print('❌ Server download error: $e');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Download failed: $e'),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 3),
              ),
            );
          }
        }
      } else if (qrData['image'] != null) {
        // Local file - copy directly
        final sourceFile = qrData['image'] as File;
        if (!await sourceFile.exists()) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Source file not found'),
                backgroundColor: Colors.red,
              ),
            );
          }
          return;
        }
        
        await sourceFile.copy(downloadPath);
        print('✅ Downloaded from local storage to: $downloadPath');
        
        // Trigger media scan so file appears in gallery
        print('📸 Triggering media scan for gallery...');
        try {
          if (Platform.isAndroid) {
            await Process.run('am', [
              'broadcast',
              '-a',
              'android.intent.action.MEDIA_SCANNER_SCAN_FILE',
              '-d',
              'file://$downloadPath'
            ]);
          }
        } catch (scanError) {
          print('⚠️ Media scan failed: $scanError');
        }
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('📸 QR Code saved to DCIM/Camera!'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
          Navigator.pop(context);
        }
      } else {
        throw Exception('No image source found (neither imageUrl nor local file)');
      }
    } catch (e) {
      print('❌ Error downloading QR code: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Payments'),
        backgroundColor: const Color(0xFF1976D2),
      ),
      body: FutureBuilder<List<List<Map<String, dynamic>>>>(
        future: _combinedTransactionsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CustomLoadingIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 50, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('Error: ${snapshot.error}'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _loadTransactions();
                      });
                    },
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          final allTransactions = snapshot.data ?? [[], []];
          final owe = allTransactions[0];
          final owingMe = allTransactions[1];

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Summary Cards
                Row(
                  children: [
                    Expanded(
                      child: Card(
                        color: const Color(0xFFF8FAFF),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'People Owe Me',
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '₱${owingMe.fold<double>(0, (sum, t) => sum + (t['amount'] as num).toDouble()).toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1976D2),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${owingMe.length} transaction${owingMe.length != 1 ? 's' : ''}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Card(
                        color: Colors.red.shade50,
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'I Owe',
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '₱${owe.fold<double>(0, (sum, t) => sum + (t['amount'] as num).toDouble()).toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.red,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${owe.length} transaction${owe.length != 1 ? 's' : ''}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),

                // Owe Section
                const Text(
                  'I Owe Others',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                if (owe.isEmpty)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(32.0),
                      child: Center(
                        child: Text('No pending payments'),
                      ),
                    ),
                  )
                else
                  ...owe.map((transaction) {
                    final pendingProofs = transaction['pending_proofs'] as int? ?? 0;
                    final latestApprovalStatus = transaction['latest_approval_status'] as String?;
                    final hasProof = latestApprovalStatus != null;
                    final isPending = hasProof && latestApprovalStatus == 'pending';
                    final isApproved = hasProof && latestApprovalStatus == 'approved';

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 20,
                                      backgroundImage: transaction['payee_avatar'] != null
                                          ? NetworkImage(ImageStorageService.getImageUrl(transaction['payee_avatar']))
                                          : null,
                                      backgroundColor: const Color(0xFF1976D2),
                                      child: transaction['payee_avatar'] == null
                                          ? Text(
                                              transaction['payee_name'][0].toUpperCase(),
                                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                            )
                                          : null,
                                    ),
                                    const SizedBox(width: 12),
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Pay to',
                                          style: TextStyle(
                                            color: Colors.grey,
                                            fontSize: 11,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          transaction['payee_name'],
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                const SizedBox(width: 12),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.red.shade100,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    '₱${(transaction['amount'] as num).toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.red,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'From: ${transaction['expense_name']}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            // Proof of Payment Badge
                            if (hasProof)
                              Padding(
                                padding: const EdgeInsets.only(top: 8.0),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isPending
                                        ? Colors.orange.shade50
                                        : Colors.green.shade50,
                                    border: Border.all(
                                      color: isPending
                                          ? Colors.orange
                                          : Colors.green,
                                      width: 1,
                                    ),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        isPending
                                            ? Icons.schedule
                                            : Icons.verified,
                                        color: isPending
                                            ? Colors.orange
                                            : Colors.green,
                                        size: 12,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        isPending
                                            ? 'Proof sent • Waiting for approval'
                                            : 'Proof approved ✓',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w500,
                                          color: isPending
                                              ? Colors.orange.shade800
                                              : Colors.green.shade800,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            const SizedBox(height: 12),
                            // Show message and button based on proof status
                            if (isPending)
                              Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: Colors.orange.shade50,
                                            border: Border.all(
                                              color: Colors.orange,
                                              width: 1,
                                            ),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Row(
                                            children: [
                                              Icon(
                                                Icons.info_outline,
                                                color: Colors.orange.shade800,
                                                size: 18,
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Text(
                                                  'Proof of payment sent. Waiting for approval from receiver.',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: Colors.orange.shade800,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                              ),
                                            ],
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
                                      color: Colors.orange.shade100,
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: Colors.orange,
                                        width: 1,
                                      ),
                                    ),
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.schedule,
                                          color: Colors.orange.shade800,
                                          size: 20,
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Waiting',
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: Colors.orange.shade800,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              )
                            else
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: () {
                                    _markTransactionAsPaid(
                                        transaction['transaction_id']);
                                  },
                                  icon: const Icon(Icons.check),
                                  label: const Text('Mark as Paid'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF1976D2),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 8,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  }),
                const SizedBox(height: 32),

                // Owed to me Section
                const Text(
                  'Others Owe Me',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                if (owingMe.isEmpty)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(32.0),
                      child: Center(
                        child: Text('No pending payments'),
                      ),
                    ),
                  )
                else
                  ...owingMe.map((transaction) {
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      color: const Color(0xFFF8FAFF),
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 20,
                                      backgroundImage: transaction['payer_avatar'] != null
                                          ? NetworkImage(ImageStorageService.getImageUrl(transaction['payer_avatar']))
                                          : null,
                                      backgroundColor: const Color(0xFF1976D2),
                                      child: transaction['payer_avatar'] == null
                                          ? Text(
                                              transaction['payer_name'][0].toUpperCase(),
                                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                            )
                                          : null,
                                    ),
                                    const SizedBox(width: 12),
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Collect from',
                                          style: TextStyle(
                                            color: Colors.grey,
                                            fontSize: 11,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          transaction['payer_name'],
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
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
                                    '₱${(transaction['amount'] as num).toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF1976D2),
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'From: ${transaction['expense_name']}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () {
                                      _showPayerQRCodes(
                                        transaction['payee_name'],
                                        transaction['payee_id'],
                                      );
                                    },
                                    icon: const Icon(Icons.qr_code),
                                    label: const Text('Send QR Code'),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: const Color(0xFF1976D2),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: () {
                                      _markTransactionAsPaid(
                                          transaction['transaction_id']);
                                    },
                                    icon: const Icon(Icons.check),
                                    label: const Text('Mark Paid'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF1976D2),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
              ],
            ),
          );
        },
      ),
    );
  }
}
