// Audio service for text-to-speech and speech-to-text using Web Speech API

class AudioService {
  constructor() {
    // Check if we're in a browser environment
    if (typeof window === 'undefined') {
      this.synth = null;
      this.recognition = null;
      this.isSpeaking = false;
      this.isListening = false;
      this.currentUtterance = null;
      return;
    }
    
    this.synth = window.speechSynthesis;
    this.recognition = null;
    this.isSpeaking = false;
    this.isListening = false;
    this.currentUtterance = null;
    
    // Initialize speech recognition if available
    if ('webkitSpeechRecognition' in window || 'SpeechRecognition' in window) {
      const SpeechRecognition = window.SpeechRecognition || window.webkitSpeechRecognition;
      this.recognition = new SpeechRecognition();
      this.recognition.continuous = false;
      this.recognition.interimResults = false;
      this.recognition.lang = 'en-US';
      
      this.recognition.onstart = () => {
        this.isListening = true;
        if (this.onListeningStart) this.onListeningStart();
      };
      
      this.recognition.onresult = (event) => {
        const transcript = event.results[0][0].transcript;
        if (this.onResult) this.onResult(transcript);
      };
      
      this.recognition.onerror = (event) => {
        this.isListening = false;
        if (this.onError) this.onError(event.error);
      };
      
      this.recognition.onend = () => {
        this.isListening = false;
        if (this.onListeningEnd) this.onListeningEnd();
      };
    }
  }
  
  // Text-to-Speech
  speak(text, options = {}) {
    this.stopSpeaking();
    
    if (!this.synth) {
      console.warn('Speech synthesis not supported');
      return;
    }
    
    const utterance = new SpeechSynthesisUtterance(text);
    utterance.lang = options.lang || 'en-US';
    utterance.rate = options.rate || 0.8;
    utterance.pitch = options.pitch || 1.0;
    utterance.volume = options.volume || 1.0;
    
    utterance.onstart = () => {
      this.isSpeaking = true;
      if (this.onSpeakingStart) this.onSpeakingStart();
    };
    
    utterance.onend = () => {
      this.isSpeaking = false;
      if (this.onSpeakingEnd) this.onSpeakingEnd();
    };
    
    utterance.onerror = (event) => {
      this.isSpeaking = false;
      if (this.onError) this.onError(event.error);
    };
    
    this.currentUtterance = utterance;
    this.synth.speak(utterance);
  }
  
  stopSpeaking() {
    if (this.synth && this.synth.speaking) {
      this.synth.cancel();
    }
    this.isSpeaking = false;
    this.currentUtterance = null;
  }
  
  // Speech-to-Text
  startListening() {
    if (!this.recognition) {
      if (this.onError) {
        this.onError('Speech recognition not supported in this browser');
      }
      return;
    }
    
    try {
      this.recognition.start();
    } catch (error) {
      if (this.onError) this.onError(error.message);
    }
  }
  
  stopListening() {
    if (this.recognition && this.isListening) {
      this.recognition.stop();
    }
    this.isListening = false;
  }
  
  // Check if speech recognition is available
  isSpeechRecognitionAvailable() {
    return 'webkitSpeechRecognition' in window || 'SpeechRecognition' in window;
  }
  
  // Check if speech synthesis is available
  isSpeechSynthesisAvailable() {
    return 'speechSynthesis' in window;
  }
}

// Create singleton instance
const audioService = new AudioService();

export default audioService;
