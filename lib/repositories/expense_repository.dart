import 'package:equisplit/services/database_service.dart';
import 'package:equisplit/services/splitting_service.dart';

class ExpenseRepository {
  final _db = DatabaseService();

  // ============ EXPENSES TABLE ============

  /// Create a new expense
  Future<int?> createExpense({
    required String expenseName,
    required String description,
    required double totalAmount,
    required int createdBy,
    String currency = 'PHP',
    String status = 'active',
    String expenseType = 'evenly',
  }) async {
    try {
      await _db.execute(
        '''INSERT INTO equisplit.expenses 
           (expense_name, description, total_amount, created_by, currency, status, expense_type) 
           VALUES (?, ?, ?, ?, ?, ?, ?)''',
        [expenseName, description, totalAmount, createdBy, currency, status, expenseType],
      );
      return await _db.getLastInsertId();
    } catch (e) {
      print('Error creating expense: $e');
      return null;
    }
  }

  /// Get all expenses
  Future<List<Map<String, dynamic>>> getAllExpenses() async {
    try {
      return await _db.query(
        'SELECT * FROM equisplit.expenses ORDER BY created_date DESC',
      );
    } catch (e) {
      print('Error fetching expenses: $e');
      return [];
    }
  }

  /// Get expenses by user
  Future<List<Map<String, dynamic>>> getExpensesByUser(int userId) async {
    try {
      return await _db.query(
        'SELECT * FROM equisplit.expenses WHERE created_by = ? ORDER BY created_date DESC',
        [userId],
      );
    } catch (e) {
      print('Error fetching user expenses: $e');
      return [];
    }
  }

  /// Get single expense
  Future<Map<String, dynamic>?> getExpenseById(int expenseId) async {
    try {
      return await _db.queryOne(
        'SELECT u.*, a.name as creator_name FROM equisplit.expenses u LEFT JOIN equisplit.user a ON a.user_id = u.created_by WHERE u.expense_id = ?',
        [expenseId],
      );
    } catch (e) {
      print('Error fetching expense: $e');
      return null;
    }
  }

  /// Update expense
  Future<bool> updateExpense({
    required int expenseId,
    required String expenseName,
    required String description,
    required double totalAmount,
    required String status,
  }) async {
    try {
      await _db.execute(
        '''UPDATE equisplit.expenses 
           SET expense_name = ?, description = ?, total_amount = ?, status = ? 
           WHERE expense_id = ?''',
        [expenseName, description, totalAmount, status, expenseId],
      );
      return true;
    } catch (e) {
      print('Error updating expense: $e');
      return false;
    }
  }

  // ============ EXPENSE PARTICIPANTS TABLE ============

  /// Add participant to expense
  Future<bool> addExpenseParticipant({
    required int expenseId,
    required int userId,
    required double contributionAmount,
    bool isPaid = false,
  }) async {
    try {
      await _db.execute(
        '''INSERT INTO equisplit.expense_participants 
           (expense_id, user_id, contribution_amount, is_paid) 
           VALUES (?, ?, ?, ?)''',
        [expenseId, userId, contributionAmount, isPaid ? 1 : 0],
      );
      return true;
    } catch (e) {
      print('Error adding participant: $e');
      return false;
    }
  }

  /// Get all participants of an expense
  Future<List<Map<String, dynamic>>> getExpenseParticipants(int expenseId) async {
    try {
      return await _db.query(
        '''SELECT ep.*, u.name, u.username, ua.image_path as avatar_path
           FROM equisplit.expense_participants ep
           JOIN equisplit.user u ON ep.user_id = u.user_id
           LEFT JOIN equisplit.user_avatars ua ON u.user_id = ua.user_id
           WHERE ep.expense_id = ?''',
        [expenseId],
      );
    } catch (e) {
      print('Error fetching participants: $e');
      return [];
    }
  }

  /// Update participant contribution
  Future<bool> updateParticipantContribution({
    required int participantId,
    required double contributionAmount,
    required bool isPaid,
  }) async {
    try {
      await _db.execute(
        '''UPDATE equisplit.expense_participants 
           SET contribution_amount = ?, is_paid = ? 
           WHERE participant_id = ?''',
        [contributionAmount, isPaid ? 1 : 0, participantId],
      );
      return true;
    } catch (e) {
      print('Error updating participant: $e');
      return false;
    }
  }

