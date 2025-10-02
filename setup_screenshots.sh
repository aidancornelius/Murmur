#!/bin/bash

# Screenshot automation setup script for Murmur
# This script helps set up the screenshot automation infrastructure

set -e

echo "🎬 Murmur screenshot automation setup"
echo "======================================"
echo ""

# Check if Fastlane is installed
if ! command -v fastlane &> /dev/null; then
    echo "⚠️  Fastlane is not installed"
    echo ""
    echo "Please install Fastlane using one of these methods:"
    echo ""
    echo "Option 1 - Using Homebrew (recommended):"
    echo "  brew install fastlane"
    echo ""
    echo "Option 2 - Using RubyGems:"
    echo "  sudo gem install fastlane"
    echo ""
    echo "Option 3 - Using Bundler (for this project only):"
    echo "  Create a Gemfile with: gem 'fastlane'"
    echo "  Then run: bundle install"
    echo ""
    exit 1
else
    echo "✅ Fastlane is already installed ($(fastlane --version | head -n 1))"
fi

# Check if Xcode is installed
if ! command -v xcodebuild &> /dev/null; then
    echo "❌ Xcode is not installed. Please install Xcode from the Mac App Store."
    exit 1
else
    echo "✅ Xcode is installed"
fi

echo ""
echo "📋 Next steps:"
echo ""
echo "1. Open Murmur.xcodeproj in Xcode"
echo ""
echo "2. Add a UI test target:"
echo "   • File > New > Target"
echo "   • Select 'UI Testing Bundle'"
echo "   • Name it 'MurmurUITests'"
echo "   • Click Finish"
echo ""
echo "3. Delete the auto-generated test file:"
echo "   • Delete 'MurmurUITests/MurmurUITestsLaunchTests.swift' (if present)"
echo ""
echo "4. Add the existing test files to the target:"
echo "   • Select 'MurmurUITests/MurmurUITests.swift'"
echo "   • In File Inspector (right panel), check 'MurmurUITests' under Target Membership"
echo "   • Do the same for 'MurmurUITests/SnapshotHelper.swift'"
echo "   • Do the same for 'MurmurUITests/Info.plist'"
echo ""
echo "5. Verify the scheme:"
echo "   • Product > Scheme > MurmurUITests"
echo "   • Ensure it tests the Murmur app"
echo ""
echo "6. Build the project:"
echo "   • Product > Build (⌘B)"
echo ""
echo "7. Run screenshot generation:"
echo "   • cd fastlane"
echo "   • fastlane screenshots"
echo ""
echo "📖 For more details, see SCREENSHOTS.md"
echo ""

# Check required simulators
echo "📱 Checking for required simulators..."
echo ""

REQUIRED_SIMS=("iPhone 17 Pro Max" "iPad Pro 13-inch (M4)")

for sim in "${REQUIRED_SIMS[@]}"; do
    if xcrun simctl list devices | grep -q "$sim"; then
        echo "✅ Found simulator: $sim"
    else
        echo "⚠️  Missing simulator: $sim"
        echo "   Install it from Xcode > Settings > Platforms"
    fi
done

echo ""
echo "Checking for iOS/iPadOS 26.0..."
if xcrun simctl list devices | grep -q "26.0"; then
    echo "✅ Found iOS/iPadOS 26.0 runtime"
else
    echo "⚠️  Missing iOS/iPadOS 26.0 runtime"
    echo "   Install it from Xcode > Settings > Platforms"
fi

echo ""
echo "✨ Setup script complete!"
echo ""
echo "Run the following to test screenshot generation manually:"
echo ""
echo "  cd fastlane && fastlane screenshots"
echo ""
