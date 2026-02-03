import 'package:flutter/material.dart';
import 'package:equisplit/repositories/user_repository.dart';
import 'package:equisplit/services/image_storage_service.dart';

class DebugPage extends StatefulWidget {
  const DebugPage({super.key});

  @override
  State<DebugPage> createState() => _DebugPageState();
}

class _DebugPageState extends State<DebugPage> {
  final _userRepo = UserRepository();
  List<Map<String, dynamic>> _users = [];
  String _debugInfo = 'Loading...';
  String _storagePath = 'Loading...';

  @override
  void initState() {
    super.initState();
    _loadDebugInfo();
  }

  Future<void> _loadDebugInfo() async {
    try {
      // Get server info
      final serverUrl = 'http://${ImageStorageService.SERVER_IP}:${ImageStorageService.SERVER_PORT}';
      
      // Get users
      final users = await _userRepo.getAllUsers();
      
      StringBuffer info = StringBuffer();
      info.writeln('📱 Device Debug Info');
      info.writeln('${DateTime.now()}');
      info.writeln('');
      info.writeln('🖥️ Image Server: $serverUrl');
      info.writeln('');
      info.writeln('Storage Information:');
      info.writeln('Server IP: ${ImageStorageService.SERVER_IP}');
      info.writeln('Server Port: ${ImageStorageService.SERVER_PORT}');
      info.writeln('');
      info.writeln('Total Users: ${users.length}');
      info.writeln('');
      info.writeln('Users in Database:');
      
      for (var user in users) {
        info.writeln('---');
        info.writeln('Name: ${user['name']}');
        info.writeln('User ID: ${user['user_id']}');
        
        // Check avatar
        final avatarPath = await _userRepo.getUserAvatarPath(user['user_id']);
        info.writeln('Avatar Path: $avatarPath');
        
        info.writeln('All Fields: ${user.keys.toList().join(", ")}');
      }

      setState(() {
        _users = users;
        _debugInfo = info.toString();
        _storagePath = serverUrl;
      });
    } catch (e) {
      setState(() {
        _debugInfo = 'Error: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Debug Info'),
        backgroundColor: const Color(0xFF424242),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange[100],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '🔍 Storage Path (IMPORTANT)',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _storagePath,
                      style: const TextStyle(
                        fontFamily: 'Courier',
                        fontSize: 11,
                        color: Color(0xFF212121),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Text(
                _debugInfo,
                style: const TextStyle(
                  fontFamily: 'Courier',
                  fontSize: 12,
                  color: Color(0xFF212121),
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _loadDebugInfo,
                child: const Text('Refresh'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