  // ============ TRANSACTIONS TABLE ============

  /// Create transaction (who owes whom)
  Future<bool> createTransaction({
    required int expenseId,
    required int payerId,
    required int payeeId,
    required double amount,
    String description = '',
    String status = 'pending',
  }) async {
    try {
      await _db.execute(
        '''INSERT INTO equisplit.transactions 
           (expense_id, payer_id, payee_id, amount, description, status) 
           VALUES (?, ?, ?, ?, ?, ?)''',
        [expenseId, payerId, payeeId, amount, description, status],
      );
      return true;
    } catch (e) {
      print('Error creating transaction: $e');
      return false;
    }
  }

  /// Get all transactions for an expense
  Future<List<Map<String, dynamic>>> getExpenseTransactions(int expenseId) async {
    try {
      return await _db.query(
        '''SELECT t.*, 
           u1.name as payer_name, u1.username as payer_username,
           u2.name as payee_name, u2.username as payee_username,
           (SELECT GROUP_CONCAT(CONCAT(qr_code_id, ':', image_path, ':', label, ':', is_default) SEPARATOR ';') 
            FROM equisplit.user_qr_codes 
            WHERE user_id = u2.user_id AND is_active = TRUE) as payee_qr_list,
           ua1.image_path as payer_avatar, ua2.image_path as payee_avatar
           FROM equisplit.transactions t
           JOIN equisplit.user u1 ON t.payer_id = u1.user_id
           JOIN equisplit.user u2 ON t.payee_id = u2.user_id
           LEFT JOIN equisplit.user_avatars ua1 ON u1.user_id = ua1.user_id
           LEFT JOIN equisplit.user_avatars ua2 ON u2.user_id = ua2.user_id
           WHERE t.expense_id = ?
           GROUP BY t.transaction_id''',
        [expenseId],
      );
    } catch (e) {
      print('Error fetching transactions: $e');
      return [];
    }
  }

  /// Add proof of payment with retry logic
  Future<bool> addProofOfPayment({
    required int transactionId,
    required String imagePath,
    required int uploadedBy,
  }) async {
    int maxRetries = 3;
    int currentRetry = 0;
    
    while (currentRetry < maxRetries) {
      try {
        await _db.execute(
          '''INSERT INTO equisplit.proof_of_payment 
             (transaction_id, image_path, uploaded_by, approval_status, uploaded_date) 
             VALUES (?, ?, ?, 'pending', CURRENT_TIMESTAMP)''',
          [transactionId, imagePath, uploadedBy],
        );
        print('✅ Proof of payment added successfully');
        return true;
      } catch (e) {
        currentRetry++;
        print('❌ Error adding proof of payment (Attempt $currentRetry/$maxRetries): $e');
        
        if (currentRetry < maxRetries) {
          // Wait before retrying
          await Future.delayed(Duration(milliseconds: 500 * currentRetry));
          print('🔄 Retrying proof of payment upload...');
          continue;
        } else {
          print('❌ Failed to add proof of payment after $maxRetries attempts');
          return false;
        }
      }
    }
    return false;
  }

  /// Get proof of payment for a transaction
  Future<Map<String, dynamic>?> getProofOfPayment(int transactionId) async {
    try {
      return await _db.queryOne(
        'SELECT * FROM equisplit.proof_of_payment WHERE transaction_id = ?',
        [transactionId],
      );
    } catch (e) {
      print('Error fetching proof of payment: $e');
      return null;
    }
  }

  /// Mark transaction as paid
  Future<bool> markTransactionAsPaid(int transactionId) async {
    try {
      await _db.execute(
        '''UPDATE equisplit.transactions 
           SET status = 'paid', paid_date = NOW() 
           WHERE transaction_id = ?''',
        [transactionId],
      );
      return true;
    } catch (e) {
      print('Error marking transaction as paid: $e');
      return false;
    }
  }

