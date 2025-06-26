#!/bin/bash

echo "VibeTunnel iOS Voice Features Build Test"
echo "========================================"

# Check if we're in the iOS directory
if [ ! -f "VibeTunnel-iOS.xcodeproj/project.pbxproj" ]; then
    echo "Error: Not in iOS project directory"
    exit 1
fi

# List the voice-related files we've created/modified
echo "Voice feature files:"
echo "- Services/SpeechRecognitionService.swift"
echo "- Services/TextToSpeechService.swift"
echo "- Services/BackgroundVoiceService.swift"
echo "- Views/Components/HandsFreeIndicator.swift"
echo "- App/AppDelegate.swift"

# Check if files exist
for file in \
    "VibeTunnel/Services/SpeechRecognitionService.swift" \
    "VibeTunnel/Services/TextToSpeechService.swift" \
    "VibeTunnel/Services/BackgroundVoiceService.swift" \
    "VibeTunnel/Views/Components/HandsFreeIndicator.swift" \
    "VibeTunnel/App/AppDelegate.swift"
do
    if [ -f "$file" ]; then
        echo "✓ $file exists"
    else
        echo "✗ $file missing"
    fi
done

echo ""
echo "Info.plist permissions:"
grep -A1 "NSMicrophoneUsageDescription\|NSSpeechRecognitionUsageDescription\|UIBackgroundModes" VibeTunnel/Resources/Info.plist || echo "Permissions not found"

echo ""
echo "To build in Xcode:"
echo "1. Open VibeTunnel-iOS.xcodeproj"
echo "2. Select your iPhone device or simulator"
echo "3. Press Cmd+B to build"
echo "4. Fix any compilation errors"
echo "5. Run on device to test voice features"
echo ""
echo "Voice Features Summary:"
echo "- Voice input button in terminal toolbar"
echo "- Japanese UI localization"
echo "- Background voice recognition"
echo "- Hands-free mode with floating indicator"
echo "- Auto-speak terminal output"
echo "- Voice commands for navigation and development"