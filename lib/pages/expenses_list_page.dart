import 'package:flutter/material.dart';
import 'package:equisplit/repositories/expense_repository.dart';
import 'package:equisplit/widgets/custom_loading_indicator.dart';

class ExpensesListPage extends StatefulWidget {
  final Map<String, dynamic>? user;

  const ExpensesListPage({super.key, this.user});

  @override
  State<ExpensesListPage> createState() => _ExpensesListPageState();
}

class _ExpensesListPageState extends State<ExpensesListPage> {
  final _expenseRepo = ExpenseRepository();
  late Future<List<Map<String, dynamic>>> _expensesFuture;

  @override
  void initState() {
    super.initState();
    _refreshExpenses();
  }

  void _refreshExpenses() {
    final userId = widget.user?['user_id'] ?? 1;
    _expensesFuture = _expenseRepo.getExpensesUserJoined(userId);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final userId = widget.user?['user_id'] ?? 1;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Expenses'),
        backgroundColor: const Color(0xFF1976D2),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          _refreshExpenses();
          await Future.delayed(const Duration(milliseconds: 500));
        },
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: _expensesFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(child: CustomLoadingIndicator());
            }

            if (snapshot.hasError) {
              return Center(
                child: Text(
                  'Error loading expenses: ${snapshot.error}',
                  style: const TextStyle(color: Colors.red),
                ),
              );
            }

            final expensesList = snapshot.data ?? [];

            if (expensesList.isEmpty) {
              return const Center(
                child: Text(
                  'No expenses joined',
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 16,
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: expensesList.length,
            itemBuilder: (context, index) {
              final expense = expensesList[index];
              final expenseId = expense['expense_id']?.toString() ?? 'N/A';
              final expenseName = expense['expense_name']?.toString() ?? 'N/A';
              final totalAmount = (expense['total_amount'] as num?)?.toDouble() ?? 0.0;
              final remainingToReceive = (expense['remaining_to_receive'] as num?)?.toDouble() ?? 0.0;
              final remainingToPay = (expense['remaining_to_pay'] as num?)?.toDouble() ?? 0.0;
              final status = expense['status']?.toString() ?? 'N/A';
              final expenseType = (expense['expense_type'] as String?) ?? 'evenly';
              final totalProofsSent = (expense['total_proofs_sent'] as num?)?.toInt() ?? 0;
              final pendingApprovals = (expense['pending_approvals'] as num?)?.toInt() ?? 0;

              // Format ID with left padding (lpad)
              final formattedId = expenseId.padLeft(8, '0');

              final isActive = status.toLowerCase() == 'active';
              final statusColor = isActive ? Colors.green : Colors.orange;
              
              // Determine expense type label and icon
              String typeLabel = '';
              IconData typeIcon = Icons.balance;
              Color typeColor = Colors.blue;
              
              switch (expenseType.toLowerCase()) {
                case 'borrowed':
                  typeLabel = 'Borrowed';
                  typeIcon = Icons.card_giftcard;
                  typeColor = const Color(0xFFFF9800);
                  break;
                case 'partial':
                  typeLabel = 'Partial';
                  typeIcon = Icons.people_alt;
                  typeColor = const Color(0xFF9C27B0);
                  break;
                case 'evenly':
                default:
                  typeLabel = 'Evenly';
                  typeIcon = Icons.balance;
                  typeColor = Colors.blue;
              }
              
              // Determine what to show - only user's personal remaining amount
              String amountDisplay = '';
              Color amountColor = Colors.grey;
              
              if (remainingToReceive > 0.01) {
                // Still need to receive
                amountDisplay = 'Pending: ₱${remainingToReceive.toStringAsFixed(2)} to receive';
                amountColor = Colors.blue;
              } else if (remainingToPay > 0.01) {
                // Still need to pay
                amountDisplay = 'Pending: ₱${remainingToPay.toStringAsFixed(2)} to pay';
                amountColor = Colors.red;
              } else {
                // Everything settled
                amountDisplay = '✓ Paid';
                amountColor = Colors.green;
              }

              // Determine proof status message
              String proofStatusMessage = '';
              if (remainingToPay > 0.01) {
                // User still owes money
                if (totalProofsSent > 0 && pendingApprovals > 0) {
                  proofStatusMessage = '⏳ Waiting for approval';
                } else if (totalProofsSent > 0) {
                  proofStatusMessage = '✓ Proof sent';
                }
              }

              return GestureDetector(
                onTap: () {
                  Navigator.pushNamed(
                    context,
                    '/expense-details',
                    arguments: {
                      'expense_id': int.parse(expenseId),
                      'current_user': widget.user,
                    },
                  );
                },
                child: Card(
                  elevation: 4,
                  margin: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      gradient: LinearGradient(
                        colors: remainingToPay > remainingToReceive
                            ? [
                                Colors.red.shade50,
                                Colors.red.shade100,
                              ]
                            : [
                                Colors.white,
                                Colors.grey.shade50,
                              ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          // Colorful Circle with Icon
                          Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: remainingToPay > remainingToReceive
                                    ? [
                                        const Color(0xFFD32F2F),
                                        const Color(0xFFC62828),
                                      ]
                                    : [
                                        const Color(0xFF1976D2),
                                        const Color(0xFF1565C0),
                                      ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: remainingToPay > remainingToReceive
                                      ? const Color(0xFFD32F2F).withValues(alpha: 0.3)
                                      : const Color(0xFF1976D2).withValues(alpha: 0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Center(
                              child: Icon(
                                Icons.receipt_long,
                                color: Colors.white,
                                size: 28,
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          // Content
                          Expanded(
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
                                          Text(
                                            expenseName,
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFF212121),
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 4),
                                          Row(
                                            children: [
                                              Text(
                                                'ID: $formattedId',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.grey[500],
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Container(
                                                padding: const EdgeInsets.symmetric(
                                                  horizontal: 6,
                                                  vertical: 2,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: typeColor.withValues(alpha: 0.15),
                                                  borderRadius: BorderRadius.circular(4),
                                                ),
                                                child: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Icon(
                                                      typeIcon,
                                                      size: 10,
                                                      color: typeColor,
                                                    ),
                                                    const SizedBox(width: 3),
                                                    Text(
                                                      typeLabel,
                                                      style: TextStyle(
                                                        fontSize: 10,
                                                        color: typeColor,
                                                        fontWeight: FontWeight.bold,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    // Amount Badge
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF1976D2)
                                            .withValues(alpha: 0.1),
                                        borderRadius:
                                            BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        '₱${totalAmount.toStringAsFixed(2)}',
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF1976D2),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                // Amount owed/owes info - small font
                                Text(
                                  amountDisplay,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: amountColor,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                if (proofStatusMessage.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4.0),
                                    child: Text(
                                      proofStatusMessage,
                                      style: const TextStyle(
                                        fontSize: 10,
                                        color: Colors.grey,
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                  ),
                                const SizedBox(height: 8),
                                // Status and Arrow
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: statusColor.withValues(
                                          alpha: 0.15,
                                        ),
                                        borderRadius:
                                            BorderRadius.circular(6),
                                        border: Border.all(
                                          color: statusColor.withValues(
                                            alpha: 0.4,
                                          ),
                                          width: 1,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Container(
                                            width: 6,
                                            height: 6,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: statusColor,
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            status,
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                              color: statusColor,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Icon(
                                      Icons.arrow_forward_ios_rounded,
                                      color: Colors.grey[400],
                                      size: 16,
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
                ),
              );
            },
          );
        },
      ),
      ),
    );
  }
}
