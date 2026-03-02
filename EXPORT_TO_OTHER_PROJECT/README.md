# 📦 ESP32 System Control - Export Package

## 🎯 What's This?

This folder contains **everything you need** to add ESP32 system control functionality to ANY Flutter project!

---

## 📁 Files in This Folder

| File | Description |
|------|-------------|
| `mongo_service.dart` | MongoDB Atlas service - handles database connection and state management |
| `system_control_page.dart` | Complete UI page with button, status cards, and polling logic |
| `main_example_1_simple.dart` | Example: Use as main page |
| `main_example_2_bottom_nav.dart` | Example: Use with bottom navigation |
| `main_example_3_navigation.dart` | Example: Navigate to it from a button |
| `pubspec_dependencies.md` | Required dependencies for pubspec.yaml |
| `QUICK_START.md` | Fast 3-step integration guide |

---

## 🚀 Integration Methods

### Method 1: Manual Copy (Recommended)

1. **Copy files to your project:**
   - `mongo_service.dart` → `your_project/lib/services/`
   - `system_control_page.dart` → `your_project/lib/pages/`

2. **Add dependencies to `pubspec.yaml`:**
   ```yaml
   dependencies:
     http: ^1.2.1
     mongo_dart: ^0.9.3
   ```

3. **Run:**
   ```bash
   flutter pub get
   ```

4. **Use in your app:**
   ```dart
   import 'pages/system_control_page.dart';
   
   // Then navigate to it or use as home page
   home: const SystemControlPage(),
   ```

### Method 2: Use Example main.dart

Pick one of the example files and copy the integration code to your main.dart:
- `main_example_1_simple.dart` - Simplest method
- `main_example_2_bottom_nav.dart` - For apps with bottom navigation
- `main_example_3_navigation.dart` - For apps that navigate to it

---

## ✨ Features You Get

✅ **Beautiful UI** - Dark theme with animated power button  
✅ **MongoDB Integration** - Direct connection to MongoDB Atlas (no backend!)  
✅ **Real-time State** - ON/OFF toggle with instant feedback  
✅ **ESP32 Polling** - Background confirmation from hardware (80s timeout)  
✅ **Status Cards** - Location, mode, connection, and system status  
✅ **Error Handling** - Automatic retries and user-friendly error messages  
✅ **Multi-User Support** - Share same database with multiple users  
✅ **Production Ready** - Clean code, proper dispose, state management  

---

## 📋 Quick Checklist

- [ ] Copy `mongo_service.dart` to `lib/services/`
- [ ] Copy `system_control_page.dart` to `lib/pages/`
- [ ] Add `http` and `mongo_dart` to `pubspec.yaml`
- [ ] Run `flutter pub get`
- [ ] Import and use `SystemControlPage` in your app
- [ ] Run `flutter run`
- [ ] Test toggle functionality
- [ ] Check console logs for connection status

---

## 🔧 Configuration

### MongoDB Connection
Default: Connects to shared database
```
mongodb+srv://solarpanelsjcet_db_user:...@cluster0.a3sl4rk.mongodb.net/test
```

To use your own database, edit `mongo_service.dart` line 17.

### ESP32 Cloud API
Default: `https://0ezk16r0u1.execute-api.ap-south-1.amazonaws.com/control`

To change, edit `system_control_page.dart` line 9.

---

## 🎨 Customization

All customization options are well-commented in the code:

- **Colors**: Lines 199, 204, 289 in `system_control_page.dart`
- **Info Cards**: Lines 231-262 in `system_control_page.dart`
- **Polling Duration**: Line 131 in `system_control_page.dart`
- **MongoDB URL**: Line 17 in `mongo_service.dart`
- **ESP32 API URL**: Line 9 in `system_control_page.dart`

---

## 📱 Requirements

- Flutter SDK: `^3.10.8` (or higher)
- Dart: `^3.0.0` (or higher)
- Internet connection (for MongoDB and ESP32 API)
- Android: Internet permission in AndroidManifest.xml
- iOS: No additional config needed

---

## 🎓 How to Use

### As Main Page
```dart
MaterialApp(
  home: const SystemControlPage(),
)
```

### With Navigation
```dart
Navigator.push(
  context,
  MaterialPageRoute(builder: (context) => const SystemControlPage()),
);
```

### In Bottom Navigation
```dart
final _pages = [
  HomePage(),
  SystemControlPage(), // Add here
  SettingsPage(),
];
```

---

## 🌐 Multi-User Support

The default MongoDB database is shared, which means:
- User A turns ON → Database updates → User B sees ON
- User B turns OFF → Database updates → User A sees OFF

Perfect for controlling a single ESP32 from multiple devices!

---

## 🔍 Troubleshooting

### "Failed to connect to MongoDB Atlas"
- Check internet connection
- Verify MongoDB URL is correct
- Check MongoDB Atlas IP whitelist (should allow all: `0.0.0.0/0`)

### "Socket Exception"
- Add internet permission to `AndroidManifest.xml`:
  ```xml
  <uses-permission android:name="android.permission.INTERNET"/>
  ```

### Import errors
- Make sure you ran `flutter pub get`
- Check file paths are correct (`lib/services/`, `lib/pages/`)

### Button not responding
- Check console logs for connection status
- Verify MongoDB connection is successful (look for ✅ logs)

---

## 📊 How It Works

```
User Taps Button
      ↓
UI Updates Immediately (optimistic)
      ↓
Update MongoDB Database
      ↓
Start Background Polling (80 seconds max)
      ↓
Every 1 second: Check ESP32 state
      ↓
ESP32 Confirms → Success! ✅
      or
80 seconds timeout → Warning ⚠️
```

---

## 🎉 That's Everything!

You now have a complete, production-ready ESP32 control system that you can:
- Drop into any Flutter project
- Customize to your needs
- Share with multiple users
- Deploy to production

**For detailed help, see:**
- `QUICK_START.md` - Fast 3-step guide
- `../INTEGRATION_GUIDE.md` - Full documentation

---

**Happy Building! 🚀**

Questions? Check the console logs - they have emojis! 🔄✅❌
