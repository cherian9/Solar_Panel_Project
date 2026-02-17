#!/bin/bash

echo "🔥 Firebase Setup Helper for Solar Panel App"
echo "=============================================="
echo ""

# Check if FlutterFire CLI is installed
if ! command -v flutterfire &> /dev/null; then
    echo "⚠️  FlutterFire CLI not found in PATH"
    echo "Installing FlutterFire CLI..."
    dart pub global activate flutterfire_cli
    echo ""
    echo "✅ FlutterFire CLI installed!"
    echo ""
    echo "⚠️  Please run this command to add FlutterFire to your PATH:"
    echo "export PATH=\"\$PATH\":\"\$HOME/.pub-cache/bin\""
    echo ""
    echo "Or add it permanently to ~/.zshrc:"
    echo "echo 'export PATH=\"\$PATH\":\"\$HOME/.pub-cache/bin\"' >> ~/.zshrc"
    echo "source ~/.zshrc"
    echo ""
    exit 0
fi

echo "✅ FlutterFire CLI found!"
echo ""

# Navigate to project directory
cd "$(dirname "$0")"

echo "📱 Configuring Firebase for your project..."
echo ""

# Run FlutterFire configure
flutterfire configure

echo ""
echo "✅ Firebase configuration complete!"
echo ""
echo "📝 Next Steps:"
echo "1. Go to https://console.firebase.google.com/"
echo "2. Select your project"
echo "3. Click 'Build' → 'Authentication'"
echo "4. Enable 'Email/Password' authentication"
echo "5. Run: flutter run"
echo ""
echo "🎉 You're ready to test the app!"