  /// Approve proof of payment (receiver approves)
  Future<bool> approveProofOfPayment({
    required int proofId,
    required int approvedBy,
  }) async {
    try {
      await _db.execute(
        '''UPDATE equisplit.proof_of_payment 
           SET approval_status = 'approved', approved_by = ?, approval_date = NOW() 
           WHERE proof_id = ?''',
        [approvedBy, proofId],
      );
      
      // Also mark transaction as paid
      final proof = await _db.queryOne(
        'SELECT transaction_id FROM equisplit.proof_of_payment WHERE proof_id = ?',
        [proofId],
      );
      
      if (proof != null) {
        await markTransactionAsPaid(proof['transaction_id'] as int);
      }
      
      return true;
    } catch (e) {
      print('Error approving proof of payment: $e');
      return false;
    }
  }

  /// Reject proof of payment
  Future<bool> rejectProofOfPayment(int proofId) async {
    try {
      await _db.execute(
        '''UPDATE equisplit.proof_of_payment 
           SET approval_status = 'rejected' 
           WHERE proof_id = ?''',
        [proofId],
      );
      return true;
    } catch (e) {
      print('Error rejecting proof of payment: $e');
      return false;
    }
  }

  /// Get pending proofs for a user (as receiver)
  Future<List<Map<String, dynamic>>> getPendingProofsForUser(int userId) async {
    try {
      return await _db.query(
        '''SELECT p.proof_id, p.transaction_id, p.image_path, p.uploaded_by, p.approval_status, p.uploaded_date,
                  t.amount, t.payer_id, t.transaction_id, u.name as payer_name, e.expense_name
           FROM equisplit.proof_of_payment p
           JOIN equisplit.transactions t ON p.transaction_id = t.transaction_id
           JOIN equisplit.user u ON t.payer_id = u.user_id
           JOIN equisplit.expenses e ON t.expense_id = e.expense_id
           WHERE t.payee_id = ? AND p.approval_status = 'pending'
           ORDER BY p.uploaded_date DESC''',
        [userId],
      );
    } catch (e) {
      print('Error fetching pending proofs: $e');
      return [];
    }
  }

  /// Get pending transactions for a user (payments they need to make)
  Future<List<Map<String, dynamic>>> getPendingPaymentsForUser(int userId) async {
    try {
      return await _db.query(
        '''SELECT t.*, 
           u1.name as payer_name, u1.username as payer_username,
           u2.name as payee_name, u2.username as payee_username,
           e.expense_name,
           (SELECT COUNT(*) FROM equisplit.proof_of_payment WHERE transaction_id = t.transaction_id AND approval_status = 'pending') as pending_proofs,
           (SELECT MAX(approval_status) FROM equisplit.proof_of_payment WHERE transaction_id = t.transaction_id) as latest_approval_status
           FROM equisplit.transactions t
           JOIN equisplit.user u1 ON t.payer_id = u1.user_id
           JOIN equisplit.user u2 ON t.payee_id = u2.user_id
           JOIN equisplit.expenses e ON t.expense_id = e.expense_id
           WHERE t.payer_id = ? AND t.status = 'pending'
           ORDER BY t.created_date DESC''',
        [userId],
      );
    } catch (e) {
      print('Error fetching pending payments: $e');
      return [];
    }
  }

  /// Get pending payments where user is the payee (others owe them)
  Future<List<Map<String, dynamic>>> getPendingPaymentsOwedToUser(int userId) async {
    try {
      return await _db.query(
        '''SELECT t.*, 
           u1.name as payer_name, u1.username as payer_username,
           u2.name as payee_name, u2.username as payee_username,
           e.expense_name,
           (SELECT COUNT(*) FROM equisplit.proof_of_payment WHERE transaction_id = t.transaction_id AND approval_status = 'pending') as pending_proofs,
           (SELECT MAX(approval_status) FROM equisplit.proof_of_payment WHERE transaction_id = t.transaction_id) as latest_approval_status
           FROM equisplit.transactions t
           JOIN equisplit.user u1 ON t.payer_id = u1.user_id
           JOIN equisplit.user u2 ON t.payee_id = u2.user_id
           JOIN equisplit.expenses e ON t.expense_id = e.expense_id
           WHERE t.payee_id = ? AND t.status = 'pending'
           ORDER BY t.created_date DESC''',
        [userId],
      );
    } catch (e) {
      print('Error fetching payments owed to user: $e');
      return [];
    }
  }

