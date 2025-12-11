# Audio Features Documentation

## Overview

Both the iOS app and web frontend now support audio input and output features for an enhanced user experience, especially helpful for younger students learning to read.

## Features

### Text-to-Speech (Audio Output)
- **Question Reading**: Users can tap a speaker icon to hear questions read aloud
- **Feedback Reading**: Users can hear feedback read aloud after submitting answers
- **Consistent UX**: Same button placement and behavior across iOS and web

### Speech-to-Text (Audio Input)
- **Voice Answers**: Users can speak their answers instead of typing
- **Real-time Transcription**: Speech is converted to text and inserted into the answer field
- **Visual Feedback**: Microphone button shows listening state

## iOS Implementation

### AudioService
- Uses `AVSpeechSynthesizer` for text-to-speech
- Uses `Speech` framework for speech recognition
- Handles permissions and audio session management
- Singleton pattern for consistent state across views

### Permissions Required
- `NSSpeechRecognitionUsageDescription`: For speech-to-text
- `NSMicrophoneUsageDescription`: For microphone access

See `ios-app/INFO_PLIST_SETUP.md` for setup instructions.

### UI Elements
- Speaker icon (🔊) next to questions and feedback for TTS
- Microphone icon (🎤) next to answer input for voice input
- Visual indicators when speaking/listening

## Frontend Implementation

### AudioService
- Uses Web Speech API (`speechSynthesis` and `SpeechRecognition`)
- Cross-browser compatibility (Chrome, Edge, Safari)
- Graceful fallback for unsupported browsers

### Browser Support
- **Text-to-Speech**: Supported in all modern browsers
- **Speech Recognition**: 
  - ✅ Chrome/Edge (full support)
  - ✅ Safari (limited support)
  - ❌ Firefox (not supported)

### UI Elements
- Speaker emoji (🔊) button for TTS
- Microphone emoji (🎤) button for voice input
- Visual feedback during listening/speaking states

## User Experience Consistency

### Button Placement
- **Question TTS**: Top-right of question text
- **Feedback TTS**: Top-right of feedback section
- **Voice Input**: Top-right of answer input field

### Visual States
- **Idle**: Default icon color
- **Active (Speaking)**: Stop icon (⏸️) or different color
- **Active (Listening)**: Red color or "Listening..." text

### Behavior
- Tapping TTS button while speaking stops playback
- Tapping microphone while listening stops recording
- Speech recognition automatically stops after result or timeout
- Text is inserted into answer field automatically

## Usage Examples

### iOS
```swift
// Text-to-Speech
audioService.speak("What is the main idea of this chapter?")

// Speech-to-Text
audioService.startListening { text, error in
    if let text = text {
        // Use transcribed text
    }
}
```

### Frontend
```javascript
// Text-to-Speech
audioService.speak("What is the main idea of this chapter?");

// Speech-to-Text
audioService.startListening();
audioService.onResult = (transcript) => {
    // Use transcribed text
};
```

## Accessibility Benefits

- Helps students with reading difficulties
- Supports auditory learners
- Reduces typing burden for younger students
- Improves engagement and accessibility

## Future Enhancements

Potential improvements:
- Adjustable speech rate
- Multiple language support
- Voice commands for navigation
- Audio playback of example answers
- Offline speech recognition (iOS)
