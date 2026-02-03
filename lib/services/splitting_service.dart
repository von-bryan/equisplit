/// Split expense calculation service
/// Calculates who owes whom and minimizes transactions
library;

class Transaction {
  String from;
  String to;
  double amount;

  Transaction({
    required this.from,
    required this.to,
    required this.amount,
  });

  @override
  String toString() => '$from pays $to: ₱${amount.toStringAsFixed(2)}';
}

class SplittingService {
  /// Calculate optimal transactions for expense splitting
  /// 
  /// Example:
  /// users: ['chaimae', 'abel', 'shine', 'ara', 'nathan', 'janno']
  /// contributions: {'chaimae': 1500, 'abel': 700, 'shine': 3800, ...}
  /// totalExpense: 6000
  /// 
  /// Returns: List of optimal transactions
  static List<Transaction> calculateOptimalTransactions(
    List<String> users,
    Map<String, double> contributions,
    double totalExpense,
  ) {
    // Calculate how much each person should pay (equal split)
    double perPersonShare = totalExpense / users.length;

    // Calculate balance for each person (negative = owes, positive = is owed)
    Map<String, double> balances = {};
    for (String user in users) {
      double contributed = contributions[user] ?? 0;
      balances[user] = contributed - perPersonShare;
    }

    // Remove people with zero balance
    balances.removeWhere((key, value) => value.abs() < 0.01);

    List<Transaction> transactions = [];

    // Greedily match debtors with creditors
    while (balances.isNotEmpty) {
      // Find person who owes the most
      String debtor = balances.keys.reduce((a, b) =>
          balances[a]! < balances[b]! ? a : b);
      double debtAmount = balances[debtor]!.abs();

      // Find person who is owed the most
      String creditor = balances.keys.reduce((a, b) =>
          balances[a]! > balances[b]! ? a : b);
      double creditAmount = balances[creditor]!;

      // Calculate transaction amount
      double transactionAmount = [debtAmount, creditAmount].reduce(
        (a, b) => a < b ? a : b,
      );

      // Add transaction
      transactions.add(
        Transaction(
          from: debtor,
          to: creditor,
          amount: transactionAmount,
        ),
      );

      // Update balances
      balances[debtor] = balances[debtor]! + transactionAmount;
      balances[creditor] = balances[creditor]! - transactionAmount;

      // Remove settled balances
      balances.removeWhere((key, value) => value.abs() < 0.01);
    }

    return transactions;
  }

  /// Calculate transactions based on expense type
  /// Types:
  /// - 'evenly': Split equally among all participants
  /// - 'borrowed': Only borrower pays back (typically person with 0 contribution)
  /// - 'partial': Only non-contributors pay (those who contributed 0)
  static List<Transaction> calculateTransactionsByType(
    List<String> users,
    Map<String, double> contributions,
    double totalExpense,
    String expenseType,
  ) {
    switch (expenseType.toLowerCase()) {
      case 'borrowed':
        return _calculateBorrowedExpenses(users, contributions, totalExpense);
      case 'partial':
        return _calculateNonContributorExpenses(users, contributions, totalExpense);
      case 'evenly':
      default:
        return calculateOptimalTransactions(users, contributions, totalExpense);
    }
  }

  /// For Borrowed Money type:
  /// Only the person who didn't contribute (borrowed) pays back
  /// Useful for: "I paid for something, you owe me back"
  static List<Transaction> _calculateBorrowedExpenses(
    List<String> users,
    Map<String, double> contributions,
    double totalExpense,
  ) {
    List<Transaction> transactions = [];
    
    // Find who paid (contributed)
    String? payer;
    String? borrower;
    
    for (String user in users) {
      double contributed = contributions[user] ?? 0;
      if (contributed > 0 && payer == null) {
        payer = user;
      } else if (contributed == 0 && borrower == null) {
        borrower = user;
      }
    }
    
    // If we have a payer and borrower, borrower pays back the total
    if (payer != null && borrower != null) {
      transactions.add(
        Transaction(
          from: borrower,
          to: payer,
          amount: totalExpense,
        ),
      );
    }
    
    return transactions;
  }

  /// For Non-Contributors Pay type:
  /// Only those who didn't contribute anything split the total equally
  /// Useful for: "Those who didn't contribute should pay"
  static List<Transaction> _calculateNonContributorExpenses(
    List<String> users,
    Map<String, double> contributions,
    double totalExpense,
  ) {
    List<Transaction> transactions = [];
    
    // Find non-contributors
    List<String> nonContributors = [];
    String? mainPayer;
    double mainPayerAmount = 0;
    
    for (String user in users) {
      double contributed = contributions[user] ?? 0;
      if (contributed == 0) {
        nonContributors.add(user);
      } else if (contributed > mainPayerAmount) {
        mainPayerAmount = contributed;
        mainPayer = user;
      }
    }
    
    // If there are non-contributors, split total equally among them
    if (nonContributors.isNotEmpty && mainPayer != null) {
      double amountPerNonContributor = totalExpense / nonContributors.length;
      
      for (String nonContributor in nonContributors) {
        transactions.add(
          Transaction(
            from: nonContributor,
            to: mainPayer,
            amount: amountPerNonContributor,
          ),
        );
      }
    }
    
    return transactions;
  }

  /// Example usage for your grocery scenario
  static List<Transaction> calculateGroceryExpenses() {
    List<String> users = ['chaimae', 'able', 'shine', 'ara', 'nathan', 'janno'];
    
    Map<String, double> contributions = {
      'chaimae': 1500,
      'able': 700,
      'shine': 3800,
      'ara': 0,
      'nathan': 0,
      'janno': 0,
    };

    double totalExpense = 6000;

    return calculateOptimalTransactions(users, contributions, totalExpense);
  }
}
