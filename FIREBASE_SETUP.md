# Firebase Authentication Setup Guide

This app now includes Firebase Authentication for user login. Follow these steps to complete the Firebase setup:

## Prerequisites
- A Google account
- Firebase CLI (optional but recommended)

## Setup Steps

### 1. Create a Firebase Project
1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Click "Add project" or "Create a project"
3. Enter project name (e.g., "solar-panel-monitor")
4. Follow the setup wizard

### 2. Enable Authentication
1. In Firebase Console, go to **Build** > **Authentication**
2. Click "Get Started"
3. Go to **Sign-in method** tab
4. Enable **Email/Password** authentication
5. Click "Save"

### 3. Configure Your App

#### Option A: Using FlutterFire CLI (Recommended)
1. Open terminal and add FlutterFire CLI to your PATH:
   ```bash
   export PATH="$PATH":"$HOME/.pub-cache/bin"
   ```

2. Run FlutterFire configure:
   ```bash
   cd /Users/cherianchirackaljoseph/AndroidStudioProjects/untitled2
   flutterfire configure
   ```

3. Select your Firebase project
4. Select platforms (at minimum, select Android)
5. This will automatically generate `lib/firebase_options.dart` with correct configuration

#### Option B: Manual Configuration

##### For Android:
1. In Firebase Console, click the Android icon to add Android app
2. Enter package name: `com.example.untitled2` (or your actual package name from `android/app/build.gradle.kts`)
3. Download `google-services.json`
4. Place it in `android/app/` directory
5. Update `android/build.gradle.kts` to include:
   ```kotlin
   dependencies {
       classpath("com.google.gms:google-services:4.4.0")
   }
   ```
6. Update `android/app/build.gradle.kts` to add at the bottom:
   ```kotlin
   plugins {
       id("com.google.gms.google-services")
   }
   ```

##### For iOS (if needed):
1. In Firebase Console, click the iOS icon to add iOS app
2. Enter bundle ID: `com.example.untitled2`
3. Download `GoogleService-Info.plist`
4. Place it in `ios/Runner/` directory
5. Open Xcode and add the file to the Runner target

### 4. Update Firebase Options
After running `flutterfire configure`, your `lib/firebase_options.dart` will be automatically updated with the correct API keys and configuration.

If you configured manually, replace the placeholder values in `lib/firebase_options.dart` with values from your Firebase project settings.

### 5. Test the App
1. Run the app:
   ```bash
   flutter run
   ```

2. You should see the login screen
3. Create a new account using the "Sign Up" button
4. Login with your credentials

## Features Included

✅ **Email/Password Authentication**
- User registration
- User login
- Password reset via email
- Logout functionality

✅ **Protected Routes**
- Automatic redirect to login screen if not authenticated
- Auto-login if user session exists

✅ **User Profile**
- Display user email in Menu tab
- Logout confirmation dialog

## Troubleshooting

### "Default FirebaseOptions have not been configured"
- Run `flutterfire configure` to generate proper configuration
- Or manually update `lib/firebase_options.dart` with your Firebase project credentials

### "No firebase app has been created"
- Make sure Firebase is initialized in `main()` before running the app
- Check that `google-services.json` (Android) is in the correct location

### Authentication errors
- Verify that Email/Password authentication is enabled in Firebase Console
- Check your internet connection
- Look at the error messages in the login screen

### Build errors
- Run `flutter clean` then `flutter pub get`
- Make sure all Firebase dependencies are installed
- Check that Google Services plugin is properly configured in build.gradle files

## Security Best Practices

1. **Never commit** `google-services.json` or `GoogleService-Info.plist` to public repositories
2. Set up **Firestore Security Rules** if you use Cloud Firestore
3. Enable **Firebase App Check** for additional security
4. Use **email verification** for production apps
5. Implement **rate limiting** to prevent abuse

## Next Steps

- Add email verification after registration
- Implement Google Sign-In or other social auth
- Add user profile data storage in Firestore
- Implement password change functionality
- Add multi-factor authentication (MFA)

## Support

For more information, visit:
- [FlutterFire Documentation](https://firebase.flutter.dev/)
- [Firebase Console](https://console.firebase.google.com/)
- [Flutter Firebase Codelab](https://firebase.google.com/codelabs/firebase-get-to-know-flutter)
