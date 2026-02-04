import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:equisplit/repositories/expense_repository.dart';
import 'package:equisplit/repositories/user_repository.dart';
import 'package:equisplit/repositories/friends_repository.dart';
import 'package:equisplit/repositories/messaging_repository.dart';
import 'package:equisplit/services/image_storage_service.dart';
import 'package:equisplit/widgets/custom_loading_indicator.dart';
import 'dart:io';
import 'dart:async';
import 'dart:math';

class DashboardPage extends StatefulWidget {
  final Map<String, dynamic>? user;

  const DashboardPage({super.key, this.user});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  final _expenseRepo = ExpenseRepository();
  final _userRepo = UserRepository();
  late Future<List<Map<String, dynamic>>> _pendingProofsFuture;
  late Future<List<Map<String, dynamic>>> _paymentHistoryFuture;
  late ScrollController _scrollController;
  late TabController _tabController;
  bool _isScrolled = false;
  int _displayedPaymentHistoryCount = 4; // Show 4 items initially
  final int _paymentHistoryPageSize = 4; // Load 4 more items per click

  // List of funny Tagalog jokes
  final List<String> _funnyQuotes = [
    'Bakit single ka pa rin? "Nag-iimpok pa, mare. Ipon muna bago jowa!" 💰😂',
    'Teacher: "Bakit ka late?" Ako: "Traffic po sa bulsa, wala pong pamasahe!" 🚗💸',
    'Ano ginagawa mo pag may pera? "Screenshot para may evidence!" 📸💵',
    'Bakit ayaw mo mag-ML? "Kasi real life ko nga talo na, sa game pa kaya!" 🎮😭',
    'Pag may nag-message sa\'yo ng "Uy kumain ka na?" ang totoo: "May pautang ka?" 🍽️💰',
    'Kailan mo masasabi na adult ka na? Pag mas excited ka sa "SALE" kaysa "PARTY!" 🛍️🎉',
    'Ano sinasabi mo pag may nanghiram ng pera? "Penge na rin ako, hiram ko na din yan!" 😂',
    'Bakit ka nag-Grab? "Para feeling rich kahit 5 minutes lang!" 🚗✨',
    'Pag tinext ka ng "Nasa\'n ka?" ang ibig sabihin: "May libre ka ba?" 🤔💸',
    '"Send GCash na lang" - Ang national anthem ng Pilipinas! 🇵🇭💙',
    'Ano difference ng baby mo at wallet mo? "Yung baby tumatagal, wallet lumalaki yung tiyan!" 👶👛',
    'Bakit di ka pa nag-asawa? "Ayoko pa maging sponsor ng ibang tao!" 💍😅',
    'Pag birthday mo: "Libre mo ko, birthday mo eh!" Logic? WALA! 🎂🤷',
    'Sweldo day: Billionaire! 2 days later: "Pwede ba ako muna?" 💸📉',
    'Ano tawag sa pera mo pagkatapos ng 15? Alamano! Nawala na! 🤪',
    'May nakita akong meme: "Yung pera ko parang Pokemon, EVOLVE ng EVOLVE hanggang mawala!" ⚡💸',
    'Bakit ka nag-ML? "Para may feeling na may gold ako!" 🏆🎮',
    'Teacher: "Mag-ipon ka!" Me: "Sige po, mag-iipon ako ng utang!" 💰😭',
    'Pag may nagtanong "Libre mo ko?" sagutin mo: "Libre ako, pero di kita libre!" 🤣',
    'Budget for the month: "Sana all may budget!" 📊😅',
    'Yung friend mo: "Tara kain!" Ikaw: "Sagot mo?" Friend: "Oo, sagot mo!" 🍔😂',
    'Ano difference ng crush mo at pera mo? Pareho, di mo makuha! 💔💸',
    'Pag may message na "K": Yung K lang afford ko e! 😅',
    'Bakit ka nag-Shopee? "Para may checkout experience kahit walang pera!" 🛒😭',
    'Ano ginagawa mo sa Spotify? "Nag-ski-skip, kasi di afford Premium!" 🎵',
    'Pag tinanong ka "May pera ka?" sagot: "Meron, sa iba!" 💰🤷',
    'New Year\'s Resolution: "Mag-iimpok!" March: "Anong ipon?" 😂📅',
    'Bakit laging wala kang pera? "Kasi nag-invest ako sa kalungkutan!" 😭📉',
    'Motto ko sa buhay: "Bahala na si Lord at GCash!" 🙏💙',
    'Pag sinabing "May utang ako sa\'yo" ibig sabihin: "Historic debt yan pre!" 🏛️💸',
    'Ano tawag mo sa wallet mo? "Empty spaces" - One Direction! 🎵👛',
    'Sinong mas mabilis, Usain Bolt o pera mo? Pera mo! Wala na bigla! ⚡💸',
    'Bakit ka stressed? "Kasi kahit sa panaginip ko, nangungutang pa rin!" 😴💰',
    'Favorite mo sa Jollibee? "Yung wifi, libre!" 🍔📱',
    'Ano favorite quote mo? "Sana ol may pera!" - Shakespeare 🎭💸',
    'Pag nag-post ka ng food: "Salamat sa naglibre!" kahit ikaw bumili! 🍕😂',
    'Bakit ayaw mong mag-gym? "Kasi taba ng wallet ko yung problema, hindi ako!" 💪👛',
    'Pag may nag-DM: "Seen" kasi baka mangutang! 👀💬',
    'Netflix: "Are you still watching?" Ako: "Nakikitingin lang po, di afford!" 📺😅',
    'Ano favorite song ng wallet mo? "Wag Ka Nang Umiyak" kasi wala na! 🎵😭',
    'Pag birthday mo tapos libre ka: "Parang nag-invest ka tapos balik lang walang tubo!" 🎂📉',
    'Bakit di ka nag-aral? "Kasi mga mayaman naman ang nag-aaral ng Math, counting lang kami!" 🧮💸',
    'Crush: "Tara date!" Ako: "Sige, virtual na lang sa Zoom!" 💻❤️',
    'Ano superpower mo? "Makasurvive ng 1 week sa 100 pesos!" 🦸💯',
    'Yung binigay mong ulam sa office: "Konting share lang" sabay ½ ng lunchbox mo! 🍱😂',
    'Paano ka mag-save? "Screenshot ng pera!" 📸💵',
    'Why are you single? "Kasi mas committed ako sa utang ko!" 💔💰',
    'Bakit ka nag-TikTok? "Para feeling sikat kahit broke!" 📱✨',
    'Online shopping: "Add to cart" pero check out? NEVER! 🛒❌',
  ];

