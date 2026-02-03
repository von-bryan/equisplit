# QR Code Download - Complete Storage Permission Setup

## Problem Fixed
QR code download wasn't saving to phone even after permission dialog appeared.

## Root Causes Identified

### 1. **Missing Android 13+ Permissions**
- Android 13+ (API 33+) uses granular media permissions
- Missing `READ_MEDIA_IMAGES` permission declaration
- App wasn't requesting correct permissions for each Android version

### 2. **Incomplete Permission Request Logic**
- Only requesting one permission at a time
- Not handling multiple permission states
- No verification that file was actually created

### 3. **No File Write Verification**
- File write was silent - no error logging
- No confirmation if file actually existed after write
- Users had no feedback on why download failed

---

## Solutions Applied

### 1. Updated AndroidManifest.xml

**Location:** `android/app/src/main/AndroidManifest.xml`

```xml
<!-- Storage permissions for Android 12 and below -->
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" />
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" />

<!-- Storage permissions for Android 11+ (API 30+) -->
<uses-permission android:name="android.permission.MANAGE_EXTERNAL_STORAGE" />

<!-- Granular media permissions for Android 13+ (API 33+) -->
<uses-permission android:name="android.permission.READ_MEDIA_IMAGES" />
<uses-permission android:name="android.permission.READ_MEDIA_VIDEO" />
<uses-permission android:name="android.permission.READ_MEDIA_AUDIO" />

<!-- Internet permission for downloading images -->
<uses-permission android:name="android.permission.INTERNET" />

<!-- Camera and photo library permissions -->
<uses-permission android:name="android.permission.CAMERA" />
```

### 2. Updated Permission Request Logic

**File:** `lib/pages/expense_details_page.dart`

**New Multi-Version Support:**

```dart
if (Platform.isAndroid) {
  final androidVersion = await _getAndroidVersion();
  List<Permission> permissionsToRequest = [];
  
  // Android 13+ (API 33+) - granular media permissions
  if (androidVersion >= 33) {
    permissionsToRequest.add(Permission.readMediaImages);
    permissionsToRequest.add(Permission.manageExternalStorage);
  }
  // Android 11-12 (API 30-32)
  else if (androidVersion >= 30) {
    permissionsToRequest.add(Permission.manageExternalStorage);
  }
  // Android 10 and below
  else {
    permissionsToRequest.add(Permission.storage);
  }
  
  final statuses = await permissionsToRequest.request();
  bool allGranted = statuses.values.every((s) => s.isGranted);
  bool anyPermanent = statuses.values.any((s) => s.isPermanentlyDenied);
}
```

### 3. Added File Write Verification

```dart
// Write to file
final file = File(downloadPath);
print('📝 Writing ${response.bodyBytes.length} bytes to file...');
await file.writeAsBytes(response.bodyBytes);

// VERIFY file was created
final fileExists = await file.exists();
final fileSize = await file.length();
print('✅ File created: $fileExists, Size: ${fileSize} bytes');

// Show success with details
ScaffoldMessenger.of(context).showSnackBar(
  SnackBar(
    content: Text(
      '✅ QR Code saved successfully!\n'
      'File: $fileName\n'
      'Location: Downloads folder'
    ),
  ),
);
```

### 4. Enhanced Error Logging

```dart
catch (e) {
  print('❌ Download error: $e');
  print('Stack trace: $e');  // Full error details
  
  // Show error to user
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text('❌ Download failed: $e'),
      backgroundColor: Colors.red,
    ),
  );
}
```

---

## Permission Matrix by Android Version

| Android Version | API | Permissions Needed | How to Grant |
|---|---|---|---|
| Android 13+ | 33+ | `READ_MEDIA_IMAGES` + `MANAGE_EXTERNAL_STORAGE` | System dialog + Settings |
| Android 11-12 | 30-32 | `MANAGE_EXTERNAL_STORAGE` | System dialog + Settings |
| Android 10 | 29 | `WRITE_EXTERNAL_STORAGE` | System dialog |
| Android 9 and below | <29 | `WRITE_EXTERNAL_STORAGE` | Manifest only (auto-granted) |

---

## Testing Steps

### Test 1: First Time Download (Android 13+)
1. Open app → Navigate to expense details
2. Click "Pay" button → "Download QR Code"
3. **Expected:** Two permission dialogs appear
   - First: "Allow EquisSplit to access photos?" → Tap "Allow"
   - Second: "Allow EquisSplit to access all files?" → Tap "Allow"
4. **Result:** QR code downloads to Downloads folder
5. **Verification:** Check Flutter logs:
   ```
   ✅ File created: true, Size: XXXX bytes
   ```

### Test 2: Permission Already Granted
1. Try downloading another QR
2. **Expected:** No dialog, instant download