  /// Get all transactions involving a user (as payer or payee)
  Future<List<Map<String, dynamic>>> getAllUserTransactions(int userId) async {
    try {
      return await _db.query(
        '''SELECT t.*, 
           u1.name as payer_name, u1.username as payer_username,
           u2.name as payee_name, u2.username as payee_username,
           e.expense_name,
           p.proof_id, p.approval_status,
           CASE WHEN p.approval_status = 'approved' THEN 1 ELSE 0 END as is_proof_approved,
           CASE WHEN t.status = 'paid' THEN 1 ELSE 0 END as is_transaction_paid
           FROM equisplit.transactions t
           JOIN equisplit.user u1 ON t.payer_id = u1.user_id
           JOIN equisplit.user u2 ON t.payee_id = u2.user_id
           JOIN equisplit.expenses e ON t.expense_id = e.expense_id
           LEFT JOIN equisplit.proof_of_payment p ON t.transaction_id = p.transaction_id
           WHERE (t.payer_id = ? OR t.payee_id = ?)
           ORDER BY t.created_date DESC''',
        [userId, userId],
      );
    } catch (e) {
      print('Error fetching all user transactions: $e');
      return [];
    }
  }

  /// Get only approved transactions for payment history display
  Future<List<Map<String, dynamic>>> getApprovedUserTransactions(int userId) async {
    try {
      return await _db.query(
        '''SELECT t.*, 
           u1.name as payer_name, u1.username as payer_username,
           u2.name as payee_name, u2.username as payee_username,
           e.expense_name,
           p.proof_id, p.approval_status,
           CASE WHEN p.approval_status = 'approved' THEN 1 ELSE 0 END as is_proof_approved,
           CASE WHEN t.status = 'paid' THEN 1 ELSE 0 END as is_transaction_paid
           FROM equisplit.transactions t
           JOIN equisplit.user u1 ON t.payer_id = u1.user_id
           JOIN equisplit.user u2 ON t.payee_id = u2.user_id
           JOIN equisplit.expenses e ON t.expense_id = e.expense_id
           LEFT JOIN equisplit.proof_of_payment p ON t.transaction_id = p.transaction_id
           WHERE (t.payer_id = ? OR t.payee_id = ?)
           AND p.approval_status = 'approved'
           ORDER BY t.created_date DESC''',
        [userId, userId],
      );
    } catch (e) {
      print('Error fetching approved user transactions: $e');
      return [];
    }
  }

  /// Get paid transactions for a user (payments I have made)
  Future<List<Map<String, dynamic>>> getPaidTransactionsForUser(int userId) async {
    try {
      return await _db.query(
        '''SELECT t.*, 
           u2.name as payee_name, u2.username as payee_username,
           e.expense_name, 'paid' as proof_status
           FROM equisplit.transactions t
           JOIN equisplit.user u2 ON t.payee_id = u2.user_id
           JOIN equisplit.expenses e ON t.expense_id = e.expense_id
           WHERE t.payer_id = ? AND t.status = 'paid'
           ORDER BY t.paid_date DESC''',
        [userId],
      );
    } catch (e) {
      print('Error fetching paid transactions: $e');
      return [];
    }
  }