  late String _selectedQuote;
  int _unreadMessageCount = 0;
  int _pendingFriendRequestCount = 0;
  Timer? _notificationPollingTimer;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);
    // Use Random for better quote selection (less repetition)
    _selectedQuote = _funnyQuotes[Random().nextInt(_funnyQuotes.length)];
    WidgetsBinding.instance.addObserver(this);
    _refreshPendingProofs();
    _loadPaymentHistory();
    _loadNotificationCounts();
    // Polling disabled - badges only update on manual refresh
    // _startNotificationPolling();
  }

  void _startNotificationPolling() {
    _notificationPollingTimer = Timer.periodic(const Duration(seconds: 3), (timer) async {
      if (!mounted) {
        timer.cancel();
        return;
      }
      await _loadNotificationCounts();
    });
  }

  void _onScroll() {
    bool newScrollState = _scrollController.offset > 50;
    if (newScrollState != _isScrolled) {
      setState(() {
        _isScrolled = newScrollState;
      });
    }
  }

  @override
  void dispose() {
    _notificationPollingTimer?.cancel();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _tabController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Refresh when app comes back to foreground
      _refreshPendingProofs();
      _loadNotificationCounts();
    }
  }

  void _refreshPendingProofs() {
    final userId = widget.user?['user_id'] ?? 1;
    _pendingProofsFuture = _expenseRepo.getPendingProofsForUser(userId);
  }

  void _loadPaymentHistory() {
    final userId = widget.user?['user_id'] ?? 1;
    _paymentHistoryFuture = _expenseRepo.getApprovedUserTransactions(userId);
  }

  Future<void> _loadNotificationCounts() async {
    final userId = widget.user?['user_id'] ?? 1;
    try {
      final unreadCount = await MessagingRepository().getUnreadMessageCount(
        userId,
      );
      final friendRequestCount = await FriendsRepository()
          .getPendingRequestCount(userId);

      // Only update if counts actually changed
      if (mounted && (_unreadMessageCount != unreadCount || _pendingFriendRequestCount != friendRequestCount)) {
        setState(() {
          _unreadMessageCount = unreadCount;
          _pendingFriendRequestCount = friendRequestCount;
        });
      }
    } catch (e) {
      print('Error loading notification counts: $e');
    }
  }

  void _loadMorePaymentHistory() {
    setState(() {
      _displayedPaymentHistoryCount += _paymentHistoryPageSize;
    });
  }

  @override
  Widget build(BuildContext context) {
    final userId = widget.user?['user_id'] ?? 1;

    return PopScope(
      canPop: false,
      onPopInvoked: (bool didPop) async {
        if (didPop) return;
        
        final shouldExit = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            title: const Text(
              'Exit EquiSplit?',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            content: const Text(
              'Do you want to exit the app?',
              style: TextStyle(fontSize: 14),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text(
                  'No',
                  style: TextStyle(
                    color: Colors.grey,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1976D2),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                ),
                child: const Text(
                  'Yes',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ) ?? false;

        if (shouldExit && context.mounted) {
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          _refreshPendingProofs();
          await Future.delayed(const Duration(milliseconds: 500));
        },
        child: CustomScrollView(
          controller: _scrollController,
          slivers: [
            // Compact App Bar with Logo
            SliverAppBar(
              expandedHeight: 70,
              floating: false,
              pinned: true,
              backgroundColor: Colors.white,
              elevation: 2,
              automaticallyImplyLeading: false,
              title: _isScrolled
                  ? Text(
                      _selectedQuote,
                      style: const TextStyle(
                        color: Colors.grey,
                        fontSize: 13,
                        fontStyle: FontStyle.italic,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    )
                  : null,
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  decoration: const BoxDecoration(color: Colors.white),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 45,
                              height: 45,
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFF),
                                borderRadius: BorderRadius.circular(10),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.1),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.savings,
                                size: 28,
                                color: Color(0xFF1976D2),
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Text(
                              'EquiSplit',
                              style: TextStyle(
                                color: Color(0xFF1976D2),
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                PopupMenuButton(
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      child: const Row(
                        children: [
                          Icon(Icons.person),
                          SizedBox(width: 8),
                          Text('Profile'),
                        ],
                      ),
                      onTap: () {
                        Navigator.pushNamed(
                          context,
                          '/profile',
                          arguments: {
                            'user': widget.user,
                            'currentUser': widget.user,
                          },
                        );
                      },
                    ),
                    PopupMenuItem(
                      child: const Row(
                        children: [
                          Icon(Icons.settings),
                          SizedBox(width: 8),
                          Text('Settings'),
                        ],
                      ),
                      onTap: () {
                        Navigator.pushNamed(
                          context, 
                          '/settings',
                          arguments: widget.user,
                        );
                      },
                    ),
                    PopupMenuItem(
                      child: const Row(
                        children: [
                          Icon(Icons.logout),
                          SizedBox(width: 8),
                          Text('Logout'),
                        ],
                      ),
                      onTap: () {
                        Navigator.pushReplacementNamed(context, '/login');
                      },
                    ),
                    PopupMenuItem(
                      child: const Row(
                        children: [
                          Icon(Icons.bug_report),
                          SizedBox(width: 8),
                          Text('Debug Info'),
                        ],
                      ),
                      onTap: () {
                        Navigator.pushNamed(context, '/debug');
                      },
                    ),
                  ],
                ),
              ],
            ),

            // Horizontally Scrollable People List
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 0,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'People',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[800],
                            ),
                          ),
                          Row(
                            children: [
                              TextButton.icon(
                                icon: _buildNotificationBadge(
                                  const Icon(Icons.message, size: 18),
                                  _unreadMessageCount,
                                ),
                                label: const Text('Messages'),
                                onPressed: () {
                                  Navigator.pushNamed(
                                    context,
                                    '/messages',
                                    arguments: widget.user,
                                  ).then((_) => _loadNotificationCounts());
                                },
                                style: TextButton.styleFrom(
                                  foregroundColor: const Color(0xFF1976D2),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                  ),
                                ),
                              ),
                              TextButton.icon(
                                icon: _buildNotificationBadge(
                                  const Icon(Icons.people, size: 18),
                                  _pendingFriendRequestCount,
                                ),
                                label: const Text('Friends'),
                                onPressed: () {
                                  Navigator.pushNamed(
                                    context,
                                    '/users',
                                    arguments: widget.user,
                                  ).then((_) => _loadNotificationCounts());
                                },
                                style: TextButton.styleFrom(
                                  foregroundColor: const Color(0xFF1976D2),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 110,
                      child: FutureBuilder<List<Map<String, dynamic>>>(
                        future: FriendsRepository().getMutualFriends(userId),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return Center(
                              child: CustomLoadingIndicator(),
                            );
                          }

                          if (!snapshot.hasData || snapshot.data!.isEmpty) {
                            return Center(
                              child: Text(
                                'No friends yet',
                                style: TextStyle(color: Colors.grey[600]),
                              ),
                            );
                          }

                          final users = snapshot.data!;

                          return ListView.builder(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: users.length,
                            itemBuilder: (context, index) {
                              final user = users[index];
                              final userName = user['name'] ?? 'User';
                              final avatarPath = user['avatar_path'] as String?;

                              return GestureDetector(
                                onTap: () {
                                  // Pass currentUser so ProfilePage knows if it's own profile
                                  Navigator.pushNamed(
                                    context,
                                    '/profile',
                                    arguments: {
                                      'user': user,
                                      'currentUser': widget.user,
                                    },
                                  );
                                },
                                child: Padding(
                                  padding: const EdgeInsets.only(right: 12),
                                  child: Column(
                                    children: [
                                      Container(
                                        width: 80,
                                        height: 80,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: Colors.grey[300],
                                          border: Border.all(
                                            color: const Color(0xFF1976D2),
                                            width: 2.5,
                                          ),
                                          image:
                                              avatarPath != null &&
                                                  avatarPath.isNotEmpty
                                              ? DecorationImage(
                                                  image:
                                                      avatarPath.startsWith(
                                                        '/uploads/',
                                                      )
                                                      ? NetworkImage(
                                                          ImageStorageService.getImageUrl(
                                                            avatarPath,
                                                          ),
                                                        )
                                                      : FileImage(
                                                          File(avatarPath),
                                                        ),
                                                  fit: BoxFit.cover,
                                                )
                                              : null,
                                        ),
                                        child:
                                            avatarPath == null ||
                                                avatarPath.isEmpty
                                            ? Icon(
                                                Icons.person,
                                                color: Colors.grey[600],
                                                size: 36,
                                              )
                                            : null,
                                      ),
                                      const SizedBox(height: 6),
                                      SizedBox(
                                        width: 90,
                                        child: Text(
                                          userName,
                                          textAlign: TextAlign.center,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Content
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Total Expenses Section
                    const Text(
                      'Expenses',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 16),
                    FutureBuilder<List<Map<String, dynamic>>>(
                      future: _expenseRepo.getAllUserTransactions(userId),
                      builder: (context, snapshot) {
                        double owesMe = 0;
                        double iOwe = 0;
                        double paidToMe = 0;
                        double iPaid = 0;
                        double netAmount = 0;
                        bool isPositive = false;

                        if (snapshot.hasData && snapshot.data != null) {
                          for (var transaction in snapshot.data!) {
                            final payerId = transaction['payer_id'] as int;
                            final payeeId = transaction['payee_id'] as int;
                            final amount = (transaction['amount'] as num)
                                .toDouble();
                            final isProofApproved =
                                (transaction['is_proof_approved'] as int?) ?? 0;
                            final isTransactionPaid =
                                (transaction['is_transaction_paid'] as int?) ??
                                0;
                            final isPaid =
                                isProofApproved == 1 || isTransactionPaid == 1;

                            if (payeeId == userId) {
                              // Someone owes me money
                              owesMe += amount;
                              // Subtract if already paid or approved
                              if (isPaid) {
                                paidToMe += amount;
                              }
                            }
                            if (payerId == userId) {
                              // I owe someone money
                              iOwe += amount;
                              // Subtract if already paid or approved
                              if (isPaid) {
                                iPaid += amount;
                              }
                            }
                          }

                          // Calculate remaining amounts (after deducting paid)
                          final remainingOwedToMe = owesMe - paidToMe;
                          final remainingIOwe = iOwe - iPaid;

                          // Calculate net amount based on remaining
                          if (remainingOwedToMe >= remainingIOwe) {
                            netAmount = remainingOwedToMe - remainingIOwe;
                            isPositive = true;
                          } else {
                            netAmount = remainingIOwe - remainingOwedToMe;
                            isPositive = false;
                          }
                        }

                        return GestureDetector(
                          onTap: () {
                            _showDebtSummary(userId);
                          },
                          child: Card(
                            elevation: 6,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: netAmount > 0.01 && isPositive
                                      ? [
                                          const Color(0xFF1976D2),
                                          const Color(0xFF0288D1),
                                        ]
                                      : netAmount > 0.01 && !isPositive
                                      ? [
                                          const Color(0xFFD32F2F),
                                          const Color(0xFFC62828),
                                        ]
                                      : [
                                          const Color(0xFF4CAF50),
                                          const Color(0xFF388E3C),
                                        ],
                                ),
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: netAmount > 0.01 && isPositive
                                        ? const Color(
                                            0xFF1976D2,
                                          ).withValues(alpha: 0.3)
                                        : netAmount > 0.01 && !isPositive
                                        ? const Color(
                                            0xFFD32F2F,
                                          ).withValues(alpha: 0.3)
                                        : const Color(
                                            0xFF4CAF50,
                                          ).withValues(alpha: 0.3),
                                    blurRadius: 12,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                              ),
                              padding: const EdgeInsets.all(20.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        netAmount.abs() < 0.01
                                            ? 'Settlement Status'
                                            : 'Settlement Balance',
                                        style: const TextStyle(
                                          color: Colors.white70,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withValues(
                                            alpha: 0.2,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
                                        ),
                                        child: Text(
                                          netAmount.abs() < 0.01
                                              ? '✓ Settled'
                                              : (netAmount > 0
                                                    ? 'Receive'
                                                    : 'Pay'),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    '₱${netAmount.abs().toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 40,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  // Two-column breakdown
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Remaining to Receive',
                                              style: TextStyle(
                                                color: Colors.white.withValues(
                                                  alpha: 0.7,
                                                ),
                                                fontSize: 12,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              '₱${(owesMe - paidToMe).toStringAsFixed(2)}',
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Container(
                                        width: 1,
                                        height: 40,
                                        color: Colors.white.withValues(
                                          alpha: 0.3,
                                        ),
                                      ),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.end,
                                          children: [
                                            Text(
                                              'Remaining to Pay',
                                              style: TextStyle(
                                                color: Colors.white.withValues(
                                                  alpha: 0.7,
                                                ),
                                                fontSize: 12,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              '₱${(iOwe - iPaid).toStringAsFixed(2)}',
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 18,
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
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 32),

                    // Tabs for Payment History and Pending Approvals
                    Material(
                      color: Colors.white,
                      child: TabBar(
                        controller: _tabController,
                        labelColor: const Color(0xFF1976D2),
                        unselectedLabelColor: Colors.grey,
                        indicatorColor: const Color(0xFF1976D2),
                        indicatorWeight: 3,
                        tabs: const [
                          Tab(text: 'Pending Approvals'),
                          Tab(text: 'Payment History'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 280,
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          // Pending Approvals Tab
                          _buildPendingApprovalsTab(),
                          // Payment History Tab
                          _buildPaymentHistoryTab(),
                        ],
                      ),
                    ),
                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 16.0),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(50),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF1976D2).withOpacity(0.4),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: FloatingActionButton.extended(
            onPressed: () {
              Navigator.pushNamed(
                context,
                '/create-expense',
                arguments: widget.user,
              );
            },
            backgroundColor: const Color(0xFF1976D2),
            elevation: 0,
            foregroundColor: Colors.white,
            icon: const Icon(Icons.add_circle, size: 28),
            label: const Text(
              'New Expense',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      ),
    );
  }

  Widget _buildPendingApprovalsTab() {
    return RefreshIndicator(
      onRefresh: () async {
        _refreshPendingProofs();
        await Future.delayed(const Duration(milliseconds: 500));
      },
      child: FutureBuilder<List<Map<String, dynamic>>>(
        future: _pendingProofsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CustomLoadingIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.done_all, size: 64, color: Colors.grey.shade300),
                  const SizedBox(height: 12),
                  const Text(
                    'No pending approvals',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          final proofs = snapshot.data!;
          return Padding(
            padding: const EdgeInsets.only(bottom: 20.0),
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              shrinkWrap: true,
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: proofs.length,
              itemBuilder: (context, index) {
                final proof = proofs[index];
                return _buildProofCard(proof);
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildPaymentHistoryTab() {
    final userId = widget.user?['user_id'] ?? 0;
    print('🔍 Building payment history for user_id: $userId');
    
    return RefreshIndicator(
      onRefresh: () async {
        setState(() {
          _displayedPaymentHistoryCount = 4; // Reset to initial count
          _paymentHistoryFuture = _expenseRepo.getApprovedUserTransactions(userId);
        });
        await Future.delayed(const Duration(milliseconds: 500));
      },
      child: FutureBuilder<List<Map<String, dynamic>>>(
        future: _paymentHistoryFuture,
        builder: (context, snapshot) {
          print('📊 Payment history state: ${snapshot.connectionState}');
          print('📊 Has data: ${snapshot.hasData}');
          print('📊 Data length: ${snapshot.data?.length ?? 0}');
          
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CustomLoadingIndicator());
          }

          if (snapshot.hasError) {
            print('❌ Payment history error: ${snapshot.error}');
            return Center(
              child: Text('Error: ${snapshot.error}'),
            );
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.check_circle_outline,
                    size: 64,
                    color: Colors.grey.shade300,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'No payment history yet',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          final allTransactions = snapshot.data!;
          final displayedTransactions = allTransactions
              .take(_displayedPaymentHistoryCount)
              .toList();
          final hasMoreItems =
              allTransactions.length > _displayedPaymentHistoryCount;

          return SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.only(bottom: 20.0),
              child: Column(
                children: [
                  ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: displayedTransactions.length,
                    itemBuilder: (context, index) {
                      final transaction = displayedTransactions[index];
                      return _buildTransactionCard(transaction);
                    },
                  ),
                  if (hasMoreItems)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16.0),
                      child: ElevatedButton(
                        onPressed: _loadMorePaymentHistory,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          elevation: 0,
                          side: const BorderSide(color: Color(0xFF1976D2)),
                        ),
                        child: const Text(
                          'Load More',
                          style: TextStyle(
                            color: Color(0xFF1976D2),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildProofCard(Map<String, dynamic> proof) {
    final payerName = proof['payer_name'] ?? 'Unknown';
    final expenseName = proof['expense_name'] ?? 'Payment';
    final amount = (proof['amount'] as num).toDouble();
    final proofId = proof['proof_id'] as int;
    final imagePath = proof['image_path'] as String;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        expenseName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      Text(
                        'From: $payerName',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '₱${amount.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.orange,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: () =>
                  _showProofDetails(proofId, payerName, amount, imagePath),
              icon: const Icon(Icons.image, size: 18),
              label: const Text('View & Approve'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionCard(Map<String, dynamic> transaction) {
    final amount = (transaction['amount'] as num).toDouble();
    final payerId = transaction['payer_id'] as int;
    final payeeId = transaction['payee_id'] as int;
    final currentUserId = widget.user?['user_id'] as int? ?? 0;
    final payerName = transaction['payer_name'] ?? 'Unknown';
    final payeeName = transaction['payee_name'] ?? 'Unknown';
    final expenseName = transaction['expense_name'] ?? 'Payment';
    final isPaid = transaction['status'] == 'paid';
    final isProofApproved = (transaction['is_proof_approved'] as int?) ?? 0;

    // Determine if this is a payment sent or received
    final isSent = payerId == currentUserId;
    final personName = isSent ? payeeName : payerName;
    final actionText = isSent ? 'To' : 'From';
    final iconColor = isPaid || isProofApproved == 1
        ? Colors.green
        : Colors.orange;
    final statusText = isPaid || isProofApproved == 1 ? 'Paid' : 'Pending';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          children: [
            Container(
              width: 45,
              height: 45,
              decoration: BoxDecoration(
                color: iconColor,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Icon(
                  isSent ? Icons.arrow_upward : Icons.arrow_downward,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    expenseName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  Text(
                    '$actionText: $personName',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  Text(
                    isSent ? 'Payment Sent' : 'Payment Received',
                    style: TextStyle(
                      fontSize: 10,
                      color: isSent ? Colors.red : Colors.green,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '₱${amount.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: iconColor,
                  ),
                ),
                Text(
                  statusText,
                  style: TextStyle(
                    fontSize: 11,
                    color: iconColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showDebtSummary(int userId) async {
    Navigator.pushNamed(context, '/expenses', arguments: widget.user);
  }

  void _showProofDetails(
    int proofId,
    String payerName,
    double amount,
    String imagePath,
  ) {
    final isServerPath = imagePath.startsWith('/uploads/');
    final imageUrl = isServerPath
        ? ImageStorageService.getImageUrl(imagePath)
        : null;
    final imageFile = isServerPath ? null : File(imagePath);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Proof of Payment - $payerName'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange[300]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Amount',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.orange,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '₱${amount.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.orange,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text('Proof of Payment:'),
              const SizedBox(height: 8),
              if (isServerPath && imageUrl != null)
                Image.network(
                  imageUrl,
                  width: 300,
                  height: 300,
                  fit: BoxFit.cover,
                )
              else if (!isServerPath && imageFile != null)
                Image.file(
                  imageFile,
                  width: 300,
                  height: 300,
                  fit: BoxFit.cover,
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
            onPressed: () async {
              Navigator.pop(context);
              await _approveProofOfPayment(proofId);
            },
            icon: const Icon(Icons.done),
            label: const Text('Approve'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  void _viewAndApproveProof(Map<String, dynamic> proof, String imagePath) {
    final payerName = proof['payer_name'] ?? 'Unknown';
    final amount = (proof['amount'] as num).toDouble();
    final proofId = proof['proof_id'] as int;
    final imageUrl = ImageStorageService.getImageUrl(imagePath);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Approve Payment from $payerName'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange[300]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Amount',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.orange,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '₱${amount.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.orange,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text('Proof of Payment:'),
              const SizedBox(height: 8),
              Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Container(
                      color: Colors.grey[100],
                      child: Center(child: CustomLoadingIndicator(size: 30)),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.image_not_supported,
                            size: 50,
                            color: Colors.grey,
                          ),
                          const SizedBox(height: 8),
                          Text('Failed to load\n$imageUrl'),
                        ],
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
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.pop(context);
              await _approveProofOfPayment(proofId);
            },
            icon: const Icon(Icons.done),
            label: const Text('Approve'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _approveProofOfPayment(int proofId) async {
    try {
      final currentUserId = widget.user?['user_id'] as int?;
      if (currentUserId == null) return;

      final success = await _expenseRepo.approveProofOfPayment(
        proofId: proofId,
        approvedBy: currentUserId,
      );

      if (success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Payment approved!'),
              backgroundColor: Colors.green,
            ),
          );
          // Refresh the pending proofs list
          _refreshPendingProofs();
          setState(() {});
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  void _showPaymentQRCodes(int userId, String userName) async {
    try {
      final qrCodes = await _expenseRepo.getUserQRCodes(userId);

      if (!mounted) return;

      if (qrCodes.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No QR codes available for this user'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(
            'Payment Method - $userName',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Color(0xFF0288D1),
            ),
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: qrCodes.map((qrCode) {
                  final imagePath = qrCode['image_path'] as String;
                  final label = qrCode['label'] as String;
                  final isServerPath = imagePath.startsWith('/uploads/');
                  final imageUrl = isServerPath
                      ? ImageStorageService.getImageUrl(imagePath)
                      : null;
                  final imageFile = isServerPath ? null : File(imagePath);

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          label,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: Color(0xFF212121),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Center(
                          child: isServerPath
                              ? Container(
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: Colors.grey.shade300,
                                      width: 2,
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Image.network(
                                    imageUrl!,
                                    width: 200,
                                    height: 200,
                                    fit: BoxFit.cover,
                                    loadingBuilder: (context, child, loadingProgress) {
                                      if (loadingProgress == null) return child;
                                      return SizedBox(
                                        width: 200,
                                        height: 200,
                                        child: Center(
                                          child: CircularProgressIndicator(
                                            value:
                                                loadingProgress
                                                        .expectedTotalBytes !=
                                                    null
                                                ? loadingProgress
                                                          .cumulativeBytesLoaded /
                                                      loadingProgress
                                                          .expectedTotalBytes!
                                                : null,
                                          ),
                                        ),
                                      );
                                    },
                                    errorBuilder: (context, error, stackTrace) {
                                      print('❌ Dashboard QR error: $error');
                                      print('🔗 URL: $imageUrl');
                                      return Container(
                                        width: 200,
                                        height: 200,
                                        decoration: BoxDecoration(
                                          color: Colors.grey.shade100,
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: Center(
                                          child: Column(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              const Icon(
                                                Icons.error,
                                                color: Colors.red,
                                              ),
                                              const SizedBox(height: 4),
                                              const Text(
                                                'QR Code failed to load',
                                                style: TextStyle(fontSize: 10),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                )
                              : FutureBuilder<bool>(
                                  future: imageFile!.exists(),
                                  builder: (context, snapshot) {
                                    if (snapshot.connectionState ==
                                        ConnectionState.waiting) {
                                      return SizedBox(
                                        width: 200,
                                        height: 200,
                                        child: Center(
                                          child: CustomLoadingIndicator(),
                                        ),
                                      );
                                    }

                                    if (snapshot.hasData &&
                                        snapshot.data == true) {
                                      return Container(
                                        decoration: BoxDecoration(
                                          border: Border.all(
                                            color: Colors.grey.shade300,
                                            width: 2,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: Image.file(
                                          imageFile,
                                          width: 200,
                                          height: 200,
                                          fit: BoxFit.cover,
                                        ),
                                      );
                                    }

                                    return Container(
                                      width: 200,
                                      height: 200,
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade100,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Center(
                                        child: Text('QR Code not found'),
                                      ),
                                    );
                                  },
                                ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Close',
                style: TextStyle(color: Color(0xFF0288D1)),
              ),
            ),
          ],
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error loading QR codes: $e')));
    }
  }

  Widget _buildNotificationBadge(Widget child, int count) {
    if (count == 0) return child;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        child,
        Positioned(
          right: -8,
          top: -8,
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.red,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 1.5),
            ),
            constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
            child: Text(
              count > 99 ? '99+' : count.toString(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ],
    );
  }
}
