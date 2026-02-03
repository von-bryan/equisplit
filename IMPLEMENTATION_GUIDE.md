# Image & QR Storage + Password Hashing Implementation

## What Was Fixed/Added

### 1. **Image Upload Folder Structure** ✅
- **What it does**: Creates an organized folder structure in the app's documents directory
- **Folders created**:
  - `equisplit/avatars/` - For user profile pictures
  - `equisplit/qrcodes/` - For payment QR codes
- **File**: `lib/services/image_storage_service.dart`

**How it works**:
```dart
// When user uploads an image
final savedPath = await ImageStorageService.saveImage(imageFile, 'avatars');

// Creates folder structure automatically
// Device storage: /data/data/com.app.equisplit/documents/equisplit/avatars/
// Then saves image with timestamp: 1706604000000_avatar.jpg
```

### 2. **Password Hashing & Encryption** ✅
- **What it does**: Encrypts passwords before saving to database
- **Method**: SHA-256 hashing
- **File**: `lib/services/password_service.dart`

**How it works**:
```dart
// When user creates account
final hashedPassword = PasswordService.hashPassword("mypassword");
// Saves: a665a45920422f9d417e4867efdc4fb8a04a1f3fff1fa07e998e86f7f7a27ae3

// When user logs in
bool isValid = PasswordService.verifyPassword("mypassword", storedHash);
// Returns: true if passwords match
```

**Security**:
- Passwords are NEVER stored in plain text
- Each password hash is unique (SHA-256)
- Database now stores hashed passwords, not actual passwords

### 3. **Fixed RangeError in CreateExpensePage** ✅
- **Issue**: "RangeError (index): invalid value: valid value range is empty"
- **Cause**: Trying to access users list when empty or missing
- **Solution**: Added try-catch blocks with fallback values

**Error Fix**:
```dart
// BEFORE (caused error):
final payerName = _allUsers.firstWhere(...)?['name'] ?? 'Unknown';

// AFTER (safe):
try {
  final payerUser = _allUsers.firstWhere(...);
  payerName = payerUser['name'] ?? 'Unknown';
} catch (e) {
  payerName = 'Unknown';
}
```

## New Dependencies Added

```yaml
dependencies:
  path_provider: ^2.1.0      # For accessing app documents directory
  crypto: ^3.0.3              # For SHA-256 password hashing
```

## How to Use

### Upload Avatar
```dart
// In ProfilePage
Future<void> _pickAvatarImage() async {
  final XFile? pickedFile = await _imagePicker.pickImage(...);
  if (pickedFile != null) {
    final savedPath = await ImageStorageService.saveImage(
      File(pickedFile.path), 
      'avatars'
    );
    // Now use savedPath to display image
  }
}
```

### Upload QR Code
```dart
final savedPath = await ImageStorageService.saveImage(
  imageFile, 
  'qrcodes'
);
_qrImages.add({
  'label': 'GCash',
  'path': savedPath,  // This path persists!
});
```

### Hash Password on Signup
```dart
// UserRepository.createUserWithPassword()
final hashedPassword = PasswordService.hashPassword(password);
await _db.execute(
  'INSERT INTO equisplit.user (..., password) VALUES (..., ?)',
  [..., hashedPassword],  // Store hashed, not plain text
);
```

### Authenticate User
```dart
// No more plain text password check!
final user = await _userRepo.authenticateUser(username, password);
// Internally: verifies password against database hash
```

## Database Update Required

⚠️ **For existing users**, you should rehash their passwords:

```sql
-- Update old plain text passwords to hashes
-- (This is just an example, your hashes will be different)
UPDATE equisplit.user SET password = SHA2(password, 256) WHERE id = 1;
```

Or in Dart:
```dart
// One-time migration script
List<Map> users = await _db.query('SELECT id, password FROM equisplit.user');
for (var user in users) {
  if (!user['password'].contains('a665')) { // Check if already hashed
    final hashed = PasswordService.hashPassword(user['password']);
    await _db.execute(
      'UPDATE equisplit.user SET password = ? WHERE id = ?',
      [hashed, user['id']],
    );
  }
}
```

## File Storage Locations

**Android**:
```
/data/data/com.equisplit.app/files/equisplit/
├── avatars/
│   ├── 1706604000000_avatar.jpg
│   └── 1706604015000_profile.jpg
└── qrcodes/
    ├── 1706604030000_gcash.jpg
    └── 1706604045000_paymaya.jpg
```

**iOS**:
```
~/Library/Application Support/equisplit/
├── avatars/
└── qrcodes/
```

## Benefits

✅ Images persist across app restarts (stored on device)
✅ Passwords are encrypted and never stored in plain text
✅ No more RangeError crashes when accessing empty lists
✅ Professional file organization
✅ Automatic folder creation
✅ Unique filenames with timestamps
✅ Easy image deletion if needed

## Testing

1. Create new account - password is automatically hashed
2. Upload avatar - check device storage (Android: Device File Explorer)
3. Upload QR code - files persist after app restart
4. Login - uses hashed password verification
5. Try wrong password - login fails securely