  /// Get payment history (all transactions user is involved in - sent or received)
  Future<List<Map<String, dynamic>>> getPaymentHistory(int userId) async {
    try {
      return await _db.query(
        '''SELECT t.transaction_id, t.amount, t.payer_id, t.payee_id, 
                  t.expense_id, t.status, t.paid_date, t.created_date,
                  u1.name as payer_name,
                  u2.name as payee_name,
                  e.expense_name,
                  p.proof_id, p.approval_status, p.uploaded_date,
                  COALESCE(p.approval_status, t.status) as proof_status,
                  CASE WHEN t.payer_id = ? THEN 'sent' ELSE 'received' END as payment_type
           FROM equisplit.transactions t
           JOIN equisplit.user u1 ON t.payer_id = u1.user_id
           JOIN equisplit.user u2 ON t.payee_id = u2.user_id
           JOIN equisplit.expenses e ON t.expense_id = e.expense_id
           LEFT JOIN equisplit.proof_of_payment p ON t.transaction_id = p.transaction_id
           WHERE (t.payer_id = ? OR t.payee_id = ?)
           AND (t.status = 'paid' OR p.approval_status = 'approved')
           ORDER BY COALESCE(t.paid_date, p.uploaded_date, t.created_date) DESC''',
        [userId, userId, userId],
      );
    } catch (e) {
      print('Error fetching payment history: $e');
      return [];
    }
  }

  /// Get expense status with paid amount and remaining balance
  Future<Map<String, dynamic>?> getExpenseStatusWithPaidAmount(int expenseId) async {
    try {
      final result = await _db.query(
        '''SELECT e.expense_id, e.expense_name, e.total_amount,
                  COALESCE(SUM(CASE WHEN p.approval_status = 'approved' THEN t.amount ELSE 0 END), 0) as paid_amount,
                  e.total_amount - COALESCE(SUM(CASE WHEN p.approval_status = 'approved' THEN t.amount ELSE 0 END), 0) as remaining_amount
           FROM equisplit.expenses e
           LEFT JOIN equisplit.transactions t ON e.expense_id = t.expense_id
           LEFT JOIN equisplit.proof_of_payment p ON t.transaction_id = p.transaction_id
           WHERE e.expense_id = ?
           GROUP BY e.expense_id''',
        [expenseId],
      );
      return result.isNotEmpty ? result[0] : null;
    } catch (e) {
      print('Error fetching expense status: $e');
      return null;
    }
  }  // ============ USER QR CODES TABLE ============

  /// Add QR code for user
  Future<bool> addUserQRCode({
    required int userId,
    required String label,
    required String imagePath,
    bool isActive = true,
  }) async {
    try {
      await _db.execute(
        '''INSERT INTO equisplit.user_qr_codes 
           (user_id, label, image_path, is_active) 
           VALUES (?, ?, ?, ?)''',
        [userId, label, imagePath, isActive ? 1 : 0],
      );
      return true;
    } catch (e) {
      print('Error adding QR code: $e');
      return false;
    }
  }

  /// Get all QR codes for user
  Future<List<Map<String, dynamic>>> getUserQRCodes(int userId) async {
    try {
      return await _db.query(
        '''SELECT * FROM equisplit.user_qr_codes 
           WHERE user_id = ? AND is_active = TRUE
           ORDER BY created_date DESC''',
        [userId],
      );
    } catch (e) {
      print('Error fetching QR codes: $e');
      return [];
    }
  }

  /// Get QR codes for a payee (for selection during payment)
  Future<List<Map<String, dynamic>>> getPayeeQRCodes(int payeeId) async {
    try {
      return await _db.query(
        '''SELECT * FROM equisplit.user_qr_codes 
           WHERE user_id = ? AND is_active = TRUE
           ORDER BY created_date DESC''',
        [payeeId],
      );
    } catch (e) {
      print('Error fetching payee QR codes: $e');
      return [];
    }
  }

  /// Delete QR code
  Future<bool> deleteQRCode(int qrCodeId) async {
    try {
      await _db.execute(
        'DELETE FROM equisplit.user_qr_codes WHERE qr_code_id = ?',
        [qrCodeId],
      );
      return true;
    } catch (e) {
      print('Error deleting QR code: $e');
      return false;
    }
  }

  /// Set QR code as default for a user
  Future<bool> setDefaultQRCode(int userId, int qrCodeId) async {
    try {
      // First, unset all QR codes for this user
      await _db.execute(
        '''UPDATE equisplit.user_qr_codes 
           SET is_default = 0 
           WHERE user_id = ?''',
        [userId],
      );
      
      // Then set the selected one as default
      await _db.execute(
        '''UPDATE equisplit.user_qr_codes 
           SET is_default = 1 
           WHERE qr_code_id = ? AND user_id = ?''',
        [qrCodeId, userId],
      );
      return true;
    } catch (e) {
      print('Error setting default QR code: $e');
      return false;
    }
  }

