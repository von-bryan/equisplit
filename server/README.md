# EquiSplit Image Server

Simple Node.js server to handle image uploads from Flutter app.

## Setup

1. **Install Node.js** from https://nodejs.org/ (if not already installed)

2. **Install dependencies:**
   ```
   cd server
   npm install
   ```

3. **Start the server:**
   ```
   npm start
   ```

   You should see:
   ```
   🚀 EquiSplit Image Server running at http://10.0.11.103:3000
   📁 Avatars saved to: C:\Users\91460\Desktop\PROJECTS\EquiSplit\equisplit\uploads\avatars
   📁 QR Codes saved to: C:\Users\91460\Desktop\PROJECTS\EquiSplit\equisplit\uploads\qrcodes
   ```

4. **Keep the terminal open** while using the app - the server needs to be running to receive uploads.

## How It Works

- Avatars uploaded from phones are saved to: `uploads/avatars/`
- QR codes uploaded from phones are saved to: `uploads/qrcodes/`
- The server responds with the file path, which is stored in your MySQL database
- Other phones can then access the image by building the URL: `http://10.0.11.103:3000/uploads/avatars/[filename]`

## Network Requirements

- **PC and phones must be on the same WiFi network**
- **Firewall must allow port 3000** (check Windows Firewall settings)
- **IP address is hardcoded as `10.0.11.103`** - if it changes, update Flutter code in `lib/services/image_storage_service.dart`

## Testing

Open in browser: http://10.0.11.103:3000/api/health

Should return: `{"status":"Server is running","ip":"10.0.11.103","port":3000}`
