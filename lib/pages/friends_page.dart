import 'package:flutter/material.dart';
import 'package:equisplit/repositories/friends_repository.dart';
import 'package:equisplit/widgets/custom_loading_indicator.dart';

class FriendsPage extends StatefulWidget {
  final Map<String, dynamic>? currentUser;

  const FriendsPage({super.key, this.currentUser});

  @override
  State<FriendsPage> createState() => _FriendsPageState();
}

class _FriendsPageState extends State<FriendsPage>
    with SingleTickerProviderStateMixin {
  final _friendsRepo = FriendsRepository();
  final _searchController = TextEditingController();
  late TabController _tabController;

  List<Map<String, dynamic>> _searchResults = [];
  List<Map<String, dynamic>> _suggestedFriends = [];
  List<Map<String, dynamic>> _pendingRequests = [];
  List<Map<String, dynamic>> _myFriends = [];

  bool _isSearching = false;
  bool _isLoadingPending = false;
  bool _isLoadingFriends = false;

  int? _currentUserId;
  final Set<int> _animatingOut = {}; // Track items being animated out

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _currentUserId = widget.currentUser?['user_id'] as int?;
    _loadInitialData();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    if (_currentUserId == null) return;

    _loadPendingRequests();
    _loadMyFriends();
    _loadSuggestedFriends();
  }

  Future<void> _loadPendingRequests() async {
    if (_currentUserId == null) return;
    setState(() => _isLoadingPending = true);

    final requests = await _friendsRepo.getPendingRequests(_currentUserId!);
    setState(() {
      _pendingRequests = requests;
      _isLoadingPending = false;
    });
  }

  Future<void> _loadMyFriends() async {
    if (_currentUserId == null) return;
    setState(() => _isLoadingFriends = true);

    final friends = await _friendsRepo.getMutualFriends(_currentUserId!);
    setState(() {
      _myFriends = friends;
      _isLoadingFriends = false;
    });
  }

  Future<void> _loadSuggestedFriends() async {
    if (_currentUserId == null) return;

    final suggested = await _friendsRepo.getSuggestedFriends(_currentUserId!);
    setState(() {
      _suggestedFriends = suggested;
    });
  }

  Future<void> _onSearchChanged() async {
    if (_currentUserId == null) return;

    final query = _searchController.text.trim();
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    setState(() => _isSearching = true);

    final results = await _friendsRepo.searchUsers(query, _currentUserId!);
    setState(() {
      _searchResults = results;
      _isSearching = false;
    });
  }

  Future<void> _sendFriendRequest(int receiverId) async {
    if (_currentUserId == null) return;

    final success = await _friendsRepo.sendFriendRequest(
      _currentUserId!,
      receiverId,
    );
    if (success && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('✅ Friend request sent')));
      _onSearchChanged(); // Refresh search results
      _loadSuggestedFriends(); // Refresh suggestions
    }
  }

  Future<void> _acceptRequest(int requestId, int friendId) async {
    // Mark as animating out
    setState(() {
      _animatingOut.add(requestId);
    });

    // Wait for animation to complete
    await Future.delayed(const Duration(milliseconds: 300));

    final success = await _friendsRepo.acceptFriendRequest(requestId);
    if (success && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('✅ Friend added')));

      // Remove from animating set
      _animatingOut.remove(requestId);

      _loadPendingRequests();
      _loadMyFriends();
      _loadSuggestedFriends();
    } else if (mounted) {
      // Remove from animating set if failed
      setState(() {
        _animatingOut.remove(requestId);
      });
    }
  }

  Future<void> _rejectRequest(int requestId) async {
    // Mark as animating out
    setState(() {
      _animatingOut.add(requestId);
    });

    // Wait for animation to complete
    await Future.delayed(const Duration(milliseconds: 300));

    final success = await _friendsRepo.rejectFriendRequest(requestId);
    if (success && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('✅ Request rejected')));

      // Remove from animating set
      _animatingOut.remove(requestId);

      _loadPendingRequests();
    } else if (mounted) {
      // Remove from animating set if failed
      setState(() {
        _animatingOut.remove(requestId);
      });
    }
  }

  Future<void> _removeFriend(int friendId) async {
    if (_currentUserId == null) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Friend?'),
        content: const Text('Are you sure you want to remove this friend?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              final success = await _friendsRepo.removeFriend(
                _currentUserId!,
                friendId,
              );
              if (success && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('✅ Friend removed')),
                );
                _loadMyFriends();
                _loadSuggestedFriends();
              }
            },
            child: const Text('Remove', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Widget _buildUserCard({
    required Map<String, dynamic> user,
    required String status,
    VoidCallback? onPrimaryAction,
    VoidCallback? onSecondaryAction,
    String? primaryButtonText,
    String? secondaryButtonText,
  }) {
    final avatarPath = user['avatar_path'] as String?;
    final name = user['name'] as String? ?? 'Unknown';
    final username = user['username'] as String? ?? '';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // Avatar
            CircleAvatar(
              radius: 28,
              backgroundImage: avatarPath != null && avatarPath.isNotEmpty
                  ? NetworkImage(avatarPath)
                  : null,
              child: avatarPath == null || avatarPath.isEmpty
                  ? const Icon(Icons.person, size: 28)
                  : null,
            ),
            const SizedBox(width: 12),
            // User info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  if (username.isNotEmpty)
                    Text(
                      '@$username',
                      style: const TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                  if (status == 'friend')
                    const Padding(
                      padding: EdgeInsets.only(top: 4),
                      child: Text(
                        'Friend',
                        style: TextStyle(
                          color: Colors.green,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            // Action buttons
            if (onPrimaryAction != null && primaryButtonText != null) ...[
              const SizedBox(width: 8),
              SizedBox(
                height: 36,
                child: ElevatedButton(
                  onPressed: onPrimaryAction,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: status == 'friend'
                        ? Colors.grey
                        : Colors.blue,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                  child: Text(
                    primaryButtonText,
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ),
            ],
            if (onSecondaryAction != null && secondaryButtonText != null) ...[
              const SizedBox(width: 8),
              SizedBox(
                height: 36,
                child: ElevatedButton(
                  onPressed: onSecondaryAction,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red[300],
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                  child: Text(
                    secondaryButtonText,
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Friends'),
          backgroundColor: const Color(0xFF424242),
          bottom: TabBar(
            controller: _tabController,
            tabs: [
              Tab(
                text: _pendingRequests.isEmpty
                    ? 'Requests'
                    : 'Requests (${_pendingRequests.length})',
              ),
              const Tab(text: 'My Friends'),
              const Tab(text: 'Find Friends'),
            ],
          ),
        ),
        body: TabBarView(
          controller: _tabController,
          children: [
            // Pending Requests Tab
            _isLoadingPending
                ? Center(child: CustomLoadingIndicator())
                : _pendingRequests.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.person_add_alt_1,
                          size: 48,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No pending requests',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: _pendingRequests.length,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemBuilder: (context, index) {
                      final request = _pendingRequests[index];
                      final userId = request['user_id'] as int?;
                      final requestId = request['id'] as int;
                      final isAnimatingOut = _animatingOut.contains(requestId);

                      return AnimatedOpacity(
                        opacity: isAnimatingOut ? 0.0 : 1.0,
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOut,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeOut,
                          height: isAnimatingOut ? 0 : null,
                          child: AnimatedSlide(
                            offset: isAnimatingOut
                                ? const Offset(1.0, 0.0)
                                : Offset.zero,
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeOut,
                            child: _buildUserCard(
                              user: request,
                              status: 'pending',
                              primaryButtonText: 'Accept',
                              secondaryButtonText: 'Decline',
                              onPrimaryAction: userId != null && !isAnimatingOut
                                  ? () => _acceptRequest(requestId, userId)
                                  : null,
                              onSecondaryAction: !isAnimatingOut
                                  ? () => _rejectRequest(requestId)
                                  : null,
                            ),
                          ),
                        ),
                      );
                    },
                  ),

            // My Friends Tab
            _isLoadingFriends
                ? Center(child: CustomLoadingIndicator())
                : _myFriends.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.people_outline,
                          size: 48,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No friends yet',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: _myFriends.length,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemBuilder: (context, index) {
                      final friend = _myFriends[index];
                      final friendId = friend['user_id'] as int?;
                      return _buildUserCard(
                        user: friend,
                        status: 'friend',
                        primaryButtonText: 'Remove',
                        onPrimaryAction: friendId != null
                            ? () => _removeFriend(friendId)
                            : null,
                      );
                    },
                  ),

            // Find Friends Tab
            Column(
              children: [
                // Search bar
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search by name or username',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: 12,
                        horizontal: 16,
                      ),
                    ),
                  ),
                ),
                // Search results or suggestions
                Expanded(
                  child: _searchController.text.isEmpty
                      ? _buildSuggestionsView()
                      : _buildSearchResultsView(),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuggestionsView() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Suggested Friends',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
          if (_suggestedFriends.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  'No suggestions available',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ),
            )
          else
            ListView.builder(
              itemCount: _suggestedFriends.length,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemBuilder: (context, index) {
                final friend = _suggestedFriends[index];
                final userId = friend['user_id'] as int?;
                return _buildUserCard(
                  user: friend,
                  status: 'suggested',
                  primaryButtonText: 'Add',
                  onPrimaryAction: userId != null
                      ? () => _sendFriendRequest(userId)
                      : null,
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildSearchResultsView() {
    return _isSearching
        ? Center(child: CustomLoadingIndicator())
        : _searchResults.isEmpty
        ? Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Text(
                'No users found',
                style: TextStyle(color: Colors.grey[600]),
              ),
            ),
          )
        : ListView.builder(
            itemCount: _searchResults.length,
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemBuilder: (context, index) {
              final user = _searchResults[index];
              final status = user['friend_status'] as String? ?? 'none';
              final userId = user['user_id'] as int?;

              String buttonText = 'Add';
              if (status == 'friend') {
                buttonText = 'Remove';
              } else if (status == 'request_sent') {
                buttonText = 'Pending';
              } else if (status == 'request_pending') {
                buttonText = 'Respond';
              }

              VoidCallback? onAction;
              if (userId != null) {
                if (status == 'friend') {
                  onAction = () => _removeFriend(userId);
                } else if (status == 'none') {
                  onAction = () => _sendFriendRequest(userId);
                }
              }

              return _buildUserCard(
                user: user,
                status: status,
                primaryButtonText: buttonText,
                onPrimaryAction: status == 'request_sent' ? null : onAction,
              );
            },
          );
  }
}
