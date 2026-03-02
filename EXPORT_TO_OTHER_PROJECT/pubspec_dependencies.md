# Required Dependencies

Add these to your `pubspec.yaml` file:

```yaml
name: your_app_name  # Change this to your app name
description: Your app description

publish_to: 'none'

version: 1.0.0+1

environment:
  sdk: ^3.10.8

dependencies:
  flutter:
    sdk: flutter
  
  # Required for ESP32 Control functionality
  http: ^1.2.1          # HTTP requests to ESP32 cloud API
  mongo_dart: ^0.9.3    # MongoDB Atlas database connection
  
  # Your other dependencies...
  cupertino_icons: ^1.0.8

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^6.0.0

flutter:
  uses-material-design: true
```

## Install Dependencies

After updating `pubspec.yaml`, run:

```bash
flutter pub get
```

## For Android - Internet Permission

Make sure your Android app has internet permission. 

File: `android/app/src/main/AndroidManifest.xml`

Add this line inside the `<manifest>` tag (before `<application>`):

```xml
<uses-permission android:name="android.permission.INTERNET"/>
```

Example:
```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <uses-permission android:name="android.permission.INTERNET"/>
    
    <application
        android:label="your_app"
        android:name="${applicationName}"
        android:icon="@mipmap/ic_launcher">
        <!-- ... rest of config ... -->
    </application>
</manifest>
```

## For iOS

No additional configuration needed - internet permission is enabled by default.