  // ============ EXPENSE ITEMS TABLE ============

  /// Add item to expense
  Future<bool> addExpenseItem({
    required int expenseId,
    required String itemName,
    required int quantity,
    required double unitPrice,
    required double totalPrice,
    String notes = '',
  }) async {
    try {
      await _db.execute(
        '''INSERT INTO equisplit.expense_items 
           (expense_id, item_name, quantity, unit_price, total_price, notes) 
           VALUES (?, ?, ?, ?, ?, ?)''',
        [expenseId, itemName, quantity, unitPrice, totalPrice, notes],
      );
      return true;
    } catch (e) {
      print('Error adding expense item: $e');
      return false;
    }
  }

  /// Get all items for an expense
  Future<List<Map<String, dynamic>>> getExpenseItems(int expenseId) async {
    try {
      return await _db.query(
        'SELECT * FROM equisplit.expense_items WHERE expense_id = ?',
        [expenseId],
      );
    } catch (e) {
      print('Error fetching expense items: $e');
      return [];
    }
  }

  // ============ SPLIT HISTORY TABLE ============

  /// Add history record
  Future<bool> addSplitHistory({
    required int expenseId,
    required String action,
    int? userId,
    String details = '',
  }) async {
    try {
      await _db.execute(
        '''INSERT INTO equisplit.split_history 
           (expense_id, action, user_id, details) 
           VALUES (?, ?, ?, ?)''',
        [expenseId, action, userId, details],
      );
      return true;
    } catch (e) {
      print('Error adding split history: $e');
      return false;
    }
  }

  /// Get history for an expense
  Future<List<Map<String, dynamic>>> getExpenseHistory(int expenseId) async {
    try {
      return await _db.query(
        '''SELECT sh.*, u.name, u.username 
           FROM equisplit.split_history sh
           LEFT JOIN equisplit.user u ON sh.user_id = u.user_id
           WHERE sh.expense_id = ?
           ORDER BY sh.created_date DESC''',
        [expenseId],
      );
    } catch (e) {
      print('Error fetching split history: $e');
      return [];
    }
  }

  // ============ SPLITTING LOGIC ============

  /// Calculate and create optimal transactions for an expense
  Future<bool> calculateAndSaveTransactions(int expenseId) async {
    try {
      // Get expense details
      final expense = await getExpenseById(expenseId);
      if (expense == null) return false;

      // Get participants
      final participants = await getExpenseParticipants(expenseId);
      if (participants.isEmpty) return false;

      // Prepare data for splitting service
      List<String> userIds = [];
      Map<String, double> contributions = {};

      for (var participant in participants) {
        String userId = participant['user_id'].toString();
        userIds.add(userId);
        contributions[userId] =
            (participant['contribution_amount'] as num).toDouble();
      }

      // Get expense type
      String expenseType = (expense['expense_type'] as String?) ?? 'evenly';

      // Calculate transactions using splitting service based on type
      List<Transaction> transactions = SplittingService.calculateTransactionsByType(
        userIds,
        contributions,
        (expense['total_amount'] as num).toDouble(),
        expenseType,
      );

      // Save all transactions to database
      for (var transaction in transactions) {
        await createTransaction(
          expenseId: expenseId,
          payerId: int.parse(transaction.from),
          payeeId: int.parse(transaction.to),
          amount: transaction.amount,
          description: transaction.toString(),
          status: 'pending',
        );
      }

      // Add history record
      await addSplitHistory(
        expenseId: expenseId,
        action: 'transactions_calculated',
        details: 'Calculated ${transactions.length} optimal transactions',
      );

      return true;
    } catch (e) {
      print('Error calculating transactions: $e');
      return false;
    }
  }

