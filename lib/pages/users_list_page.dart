import 'package:flutter/material.dart';
import 'package:equisplit/repositories/friends_repository.dart';
import 'package:equisplit/services/image_storage_service.dart';

class UsersListPage extends StatefulWidget {
  final Map<String, dynamic>? currentUser;

  const UsersListPage({super.key, this.currentUser});

  @override
  State<UsersListPage> createState() => _UsersListPageState();
}

class _UsersListPageState extends State<UsersListPage> with SingleTickerProviderStateMixin {
  final _friendsRepo = FriendsRepository();
  final _searchController = TextEditingController();
  late TabController _tabController;

  List<Map<String, dynamic>> _searchResults = [];
  List<Map<String, dynamic>> _suggestedFriends = [];
  List<Map<String, dynamic>> _pendingRequests = [];
  List<Map<String, dynamic>> _myFriends = [];
  
  bool _isSearching = false;
  bool _isLoadingSuggestions = false;
  bool _isLoadingPending = false;
  bool _isLoadingFriends = false;

  int? _currentUserId;

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
    setState(() => _isLoadingSuggestions = true);

    final suggested = await _friendsRepo.getSuggestedFriends(_currentUserId!);
    setState(() {
      _suggestedFriends = suggested;
      _isLoadingSuggestions = false;
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

    final success =
        await _friendsRepo.sendFriendRequest(_currentUserId!, receiverId);
    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Friend request sent')),
      );
      _onSearchChanged();
      _loadSuggestedFriends();
    }
  }

  Future<void> _acceptRequest(int requestId, int friendId) async {
    final success = await _friendsRepo.acceptFriendRequest(requestId);
    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Friend added')),
      );
      _loadPendingRequests();
      _loadMyFriends();
      _loadSuggestedFriends();
    }
  }

  Future<void> _rejectRequest(int requestId) async {
    final success = await _friendsRepo.rejectFriendRequest(requestId);
    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Request rejected')),
      );
      _loadPendingRequests();
    }
  }

  Future<void> _cancelFriendRequest(int receiverId) async {
    if (_currentUserId == null) return;

    final success =
        await _friendsRepo.cancelFriendRequest(_currentUserId!, receiverId);
    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Friend request cancelled')),
      );
      _onSearchChanged();
      _loadSuggestedFriends();
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
              final success =
                  await _friendsRepo.removeFriend(_currentUserId!, friendId);
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
    VoidCallback? onAction,
    String? buttonText,
  }) {
    final avatarPath = user['avatar_path'] as String?;
    final name = user['name'] as String? ?? 'Unknown';
    final username = user['username'] as String? ?? '';

    String? avatarUrl;
    if (avatarPath != null && avatarPath.isNotEmpty) {
      avatarUrl = 'http://${ImageStorageService.SERVER_IP}:${ImageStorageService.SERVER_PORT}$avatarPath';
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFF0F7FF),
                border: Border.all(
                  color: const Color(0xFF1976D2),
                  width: 1.5,
                ),
              ),
              child: avatarUrl != null && avatarUrl.isNotEmpty
                  ? ClipOval(
                      child: Image.network(
                        avatarUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return const Icon(Icons.person, size: 35, color: Color(0xFF1976D2));
                        },
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return const Center(
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          );
                        },
                      ),
                    )
                  : const Icon(Icons.person, size: 35, color: Color(0xFF1976D2)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.black87,
                    ),
                  ),
                  if (username.isNotEmpty)
                    Text(
                      '@$username',
                      style: const TextStyle(
                        color: Colors.grey,
                        fontSize: 13,
                      ),
                    ),
                  if (status == 'friend')
                    const Padding(
                      padding: EdgeInsets.only(top: 4),
                      child: Text(
                        '✓ Friend',
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
            if (onAction != null && buttonText != null)
              SizedBox(
                height: 36,
                child: ElevatedButton(
                  onPressed: onAction,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: status == 'friend' ? Colors.grey : const Color(0xFF1976D2),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                  child: Text(
                    buttonText,
                    style: const TextStyle(fontSize: 12, color: Colors.white),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserCardWithActions({
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

    String? avatarUrl;
    if (avatarPath != null && avatarPath.isNotEmpty) {
      avatarUrl = 'http://${ImageStorageService.SERVER_IP}:${ImageStorageService.SERVER_PORT}$avatarPath';
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFF0F7FF),
                border: Border.all(
                  color: const Color(0xFF1976D2),
                  width: 1.5,
                ),
              ),
              child: avatarUrl != null && avatarUrl.isNotEmpty
                  ? ClipOval(
                      child: Image.network(
                        avatarUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return const Icon(Icons.person, size: 35, color: Color(0xFF1976D2));
                        },
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return const Center(
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          );
                        },
                      ),
                    )
                  : const Icon(Icons.person, size: 35, color: Color(0xFF1976D2)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.black87,
                    ),
                  ),
                  if (username.isNotEmpty)
                    Text(
                      '@$username',
                      style: const TextStyle(
                        color: Colors.grey,
                        fontSize: 13,
                      ),
                    ),
                ],
              ),
            ),
            if (onPrimaryAction != null && primaryButtonText != null) ...[
              const SizedBox(width: 8),
              SizedBox(
                height: 36,
                child: ElevatedButton(
                  onPressed: onPrimaryAction,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1976D2),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                  child: Text(
                    primaryButtonText,
                    style: const TextStyle(fontSize: 12, color: Colors.white),
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
                    style: const TextStyle(fontSize: 12, color: Colors.white),
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Friends'),
        backgroundColor: const Color(0xFF1976D2),
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            const Tab(text: 'Find Friends'),
            Tab(
              text: _pendingRequests.isEmpty
                  ? 'Requests'
                  : 'Requests (${_pendingRequests.length})',
            ),
            Tab(
              text: _myFriends.isEmpty
                  ? 'My Friends'
                  : 'My Friends (${_myFriends.length})',
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Tab 1: Find Friends
          Column(
            children: [
              Container(
                color: const Color(0xFF1976D2),
                padding: const EdgeInsets.all(12),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search by name or username',
                    prefixIcon: const Icon(Icons.search, color: Color(0xFF1976D2)),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(25),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: 12,
                      horizontal: 16,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: _searchController.text.isEmpty
                    ? _buildSuggestionsView()
                    : _buildSearchResultsView(),
              ),
            ],
          ),

          // Tab 2: Friend Requests
          _isLoadingPending
              ? const Center(child: CircularProgressIndicator())
              : _pendingRequests.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.person_add_alt_1, size: 48, color: Colors.grey[400]),
                          const SizedBox(height: 16),
                          Text(
                            'No pending requests',
                            style: TextStyle(color: Colors.grey[600], fontSize: 16),
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
                        return _buildUserCardWithActions(
                          user: request,
                          status: 'pending',
                          primaryButtonText: 'Accept',
                          secondaryButtonText: 'Decline',
                          onPrimaryAction: userId != null
                              ? () => _acceptRequest(request['id'] as int, userId)
                              : null,
                          onSecondaryAction: () => _rejectRequest(request['id'] as int),
                        );
                      },
                    ),

          // Tab 3: My Friends
          _isLoadingFriends
              ? const Center(child: CircularProgressIndicator())
              : _myFriends.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.people_outline, size: 48, color: Colors.grey[400]),
                          const SizedBox(height: 16),
                          Text(
                            'No friends yet',
                            style: TextStyle(color: Colors.grey[600], fontSize: 16),
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
                        return _buildUserCardWithActions(
                          user: friend,
                          status: 'friend',
                          primaryButtonText: 'Remove',
                          onPrimaryAction: friendId != null
                              ? () => _removeFriend(friendId)
                              : null,
                        );
                      },
                    ),
        ],
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
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF1976D2),
                  ),
            ),
          ),
          if (_isLoadingSuggestions)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: CircularProgressIndicator(),
              ),
            )
          else if (_suggestedFriends.isEmpty)
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
                final status = friend['friend_status'] as String? ?? 'none';
                
                String buttonText = 'Add';
                VoidCallback? onAction;
                
                if (status == 'request_sent') {
                  buttonText = 'Cancel Request';
                  if (userId != null) {
                    onAction = () => _cancelFriendRequest(userId);
                  }
                } else if (userId != null) {
                  onAction = () => _sendFriendRequest(userId);
                }
                
                return _buildUserCard(
                  user: friend,
                  status: 'suggested',
                  buttonText: buttonText,
                  onAction: onAction,
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildSearchResultsView() {
    // Filter out friends from search results
    final nonFriendResults = _searchResults
        .where((user) => (user['friend_status'] as String? ?? 'none') != 'friend')
        .toList();

    return _isSearching
        ? const Center(child: CircularProgressIndicator())
        : nonFriendResults.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text(
                    'No users found',
                    style: TextStyle(color: Colors.grey[600], fontSize: 16),
                  ),
                ),
              )
            : ListView.builder(
                itemCount: nonFriendResults.length,
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemBuilder: (context, index) {
                  final user = nonFriendResults[index];
                  final status = user['friend_status'] as String? ?? 'none';
                  final userId = user['user_id'] as int?;

                  String buttonText = 'Add';
                  VoidCallback? onAction;
                  
                  if (status == 'request_sent') {
                    buttonText = 'Cancel Request';
                    if (userId != null) {
                      onAction = () => _cancelFriendRequest(userId);
                    }
                  } else if (status == 'request_pending') {
                    buttonText = 'Respond';
                  } else if (status == 'none' && userId != null) {
                    onAction = () => _sendFriendRequest(userId);
                  }

                  return _buildUserCard(
                    user: user,
                    status: status,
                    buttonText: buttonText,
                    onAction: onAction,
                  );
                },
              );
  }
}
