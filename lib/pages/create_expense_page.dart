import 'package:flutter/material.dart';
import 'package:equisplit/repositories/expense_repository.dart';
import 'package:equisplit/repositories/user_repository.dart';
import 'package:equisplit/repositories/friends_repository.dart';
import 'package:equisplit/services/splitting_service.dart';
import 'package:equisplit/services/image_storage_service.dart';
import 'dart:io';

class CreateExpensePage extends StatefulWidget {
  final Map<String, dynamic>? currentUser;

  const CreateExpensePage({super.key, this.currentUser});

  @override
  State<CreateExpensePage> createState() => _CreateExpensePageState();
}

class _CreateExpensePageState extends State<CreateExpensePage> {
  final _expenseNameController = TextEditingController();
  final _descriptionController = TextEditingController();
  
  final _expenseRepo = ExpenseRepository();
  final _userRepo = UserRepository();
  final _friendsRepo = FriendsRepository();
  
  bool _isLoading = false;
  List<Map<String, dynamic>> _allUsers = [];
  List<Map<String, dynamic>> _mutualFriends = [];
  final Map<int, double> _selectedParticipants = {};
  final Map<int, TextEditingController> _contributionControllers = {};
  List<Map<String, dynamic>> _calculatedTransactions = [];
  bool _showTransactions = false;
  int? _focusedParticipantId;
  String _expenseType = 'evenly'; // evenly, borrowed, partial
  