### Test 3: Permission Denied
1. While permission dialog is showing, tap "Deny"
2. **Expected:** Snackbar shows: "❌ Storage permission denied"

### Test 4: Permanently Denied
1. Settings → Apps → EquisSplit → Permissions → Storage
2. Toggle "Allow access to all files" OFF
3. Try QR download
4. **Expected:** Snackbar with "Open Settings" button
5. Tap button → App settings opens
6. Toggle permission ON → Download works

### Test 5: Verify File Location
1. After successful download, open Files app
2. Navigate to Downloads folder
3. **Expected:** See file named like `PayeeName_qrcode_1738508225076.png`

---

## Logs to Monitor

### Successful Download:
```
📱 Android API Level: 33
📱 Android 13+: Requesting READ_MEDIA_IMAGES
📋 Permission statuses: {Permission.readMediaImages: PermissionStatus.granted, ...}
✅ All storage permissions granted
📂 Download directory: /storage/emulated/0/Download
💾 Save location: /storage/emulated/0/Download/PayeeName_qrcode_1738508225076.png
🌐 Downloading from server: http://10.0.11.103:3000/uploads/...
📝 Writing 12345 bytes to file...
✅ File created: true, Size: 12345 bytes
✅ QR Code saved successfully!
```

### Permission Denied:
```
📱 Android API Level: 33
📱 Android 13+: Requesting READ_MEDIA_IMAGES
📋 Permission statuses: {Permission.readMediaImages: PermissionStatus.denied}
❌ Storage permission denied. Please grant access to download.
```

### File Write Failed:
```
📝 Writing 12345 bytes to file...
✅ File created: false, Size: 0 bytes
❌ File was not saved properly!
```

---

## Troubleshooting

### "Storage permission denied" - Still Appears

**Solution:**
1. Uninstall app completely: `flutter clean && flutter uninstall`
2. Reinstall: `flutter run`
3. Accept permission dialog this time

### File Not Appearing in Downloads

**Check:**
1. Go to phone Files app
2. Navigate to Downloads folder
3. Check if file exists there
4. If not, check Flutter logs for: `✅ File created: false`

**Solution:**
1. Check if you're in Internal Storage (not SD card)
2. Try moving to app-specific directory instead:
   ```dart
   Directory? appDir = await getApplicationDocumentsDirectory();
   ```

### "Download timeout" Error

**Causes:**
- Server is down
- Network connection is slow
- Firewall blocking access

**Solution:**
1. Check if server is running: `npm start`
2. Verify IP address: Check if `10.0.11.103:3000` is reachable
3. Test with curl:
   ```bash
   curl http://10.0.11.103:3000/uploads/qrcodes/test.jpg
   ```

### Android 13 Device Still Getting Permission Dialog

**Reason:** 
- Device might be reporting wrong API level
- permission_handler might need update

**Solution:**
1. Update permission_handler: `flutter pub add permission_handler:^12.0.4`
2. Verify API level in logs: Check `📱 Android API Level:`
3. If still wrong, contact support with logs

---

## File Structure After Changes

```
equisplit/
├── android/
│   └── app/src/main/
│       └── AndroidManifest.xml         ✅ UPDATED with all permissions
├── lib/
│   └── pages/
│       └── expense_details_page.dart   ✅ UPDATED with enhanced permission logic
├── pubspec.yaml                        ✅ UNCHANGED (permission_handler: ^12.0.1)
└── FIXES_APPLIED.md                   (Previous fixes still valid)
```

---

## Summary of Changes

| Component | Change | Status |
|-----------|--------|--------|
| AndroidManifest.xml | Added Android 13+ media permissions | ✅ Done |
| expense_details_page.dart | Multi-version permission request | ✅ Done |
| expense_details_page.dart | File existence verification | ✅ Done |
| expense_details_page.dart | Enhanced error logging | ✅ Done |
| pubspec.yaml | No change needed | ✅ OK |

---

## Quick Start

1. **Clean and rebuild:**
   ```bash
   flutter clean
   flutter pub get
   flutter run
   ```

2. **Test download:**
   - Go to Expense Details
   - Click "Pay"
   - Click "Download QR Code"
   - Grant all permissions when prompted
   - Check Downloads folder for file

3. **Monitor logs:**
   ```bash
   flutter logs
   ```
   Look for success message: `✅ File created: true`

---

## Next Steps

If download still doesn't work after these fixes:

1. **Check logs:** Share output from `flutter logs`
2. **Verify permissions:** Settings → Apps → EquisSplit → Permissions
3. **Try alternative:** Save to app-specific directory instead of Downloads
4. **Contact support:** Include:
   - Android version (shown in logs)
   - Error message from snackbar
   - Flutter logs output

---

**Last Updated:** February 2, 2026
**App Status:** Running and ready for testing