  /// Get summary for dashboard
  Future<Map<String, dynamic>?> getExpenseSummary(int expenseId) async {
    try {
      final expense = await getExpenseById(expenseId);
      final participants = await getExpenseParticipants(expenseId);
      final transactions = await getExpenseTransactions(expenseId);
      final items = await getExpenseItems(expenseId);

      return {
        'expense': expense,
        'participants': participants,
        'transactions': transactions,
        'items': items,
        'participant_count': participants.length,
        'transaction_count': transactions.length,
        'paid_count':
            transactions.where((t) => t['status'] == 'paid').length,
      };
    } catch (e) {
      print('Error fetching expense summary: $e');
      return null;
    }
  }

  /// Get all expenses that a user participated in
  Future<List<Map<String, dynamic>>> getExpensesUserJoined(int userId) async {
    try {
      return await _db.query(
        '''SELECT e.expense_id, e.expense_name, e.description, e.total_amount, 
                  e.status, e.expense_type, u.name as created_by,
                  COALESCE(SUM(CASE WHEN t.payee_id = ? THEN t.amount ELSE 0 END), 0) as amount_owed_to_user,
                  COALESCE(SUM(CASE WHEN t.payer_id = ? THEN t.amount ELSE 0 END), 0) as amount_user_owes,
                  (SELECT COALESCE(SUM(t2.amount), 0) FROM equisplit.transactions t2 
                   LEFT JOIN equisplit.proof_of_payment p2 ON t2.transaction_id = p2.transaction_id
                   WHERE t2.expense_id = e.expense_id AND t2.payee_id = ? AND (t2.status = 'paid' OR p2.approval_status = 'approved')) as amount_received_by_user,
                  (SELECT COALESCE(SUM(t3.amount), 0) FROM equisplit.transactions t3 
                   LEFT JOIN equisplit.proof_of_payment p3 ON t3.transaction_id = p3.transaction_id
                   WHERE t3.expense_id = e.expense_id AND t3.payer_id = ? AND (t3.status = 'paid' OR p3.approval_status = 'approved')) as amount_paid_by_user,
                  COALESCE(SUM(CASE WHEN t.payee_id = ? THEN t.amount ELSE 0 END), 0) - 
                  (SELECT COALESCE(SUM(t2.amount), 0) FROM equisplit.transactions t2 
                   LEFT JOIN equisplit.proof_of_payment p2 ON t2.transaction_id = p2.transaction_id
                   WHERE t2.expense_id = e.expense_id AND t2.payee_id = ? AND (t2.status = 'paid' OR p2.approval_status = 'approved')) as remaining_to_receive,
                  COALESCE(SUM(CASE WHEN t.payer_id = ? THEN t.amount ELSE 0 END), 0) - 
                  (SELECT COALESCE(SUM(t3.amount), 0) FROM equisplit.transactions t3 
                   LEFT JOIN equisplit.proof_of_payment p3 ON t3.transaction_id = p3.transaction_id
                   WHERE t3.expense_id = e.expense_id AND t3.payer_id = ? AND (t3.status = 'paid' OR p3.approval_status = 'approved')) as remaining_to_pay,
                  (SELECT COUNT(*) FROM equisplit.proof_of_payment p 
                   LEFT JOIN equisplit.transactions t ON p.transaction_id = t.transaction_id
                   WHERE t.expense_id = e.expense_id AND t.payer_id = ?) as total_proofs_sent,
                  (SELECT COUNT(*) FROM equisplit.proof_of_payment p 
                   LEFT JOIN equisplit.transactions t ON p.transaction_id = t.transaction_id
                   WHERE t.expense_id = e.expense_id AND t.payer_id = ? AND p.approval_status = 'pending') as pending_approvals
           FROM equisplit.expenses e
           JOIN equisplit.expense_participants ep ON e.expense_id = ep.expense_id
           LEFT JOIN equisplit.user u ON e.created_by = u.user_id
           LEFT JOIN equisplit.transactions t ON e.expense_id = t.expense_id
           WHERE ep.user_id = ?
           GROUP BY e.expense_id
           ORDER BY e.expense_id DESC''',
        [userId, userId, userId, userId, userId, userId, userId, userId, userId, userId, userId],
      );
    } catch (e) {
      print('Error fetching expenses user joined: $e');
      return [];
    }
  }}