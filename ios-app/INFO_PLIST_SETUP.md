# iOS Info.plist Setup for Audio Features

To enable speech recognition in the iOS app, you need to add the following permissions to your Info.plist file.

## Required Permissions

Add these keys to your `Info.plist` file (or in Xcode's Info tab):

### 1. Speech Recognition Permission
```xml
<key>NSSpeechRecognitionUsageDescription</key>
<string>LunaReading needs access to speech recognition to allow you to speak your answers instead of typing them.</string>
```

### 2. Microphone Permission
```xml
<key>NSMicrophoneUsageDescription</key>
<string>LunaReading needs access to your microphone to record your voice answers.</string>
```

## How to Add in Xcode

1. Open your project in Xcode
2. Select your app target
3. Go to the "Info" tab
4. Click the "+" button to add a new key
5. Add the keys above with their descriptions

Alternatively, if you have an Info.plist file:

1. Right-click on your project in the navigator
2. Select "New File" > "Property List"
3. Name it `Info.plist` if it doesn't exist
4. Add the keys and values above

## Testing

After adding these permissions:
1. Build and run the app
2. When you first tap the microphone button, iOS will prompt for permission
3. Grant permission to enable voice input
