const express = require('express');
const multer = require('multer');
const path = require('path');
const fs = require('fs');
const cors = require('cors');

const app = express();
const PORT = 3000;

// Enable CORS
app.use(cors());
app.use(express.json());

// Ensure upload directories exist
const uploadsDir = path.join(__dirname, '..', 'uploads');
const avatarsDir = path.join(uploadsDir, 'avatars');
const qrcodesDir = path.join(uploadsDir, 'qrcodes');
const proofsDir = path.join(uploadsDir, 'proofs');
const chatDir = path.join(uploadsDir, 'chat');

[avatarsDir, qrcodesDir, proofsDir, chatDir].forEach(dir => {
  if (!fs.existsSync(dir)) {
    fs.mkdirSync(dir, { recursive: true });
  }
});

// Configure multer for different upload types
const createStorage = (folderName) => {
  return multer.diskStorage({
    destination: (req, file, cb) => {
      const uploadPath = path.join(uploadsDir, folderName);
      cb(null, uploadPath);
    },
    filename: (req, file, cb) => {
      const timestamp = Date.now();
      const ext = path.extname(file.originalname);
      const name = path.basename(file.originalname, ext);
      cb(null, `${timestamp}_${name}${ext}`);
    }
  });
};

const uploadAvatars = multer({ storage: createStorage('avatars') });
const uploadQrcodes = multer({ storage: createStorage('qrcodes') });
const uploadProofs = multer({ storage: createStorage('proofs') });
const uploadChat = multer({ 
  storage: createStorage('chat'),
  limits: { fileSize: 50 * 1024 * 1024 } // 50MB limit for videos
});

// Routes
app.post('/api/upload/avatar', uploadAvatars.single('file'), (req, res) => {
  if (!req.file) {
    return res.status(400).json({ error: 'No file uploaded' });
  }
  const filePath = `/uploads/avatars/${req.file.filename}`;
  console.log(`✅ Avatar uploaded: ${filePath}`);
  res.json({ 
    success: true, 
    filePath: filePath,
    filename: req.file.filename,
    fullPath: `http://10.0.11.103:${PORT}${filePath}`
  });
});

app.post('/api/upload/qrcode', uploadQrcodes.single('file'), (req, res) => {
  if (!req.file) {
    return res.status(400).json({ error: 'No file uploaded' });
  }
  const filePath = `/uploads/qrcodes/${req.file.filename}`;
  console.log(`✅ QR Code uploaded: ${filePath}`);
  res.json({ 
    success: true, 
    filePath: filePath,
    filename: req.file.filename,
    fullPath: `http://10.0.11.103:${PORT}${filePath}`
  });
});

app.post('/api/upload/proof', uploadProofs.single('file'), (req, res) => {
  if (!req.file) {
    return res.status(400).json({ error: 'No file uploaded' });
  }
  const filePath = `/uploads/proofs/${req.file.filename}`;
  console.log(`✅ Proof of Payment uploaded: ${filePath}`);
  res.json({ 
    success: true, 
    filePath: filePath,
    filename: req.file.filename,
    fullPath: `http://10.0.11.103:${PORT}${filePath}`
  });
});

app.post('/api/upload/chat', uploadChat.single('file'), (req, res) => {
  if (!req.file) {
    return res.status(400).json({ error: 'No file uploaded' });
  }
  const filePath = `/uploads/chat/${req.file.filename}`;
  console.log(`✅ Chat media uploaded: ${filePath}`);
  res.json({ 
    success: true, 
    filePath: filePath,
    filename: req.file.filename,
    mimeType: req.file.mimetype
  });
});

// Serve uploaded files
app.use('/uploads', express.static(uploadsDir));

// Health check
app.get('/api/health', (req, res) => {
  res.json({ status: 'Server is running', ip: '10.0.11.103', port: PORT });
});

// Start server
app.listen(PORT, '0.0.0.0', () => {
  console.log(`🚀 EquiSplit Image Server running at http://10.0.11.103:${PORT}`);
  console.log(`📁 Avatars saved to: ${avatarsDir}`);
  console.log(`📁 QR Codes saved to: ${qrcodesDir}`);
  console.log(`📁 Proofs saved to: ${proofsDir}`);
  console.log(`📁 Chat media saved to: ${chatDir}`);
});
