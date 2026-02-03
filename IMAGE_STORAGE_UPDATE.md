# Image Storage Update - January 31, 2026

## 📁 New Image Storage Structure

**Images are now saved to a shared, project-accessible location:**

```
Device Storage:
├── equisplit/
│   ├── avatars/
│   │   └── [timestamp]_[filename].jpg
│   └── qrcodes/
│       └── [timestamp]_[filename].jpg
```

**Location on Device:**
- Path changes based on device: `/storage/emulated/0/equisplit/` or similar
- This is **external storage** (shared across all apps)
- **NOT** inside app-specific data folder
- **Persists** even if app is uninstalled

## 🔄 How Images Are Stored

### Before (Old System)
```
/data/user/0/com.example.equisplit/app_flutter/equisplit/avatars/
```
❌ App-specific directory
❌ Lost when app uninstalls
❌ Can't be shared

### After (New System)
```
/storage/emulated/0/equisplit/avatars/
```
✅ Shared external storage
✅ Accessible from file manager
✅ Persists across app installations
✅ Accessible across all phones with same database

## 📱 Multi-Phone Access

When you run on **Infinix OR Samsung** phone:
1. Both connect to same database (MySQL server)
2. Database stores image file paths
3. Paths point to external storage location
4. Both phones can access images from the same path

**Example:**
- User "Sunshine" uploads avatar on Infinix
- Database saves: `/storage/emulated/0/equisplit/avatars/1769826596707_photo.jpg`
- Samsung phone runs app, queries database
- Samsung can load same image from that path

## 🔧 Updated Services

### ImageStorageService.dart
```dart
// Uses getExternalStorageDirectory() instead of getApplicationDocumentsDirectory()
// Falls back to app documents if external storage unavailable
// Creates /equisplit/avatars/ and /equisplit/qrcodes/ folders
```

### Android Permissions
```xml
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" />
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" />
<uses-permission android:name="android.permission.MANAGE_EXTERNAL_STORAGE" />
```

## 📝 Database Integration

Images paths stored in:
- **user_avatars** table → image_path
- **user_qr_codes** table → image_path

Both tables reference the external storage path, so any phone can load them.

## ✅ Benefits

✅ Images survive app uninstall/reinstall
✅ Accessible across multiple phones
✅ Can be backed up/synced easily
✅ Version-controllable paths
✅ Accessible via file manager

## 🚀 Next Steps

1. Test on both Infinix and Samsung
2. Upload new avatar/QR codes
3. Check if images appear on both phones
4. Images should be visible in device's file manager under /equisplit/ folder
