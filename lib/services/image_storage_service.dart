import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

class ImageStorageService {
  static const String SERVER_IP = '10.0.5.60';
  static const int SERVER_PORT = 3000;
  static const String BASE_URL = 'http://$SERVER_IP:$SERVER_PORT/api';

  /// Test server connectivity
  static Future<bool> testServerConnection() async {
    try {
      print('🧪 Testing server connection to http://$SERVER_IP:$SERVER_PORT');
      final response = await http.get(
        Uri.parse('http://$SERVER_IP:$SERVER_PORT'),
      ).timeout(
        const Duration(seconds: 5),
        onTimeout: () => throw Exception('Timeout'),
      );
      print('✅ Server reachable: ${response.statusCode}');
      return response.statusCode == 200 || response.statusCode == 404;
    } catch (e) {
      print('❌ Server connection failed: $e');
      return false;
    }
  }

  /// Upload image to PC server (accessible across all phones with same database)
  static Future<String?> saveImage(File imageFile, String subfolder) async {
    try {
      final uploadEndpoint = subfolder == 'avatars' 
          ? '$BASE_URL/upload/avatar'
          : '$BASE_URL/upload/qrcode';

      print('📤 Uploading to: $uploadEndpoint');

      final request = http.MultipartRequest('POST', Uri.parse(uploadEndpoint));
      request.files.add(
        await http.MultipartFile.fromPath(
          'file',
          imageFile.path,
        ),
      );

      final response = await request.send().timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception('Upload timeout - server might be unreachable');
        },
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(await response.stream.bytesToString());
        final filePath = responseData['filePath'] as String;
        final fullUrl = responseData['fullPath'] as String;
        
        print('✅ Upload successful: $filePath');
        print('🔗 Full URL: $fullUrl');
        
        // Return the path for database storage
        return filePath;
      } else {
        print('❌ Upload failed: ${response.statusCode}');
        print('Response: ${await response.stream.bytesToString()}');
        return null;
      }
    } catch (e) {
      print('❌ Upload error: $e');
      return null;
    }
  }

  /// Upload proof of payment image
  static Future<String?> saveProofOfPayment(File imageFile) async {
    try {
      final uploadEndpoint = '$BASE_URL/upload/proof';
      print('📤 Uploading proof of payment to: $uploadEndpoint');

      final request = http.MultipartRequest('POST', Uri.parse(uploadEndpoint));
      request.files.add(
        await http.MultipartFile.fromPath(
          'file',
          imageFile.path,
        ),
      );

      final response = await request.send().timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception('Upload timeout');
        },
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseData = jsonDecode(await response.stream.bytesToString());
        final filePath = responseData['filePath'] ?? responseData['path'];
        print('✅ Proof uploaded successfully: $filePath');
        return filePath;
      } else {
        print('❌ Upload failed: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('❌ Proof upload error: $e');
      return null;
    }
  }

  /// Get image URL from server
  static String getImageUrl(String filePath) {
    final url = 'http://$SERVER_IP:$SERVER_PORT$filePath';
    print('🔗 Image URL: $url (from path: $filePath)');
    return url;
  }

  /// Delete image from server
  static Future<bool> deleteImage(String filePath) async {
    try {
      print('🗑️ Deleting: $filePath');
      // Note: You may want to add a DELETE endpoint in the server for this
      return true;
    } catch (e) {
      print('❌ Error deleting image: $e');
      return false;
    }
  }
}