  final FocusNode _contributionFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadUsers();
    // Automatically add current user as a participant
    if (widget.currentUser != null) {
      final currentUserId = widget.currentUser!['user_id'] as int?;
      if (currentUserId != null) {
        _selectedParticipants[currentUserId] = 0;
      }
    }
  }

  @override
  void dispose() {
    _expenseNameController.dispose();
    _descriptionController.dispose();
    _contributionFocusNode.dispose();
    _scrollController.dispose();
    for (var controller in _contributionControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _loadUsers() async {
    final currentUserId = widget.currentUser?['user_id'] as int?;
    
    // Load all users for backwards compatibility
    final users = await _userRepo.getAllUsers();
    setState(() {
      _allUsers = users;
    });

    // Load mutual friends only if user is logged in
    if (currentUserId != null) {
      final friends = await _friendsRepo.getMutualFriends(currentUserId);
      setState(() {
        _mutualFriends = friends;
      });
    }
  }

  void _showAddParticipantDialog() {
    List<int> tempSelectedUsers = [];
    String searchQuery = '';
    final currentUserId = widget.currentUser?['user_id'] as int?;
    final isBorrowedType = _expenseType == 'borrowed';
    final maxParticipantsForBorrowed = 1; // Only 1 additional participant + current user

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Add Participants',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              if (isBorrowedType)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.orange[100],
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'Borrowed Money: Select only 1 participant',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.orange,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Search Field
                TextField(
                  onChanged: (value) {
                    setDialogState(() {
                      searchQuery = value.toLowerCase();
                    });
                  },
                  decoration: InputDecoration(
                    hintText: 'Search participants...',
                    prefixIcon: const Icon(Icons.search, color: Color(0xFF1976D2)),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Colors.grey),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(
                        color: Color(0xFF1976D2),
                        width: 2,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Select All Button - Only applies to filtered search (and not for borrowed type)
                if (!isBorrowedType)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        setDialogState(() {
                          // Use only mutual friends
                          final userList = _mutualFriends;
                          
                          // Get filtered users based on search
                          final filteredUsers = userList
                              .where((user) =>
                                  (searchQuery.isEmpty ||
                                      user['name']
                                          .toString()
                                          .toLowerCase()
                                          .contains(searchQuery) ||
                                      user['username']
                                          .toString()
                                          .toLowerCase()
                                          .contains(searchQuery)) &&
                                  !_selectedParticipants
                                      .containsKey(user['user_id']))
                              .toList();

                          // Check if all filtered are selected
                          final allFiltered = filteredUsers
                              .map((u) => u['user_id'] as int)
                              .toList();
                          final allSelectedInFiltered = allFiltered
                              .every((id) => tempSelectedUsers.contains(id));

                          if (allSelectedInFiltered && tempSelectedUsers.isNotEmpty) {
                            // Deselect all filtered
                            tempSelectedUsers.removeWhere(
                                (id) => allFiltered.contains(id));
                          } else {
                            // Select all filtered
                            for (var user in filteredUsers) {
                              final userId = user['user_id'] as int;
                              if (!tempSelectedUsers.contains(userId)) {
                                tempSelectedUsers.add(userId);
                              }
                            }
                          }
                        });
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1976D2),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                      child: const Text(
                        'Select All Filtered',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                if (!isBorrowedType)
                  const SizedBox(height: 12),

                // User List
                Expanded(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _mutualFriends.length,
                    itemBuilder: (context, index) {
                      final userList = _mutualFriends;
                      final user = userList[index];
                      final userId = user['user_id'] as int;
                      
                      // Skip current user from modal
                      if (userId == currentUserId) {
                        return const SizedBox.shrink();
                      }
                      
                      final isAlreadyAdded =
                          _selectedParticipants.containsKey(userId);
                      final isSelected = tempSelectedUsers.contains(userId);
                      
                      // For borrowed type, disable if already 1 selected and not current
                      final isBorrowedMaxReached = isBorrowedType && 
                          tempSelectedUsers.length >= maxParticipantsForBorrowed && 
                          !isSelected;

                      // Filter by search
                      if (searchQuery.isNotEmpty &&
                          !user['name']
                              .toString()
                              .toLowerCase()
                              .contains(searchQuery) &&
                          !user['username']
                              .toString()
                              .toLowerCase()
                              .contains(searchQuery)) {
                        return const SizedBox.shrink();
                      }

                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        elevation: isSelected ? 2 : 0,
                        color: isSelected ? const Color(0xFFF0F7FF) : Colors.white,
                        child: ListTile(
                          leading: _buildAvatarImage(user, size: 40),
                          title: Text(
                            user['name'],
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          trailing: isAlreadyAdded
                              ? Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.green,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text(
                                    'Added',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                )
                              : isBorrowedMaxReached
                                  ? Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.grey,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Text(
                                        'Max',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    )
                              : isSelected
                                  ? const Icon(
                                      Icons.check_circle,
                                      color: Color(0xFF1976D2),
                                    )
                                  : const Icon(Icons.circle_outlined),
                          enabled: !isAlreadyAdded && !isBorrowedMaxReached,
                          onTap: (!isAlreadyAdded && !isBorrowedMaxReached)
                              ? () {
                                  setDialogState(() {
                                    if (isSelected) {
                                      tempSelectedUsers.remove(userId);
                                    } else {
                                      tempSelectedUsers.add(userId);
                                    }
                                  });
                                }
                              : null,
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w500)),
            ),
            ElevatedButton(
              onPressed: tempSelectedUsers.isEmpty
                  ? null
                  : () {
                      // Call the OUTER widget's setState to update main page
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        setState(() {
                          for (var userId in tempSelectedUsers) {
                            _selectedParticipants[userId] = 0;
                          }
                          if (tempSelectedUsers.isNotEmpty) {
                            _focusedParticipantId = tempSelectedUsers.first;
                          }
                        });
                      });
                      
                      // Close the dialog using the dialog's context
                      Navigator.pop(dialogContext);
                      
                      Future.delayed(const Duration(milliseconds: 200), () {
                        if (mounted) {
                          // Scroll to show participants section
                          if (_scrollController.hasClients) {
                            _scrollController.animateTo(
                              300,
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeInOut,
                            );
                          }
                          _contributionFocusNode.requestFocus();
                        }
                      });
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1976D2),
              ),
              child: Text(
                'Add ${tempSelectedUsers.length} Participant${tempSelectedUsers.length != 1 ? 's' : ''}',
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _removeParticipant(int userId) {
    setState(() {
      _selectedParticipants.remove(userId);
      _contributionControllers[userId]?.dispose();
      _contributionControllers.remove(userId);
      if (_focusedParticipantId == userId) {
        _focusedParticipantId = null;
      }
    });
  }

  Widget _buildAvatarImage(Map<String, dynamic> user, {double size = 40}) {
    final avatarPath = user['avatar_path'] as String?;
    
    print('Avatar Debug - User: ${user['name']}, Avatar Path: $avatarPath');
    
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0xFF1976D2),
        shape: BoxShape.circle,
      ),
      child: avatarPath != null && avatarPath.isNotEmpty
          ? ClipRRect(
              borderRadius: BorderRadius.circular(size / 2),
              child: Builder(
                builder: (context) {
                  // Extract filename if the path contains the full path
                  String filename = avatarPath;
                  if (avatarPath.contains('/')) {
                    filename = avatarPath.split('/').last;
                  }
                  final url = 'http://10.0.11.103:3000/uploads/avatars/$filename';
                  print('Loading avatar from URL: $url');
                  return Image.network(
                    url,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      print('Error loading avatar from server: $error');
                      print('URL was: $url');
                      // Fallback to initials if image fails to load
                      return Center(
                        child: Text(
                          user['name'][0].toUpperCase(),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            fontSize: size / 2.2,
                          ),
                        ),
                      );
                    },
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Center(
                        child: CircularProgressIndicator(
                          value: loadingProgress.expectedTotalBytes != null
                              ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                              : null,
                        ),
                      );
                    },
                  );
                },
              ),
            )
          : Center(
              child: Text(
                user['name'][0].toUpperCase(),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  fontSize: size / 2.2,
                ),
              ),
            ),
    );
  }

  Widget _buildExpenseTypeOption(
    String type,
    String title,
    String description,
    IconData icon,
  ) {
    bool isSelected = _expenseType == type;
    return InkWell(
      onTap: () {
        setState(() {
          _expenseType = type;
        });
      },
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? const Color(0xFF1976D2) : Colors.grey[200],
              ),
              child: Icon(
                icon,
                color: isSelected ? Colors.white : Colors.grey[600],
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? const Color(0xFF1976D2) : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            Radio<String>(
              value: type,
              groupValue: _expenseType,
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _expenseType = value;
                  });
                }
              },
              activeColor: const Color(0xFF1976D2),
            ),
          ],
        ),
      ),
    );
  }

  TextEditingController _getContributionController(int userId) {
    if (!_contributionControllers.containsKey(userId)) {
      _contributionControllers[userId] = TextEditingController(
        text: '', // Start with empty text
      );
      _contributionControllers[userId]!.addListener(() {
        setState(() {
          _selectedParticipants[userId] =
              double.tryParse(_contributionControllers[userId]!.text) ?? 0;
        });
      });
    }
    return _contributionControllers[userId]!;
  }

  double _calculateTotal() {
    return _selectedParticipants.values.fold(0, (sum, val) => sum + val);
  }

  Future<void> _computeExpenses() async {
    if (_expenseNameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter expense name')),
      );
      return;
    }

    if (_selectedParticipants.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one participant')),
      );
      return;
    }

    double totalAmount = _calculateTotal();

    if (totalAmount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Total amount must be greater than 0')),
      );
      return;
    }

    Map<String, double> contributionsStr = {};
    for (var entry in _selectedParticipants.entries) {
      contributionsStr[entry.key.toString()] = entry.value;
    }

    List<String> userIds =
        _selectedParticipants.keys.map((id) => id.toString()).toList();

    // Calculate transactions based on expense type
    List<Transaction> transactions =
        SplittingService.calculateTransactionsByType(
      userIds,
      contributionsStr,
      totalAmount,
      _expenseType,
    );

    setState(() {
      _calculatedTransactions = transactions
          .map((t) {
            String payerName = 'Unknown';
            String payeeName = 'Unknown';

            try {
              final payerUser =
                  _allUsers.firstWhere((u) => u['user_id'].toString() == t.from);
              payerName = payerUser['name'] ?? 'Unknown';
            } catch (e) {
              payerName = 'Unknown';
            }

            try {
              final payeeUser =
                  _allUsers.firstWhere((u) => u['user_id'].toString() == t.to);
              payeeName = payeeUser['name'] ?? 'Unknown';
            } catch (e) {
              payeeName = 'Unknown';
            }

            return {
              'from': payerName,
              'from_id': int.tryParse(t.from) ?? 0,
              'to': payeeName,
              'to_id': int.tryParse(t.to) ?? 0,
              'amount': t.amount,
            };
          })
          .toList();
      _showTransactions = true;
    });
  }

  Future<void> _saveExpense() async {
    setState(() => _isLoading = true);

    try {
      double totalAmount = _calculateTotal();

      int? expenseId = await _expenseRepo.createExpense(
        expenseName: _expenseNameController.text,
        description: _descriptionController.text,
        totalAmount: totalAmount,
        createdBy: widget.currentUser?['user_id'] ?? 1,
        expenseType: _expenseType,
      );

      if (expenseId == null) throw Exception('Failed to create expense');

      for (var entry in _selectedParticipants.entries) {
        await _expenseRepo.addExpenseParticipant(
          expenseId: expenseId,
          userId: entry.key,
          contributionAmount: entry.value,
        );
      }

      await _expenseRepo.calculateAndSaveTransactions(expenseId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Expense created successfully!'),
            backgroundColor: Color(0xFF1976D2),
            duration: Duration(seconds: 2),
          ),
        );

        // Navigate back to dashboard (homepage) with current user
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            Navigator.pushReplacementNamed(
              context,
              '/dashboard',
              arguments: widget.currentUser ?? {},
            );
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    double totalAmount = _calculateTotal();

    if (_showTransactions) {
      return _buildTransactionsView(totalAmount);
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFF),
      appBar: AppBar(
        title: const Text('Create Expense'),
        backgroundColor: const Color(0xFF1976D2),
      ),
      body: SingleChildScrollView(
        controller: _scrollController,
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _expenseNameController,
              decoration: InputDecoration(
                labelText: 'Expense Name',
                hintText: 'e.g., Dinner, Shopping',
                prefixIcon: const Icon(Icons.shopping_cart, color: Color(0xFF1976D2)),
                labelStyle: const TextStyle(color: Color(0xFF1976D2)),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.grey),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: Color(0xFF1976D2),
                    width: 2,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            TextField(
              controller: _descriptionController,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'Description (Optional)',
                hintText: 'Add notes...',
                prefixIcon: const Icon(Icons.description, color: Color(0xFF1976D2)),
                labelStyle: const TextStyle(color: Color(0xFF1976D2)),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.grey),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: Color(0xFF1976D2),
                    width: 2,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Expense Type Selection
            const Text(
              'Expense Type',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFF1976D2)),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  _buildExpenseTypeOption(
                    'evenly',
                    'Evenly Split',
                    'Split equally among all\nparticipants',
                    Icons.balance,
                  ),
                  Divider(height: 0, color: Colors.grey[300]),
                  _buildExpenseTypeOption(
                    'borrowed',
                    'Borrowed Money',
                    'Only borrower pays back',
                    Icons.card_giftcard,
                  ),
                  Divider(height: 0, color: Colors.grey[300]),
                  _buildExpenseTypeOption(
                    'partial',
                    'Non-Contributors Pay',
                    'Only those who didn\'t\ncontribute will pay',
                    Icons.people_alt,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Add Participant Button - Above the cards
            Center(
              child: ElevatedButton.icon(
                onPressed: _showAddParticipantDialog,
                icon: const Icon(Icons.person_add, color: Colors.white),
                label: const Text(
                  'Add Participant',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1976D2),
                  elevation: 4,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  shadowColor: const Color(0xFF1976D2).withOpacity(0.5),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Debug: Show participant count
            if (_selectedParticipants.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: Text(
                  'Added Participants: ${_selectedParticipants.length}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
              ),

            // Participants with Contribution Input
            if (_selectedParticipants.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFF1976D2),
                    width: 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Participants & Contributions',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1976D2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '${_selectedParticipants.length}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    ..._selectedParticipants.entries.map((entry) {
                      final userId = entry.key;
                      final amount = entry.value;
                      final user = _allUsers.firstWhere(
                        (u) => u['user_id'] == userId,
                        orElse: () => {'name': 'Unknown', 'username': ''},
                      );
                      final isFocused = _focusedParticipantId == userId;

                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            _focusedParticipantId = userId;
                          });
                          _contributionFocusNode.requestFocus();
                        },
                        child: Card(
                          elevation: 2,
                          margin: const EdgeInsets.only(bottom: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      _buildAvatarImage(user, size: 40),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              user['name'],
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16,
                                                color: Colors.black87,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      // Only show remove button if user is NOT the current user
                                      if (userId != widget.currentUser?['user_id'])
                                        IconButton(
                                          icon: const Icon(Icons.close, color: Colors.red, size: 20),
                                          onPressed: () => _removeParticipant(userId),
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                                        ),
                                    ],
                                  ),
                                  if (isFocused) ...[
                                    const SizedBox(height: 12),
                                    TextField(
                                      focusNode: _contributionFocusNode,
                                      keyboardType: TextInputType.number,
                                      decoration: InputDecoration(
                                        labelText: 'Contribution Amount',
                                        hintText: '0.00',
                                        prefixText: '₱ ',
                                        prefixStyle: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF1976D2),
                                        ),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(8),
                                          borderSide: const BorderSide(
                                            color: Color(0xFF1976D2),
                                            width: 2,
                                          ),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(8),
                                          borderSide: const BorderSide(
                                            color: Color(0xFF1976D2),
                                            width: 2,
                                          ),
                                        ),
                                      ),
                                      controller: _getContributionController(userId),
                                    ),
                                  ] else
                                    Padding(
                                      padding: const EdgeInsets.only(top: 8.0),
                                      child: Text(
                                        'Contribution: ₱${amount.toStringAsFixed(2)}',
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                          color: Color(0xFF1976D2),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Card(
                color: const Color(0xFFE0E0E0),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Total Expense:',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Colors.black54,
                        ),
                      ),
                      Text(
                        '₱${totalAmount.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF212121),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],

            if (_selectedParticipants.isNotEmpty) ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _computeExpenses,
                  icon: const Icon(Icons.calculate, color: Colors.white, size: 28),
                  label: const Text(
                    'Compute Expenses',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1976D2),
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    elevation: 6,
                    shadowColor: const Color(0xFF1976D2).withOpacity(0.4),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ] else
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 32.0),
                child: Center(
                  child: Column(
                    children: [
                      Icon(
                        Icons.people_outline,
                        size: 64,
                        color: Colors.grey.shade300,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'No participants yet',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionsView(double totalAmount) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFF),
      appBar: AppBar(
        title: const Text('Expense Calculation'),
        backgroundColor: const Color(0xFF1976D2),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            setState(() {
              _showTransactions = false;
            });
          },
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              color: Colors.white,
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _expenseNameController.text,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Total Expense:',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                        Text(
                          '₱${totalAmount.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1976D2),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Participants:',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                        Text(
                          _selectedParticipants.length.toString(),
                          style: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFF1976D2),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            const Text(
              'Who Pays Whom',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 12),
            if (_calculatedTransactions.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 32.0),
                  child: Text('No transactions needed'),
                ),
              )
            else
              ..._calculatedTransactions.map((transaction) {
                return Card(
                  elevation: 2,
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                RichText(
                                  text: TextSpan(
                                    children: [
                                      TextSpan(
                                        text: transaction['from'],
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.black,
                                          fontSize: 16,
                                        ),
                                      ),
                                      const TextSpan(
                                        text: ' pays ',
                                        style: TextStyle(
                                          color: Colors.grey,
                                          fontSize: 14,
                                        ),
                                      ),
                                      TextSpan(
                                        text: transaction['to'],
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF1976D2),
                                          fontSize: 16,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF1976D2),
                                    borderRadius: BorderRadius.circular(8),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFF1976D2).withOpacity(0.3),
                                        blurRadius: 4,
                                      ),
                                    ],
                                  ),
                                  child: Text(
                                    '₱${(transaction['amount'] as num).toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                        ],
                      ),
                    ),
                  ),
                );
              }),
            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _saveExpense,
                icon: _isLoading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Icon(Icons.save, color: Colors.white, size: 28),
                label: Text(
                  _isLoading ? 'Saving...' : 'Save Expense',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1976D2),
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  elevation: 6,
                  shadowColor: const Color(0xFF1976D2).withOpacity(0.4),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showPaymentQR(String receiverName, int receiverId) async {
    // Fetch receiver's QR codes
    final receiverQRCodes = await _expenseRepo.getUserQRCodes(receiverId);
    
    if (!mounted) return;
    
    if (receiverQRCodes.isEmpty) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Pay $receiverName'),
          content: const Text(
            'The receiver has not uploaded any QR codes yet.\n\nPlease ask them to add their payment QR codes in their profile.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    // Load QR code images
    List<Map<String, dynamic>> qrWithImages = [];
    for (var qr in receiverQRCodes) {
      final imagePath = qr['image_path'];
      
      // Check if it's a server path or local file
      if (imagePath.startsWith('/uploads/')) {
        // Server path
        final imageUrl = ImageStorageService.getImageUrl(imagePath);
        qrWithImages.add({
          'id': qr['qr_code_id'],
          'label': qr['label'],
          'image': null,
          'imageUrl': imageUrl,
          'path': imagePath,
        });
      } else {
        // Local file
        final file = File(imagePath);
        if (await file.exists()) {
          qrWithImages.add({
            'id': qr['qr_code_id'],
            'label': qr['label'],
            'image': file,
            'imageUrl': null,
            'path': imagePath,
          });
        }
      }
    }

    if (qrWithImages.isEmpty) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Pay $receiverName'),
          content: const Text('QR codes could not be loaded.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Pay $receiverName'),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Select payment method:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              SingleChildScrollView(
                child: Column(
                  children: qrWithImages.map((qrData) {
                    return GestureDetector(
                      onTap: () {
                        Navigator.pop(context);
                        _showQRDetail(receiverName, qrData);
                      },
                      child: Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 80,
                                height: 80,
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: qrData['imageUrl'] != null
                                      ? Image.network(
                                          qrData['imageUrl'],
                                          fit: BoxFit.cover,
                                          errorBuilder: (context, error, stackTrace) {
                                            print('❌ Create expense QR error: $error');
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
                                        )
                                      : Image.file(
                                          qrData['image'],
                                          fit: BoxFit.cover,
                                        ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      qrData['label'],
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    const Text(
                                      'Tap to view',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(Icons.arrow_forward_ios, size: 16),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
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
        ],
      ),
    );
  }

  void _showQRDetail(String receiverName, Map<String, dynamic> qrData) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${qrData['label']} - Pay $receiverName'),
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
              'Show this QR code to complete the payment',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }
}
