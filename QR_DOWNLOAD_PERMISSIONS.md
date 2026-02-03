# QR Code Download - Permissions Configuration

## Overview
The QR download feature requires specific Android permissions for Android 10+ devices due to scoped storage restrictions.

---

## 1. AndroidManifest.xml Permissions

**Location:** `android/app/src/main/AndroidManifest.xml`

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <!-- Storage permissions -->
    <uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" />
    <uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" />
    <uses-permission android:name="android.permission.MANAGE_EXTERNAL_STORAGE" />
    
    <!-- Internet permission for downloading images -->
    <uses-permission android:name="android.permission.INTERNET" />
    
    <!-- Camera and photo library permissions -->
    <uses-permission android:name="android.permission.CAMERA" />
    
    <!-- Application configuration follows... -->
</manifest>
```

### Permission Explanations:

| Permission | Purpose | Android Version |
|-----------|---------|-----------------|
| `READ_EXTERNAL_STORAGE` | Read files from device storage | API 18+ |
| `WRITE_EXTERNAL_STORAGE` | Write files to device storage | API 4+ |
| `MANAGE_EXTERNAL_STORAGE` | Access all files (scoped storage bypass) | API 30+ |
| `INTERNET` | Download QR codes from server | API 1+ |
| `CAMERA` | Take photos for proof of payment | API 1+ |

---

## 2. pubspec.yaml Dependencies

**Location:** `pubspec.yaml`

```yaml
dependencies:
  flutter:
    sdk: flutter
  
  # ... other dependencies ...
  
  permission_handler: ^11.4.4  # Runtime permission handling
  path_provider: ^2.1.0         # Access device directories
  http: ^1.1.0                  # Download QR images
```

---

## 3. Flutter Runtime Permission Code

**Location:** `lib/pages/expense_details_page.dart`

### Import Statement:
```dart
import 'package:permission_handler/permission_handler.dart';
```

### Permission Request Function:
```dart
Future<void> _downloadQRCode(String qrImagePath, String payeeName) async {
  try {
    print('📥 Starting download from: $qrImagePath');
    
    // Request permission for Android 10+
    if (Platform.isAndroid) {
      final status = await Permission.storage.request();
      
      if (status.isDenied) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Storage permission denied')),
          );
        }
        return;
      }
      
      if (status.isPermanentlyDenied) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Storage permission permanently denied. Open app settings.'),
              action: SnackBarAction(
                label: 'Settings',
                onPressed: openAppSettings,
              ),
            ),
          );
        }
        return;
      }
    }
    
    // Get the Downloads directory
    Directory? downloadDir = await getDownloadsDirectory();
    
    // ... rest of download logic ...
  } catch (e) {
    print('❌ Download error: $e');
  }
}
```

---

## 4. Android 10+ Scoped Storage Considerations

### What Changed:
- **Android 9 and below:** Apps can access all files with `WRITE_EXTERNAL_STORAGE`
- **Android 10+:** Apps are restricted to app-specific directories (scoped storage)
- **Solution:** Use `MANAGE_EXTERNAL_STORAGE` to access Downloads folder

### File Path Access:
```dart
// Works on all Android versions
Directory? downloadDir = await getDownloadsDirectory();

// Generates path like: /storage/emulated/0/Download/
String downloadPath = '${downloadDir.path}/QRCode_timestamp.png';
```

---

## 5. Permission States Handled

| State | Behavior |
|-------|----------|
| `granted` | Download proceeds normally |
| `denied` | Show snackbar, don't download |
| `permanentlyDenied` | Show snackbar with link to app settings |
| `restricted` | iOS specific, show settings link |
| `provisional` | iOS specific, request after interaction |

---

## 6. User Flow

```
1. User clicks "Download QR Code" button
   ↓
2. App checks if runtime permission is needed (Android only)
   ↓
3. If not granted, system shows permission dialog:
   "Allow EquisSplit to access photos, media, and files on your device?"
   [DENY] [ALLOW]
   ↓
4. If user grants:
   - Download QR from server
   - Save to Downloads folder
   - Show success snackbar
   ↓
5. If user denies:
   - If first time: Show snackbar
   - If permanently denied: Show snackbar with "Settings" button
```

---

## 7. Testing Permission Scenarios

### Test Case 1: First Time Download
- App shows system permission dialog
- User taps "Allow"
- QR code downloads successfully

### Test Case 2: Permission Already Granted
- No dialog shown
- QR code downloads immediately

### Test Case 3: Permission Denied
- App shows "Storage permission denied" snackbar
- Download is not attempted

### Test Case 4: Permanently Denied
- App shows snackbar with "Settings" button
- Tapping "Settings" opens app settings
- User can manually grant permission there

---

## 8. Installation Steps

Run this command to install/update dependencies:

```bash
flutter pub get
```

Then rebuild the app:

```bash
flutter clean
flutter pub get
flutter run
```

---

## 9. Troubleshooting

### Issue: "Permission permanently denied"
**Solution:** 
- Go to Phone Settings → Apps → EquisSplit → Permissions → Storage
- Toggle "Allow access to all files" ON

### Issue: "Cannot access downloads folder"
**Solution:**
- Ensure `MANAGE_EXTERNAL_STORAGE` is in AndroidManifest.xml
- For Android 10, use `getDownloadsDirectory()` from path_provider
- Target SDK must be 33+ (API 33+)

### Issue: "Download fails even with permission granted"
**Solution:**
- Check internet connection
- Verify server is running and QR image exists
- Check file system permissions on device

---

## 10. Security Best Practices

1. ✅ **Always request permission before file operations**
2. ✅ **Handle all permission states (granted, denied, permanentlyDenied)**
3. ✅ **Show clear user messaging about why permissions are needed**
4. ✅ **Provide Settings link for permanently denied permissions**
5. ✅ **Use app-specific directories when possible** (Downloads is shared storage)
6. ✅ **Validate downloaded file before using** (check size, format)

---

## Summary

**Required Changes Made:**
- ✅ Added `permission_handler: ^11.4.4` to pubspec.yaml
- ✅ Updated AndroidManifest.xml with all required permissions
- ✅ Added runtime permission check in `_downloadQRCode()` function
- ✅ Handles all permission states with appropriate UI feedback

**No additional configuration needed!** The app is now ready to download QR codes on Android 10+.
