import Foundation
import AVFoundation

@Observable
class TextToSpeechService: NSObject {
    private let synthesizer = AVSpeechSynthesizer()
    
    var isSpeaking: Bool {
        synthesizer.isSpeaking
    }
    
    var isPaused: Bool {
        synthesizer.isPaused
    }
    
    var speechRate: Float = 0.5
    var volume: Float = 1.0
    var pitch: Float = 1.0
    var language = "ja-JP"
    
    override init() {
        super.init()
        synthesizer.delegate = self
        
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio, options: .duckOthers)
        } catch {
            print("Failed to set audio session category: \(error)")
        }
    }
    
    func speak(_ text: String) {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        
        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = speechRate
        utterance.volume = volume
        utterance.pitchMultiplier = pitch
        utterance.voice = AVSpeechSynthesisVoice(language: language)
        
        synthesizer.speak(utterance)
    }
    
    func speakLastLine(from text: String) {
        let lines = text.components(separatedBy: .newlines)
        if let lastLine = lines.last(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty }) {
            speak(lastLine)
        }
    }
    
    func speakSelection(_ text: String) {
        let cleanedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if !cleanedText.isEmpty {
            speak(cleanedText)
        }
    }
    
    func pause() {
        if synthesizer.isSpeaking && !synthesizer.isPaused {
            synthesizer.pauseSpeaking(at: .immediate)
        }
    }
    
    func resume() {
        if synthesizer.isPaused {
            synthesizer.continueSpeaking()
        }
    }
    
    func stop() {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
    }
    
    func toggleSpeaking() {
        if synthesizer.isSpeaking {
            if synthesizer.isPaused {
                resume()
            } else {
                pause()
            }
        }
    }
}

extension TextToSpeechService: AVSpeechSynthesizerDelegate {
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        print("Started speaking")
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        print("Finished speaking")
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didPause utterance: AVSpeechUtterance) {
        print("Paused speaking")
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didContinue utterance: AVSpeechUtterance) {
        print("Resumed speaking")
    }
}