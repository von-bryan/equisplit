# Image Assets

This directory contains all image assets for the EquiSplit application.

## Folder Structure

- **avatars/** - User profile avatar images
- **qrcodes/** - Payment QR code images

## Notes

- Images are downloaded from the database at runtime
- This folder structure allows for version control of static images
- User-generated images are stored in the app's internal documents directory:
  - `/equisplit/avatars/` on the device
  - `/equisplit/qrcodes/` on the device
