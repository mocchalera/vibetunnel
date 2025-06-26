import Foundation
import AVFoundation
import Speech
import Combine

/// ランニング中でも使える完全ハンズフリー音声サービス
@MainActor
final class BackgroundVoiceService: NSObject, ObservableObject {
    static let shared = BackgroundVoiceService()
    
    // 音声認識
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "ja-JP"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    
    // 音声合成
    private let synthesizer = AVSpeechSynthesizer()
    
    // 状態管理
    @Published var isListening = false
    @Published var isInBackgroundMode = false
    @Published var currentCommand = ""
    @Published var lastResponse = ""
    
    // 音声コマンド
    private var voiceCommands: [String: VoiceCommand] = [:]
    
    // WebSocket接続
    private var webSocketClient: BufferWebSocketClient?
    private var currentSessionId: String?
    
    override init() {
        super.init()
        setupAudioSession()
        setupVoiceCommands()
        synthesizer.delegate = self
    }
    
    private func setupAudioSession() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            // バックグラウンドでも音声認識と再生を継続
            try audioSession.setCategory(.playAndRecord, 
                                       mode: .voiceChat,
                                       options: [.mixWithOthers, .allowBluetooth, .defaultToSpeaker])
            try audioSession.setActive(true)
            
            // バックグラウンド通知を監視
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(handleInterruption),
                name: AVAudioSession.interruptionNotification,
                object: audioSession
            )
        } catch {
            print("オーディオセッション設定エラー: \(error)")
        }
    }
    
    private func setupVoiceCommands() {
        // 基本コマンド
        voiceCommands["実行"] = VoiceCommand { [weak self] in
            self?.sendCurrentCommand()
        }
        
        voiceCommands["クリア"] = VoiceCommand { [weak self] in
            self?.currentCommand = ""
            self?.speak("コマンドをクリアしました")
        }
        
        voiceCommands["読み上げ"] = VoiceCommand { [weak self] in
            self?.readLastResponse()
        }
        
        voiceCommands["ヘルプ"] = VoiceCommand { [weak self] in
            self?.speakHelp()
        }
        
        // ナビゲーションコマンド
        voiceCommands["戻る"] = VoiceCommand { [weak self] in
            self?.speak("前のディレクトリに戻ります")
            self?.executeCommand("cd ..")
        }
        
        voiceCommands["ホーム"] = VoiceCommand { [weak self] in
            self?.speak("ホームディレクトリに移動します")
            self?.executeCommand("cd ~")
        }
        
        voiceCommands["リスト"] = VoiceCommand { [weak self] in
            self?.speak("ファイル一覧を表示します")
            self?.executeCommand("ls -la")
        }
        
        voiceCommands["上へ"] = VoiceCommand { [weak self] in
            self?.executeCommand("\u{001B}[A") // 上矢印キー
        }
        
        voiceCommands["下へ"] = VoiceCommand { [weak self] in
            self?.executeCommand("\u{001B}[B") // 下矢印キー
        }
        
        // 画面操作コマンド
        voiceCommands["スクロールアップ"] = VoiceCommand { [weak self] in
            self?.speak("上にスクロール")
            self?.executeCommand("\u{001B}[5~") // Page Up
        }
        
        voiceCommands["スクロールダウン"] = VoiceCommand { [weak self] in
            self?.speak("下にスクロール")
            self?.executeCommand("\u{001B}[6~") // Page Down
        }
        
        voiceCommands["キャンセル"] = VoiceCommand { [weak self] in
            self?.speak("処理を中断します")
            self?.executeCommand("\u{0003}") // Ctrl+C
        }
        
        voiceCommands["停止"] = VoiceCommand { [weak self] in
            self?.speak("処理を停止します")
            self?.executeCommand("\u{0003}") // Ctrl+C
        }
        
        // 開発コマンド
        voiceCommands["ステータス"] = VoiceCommand { [weak self] in
            self?.executeCommand("git status")
        }
        
        voiceCommands["差分"] = VoiceCommand { [weak self] in
            self?.executeCommand("git diff")
        }
        
        voiceCommands["ビルド"] = VoiceCommand { [weak self] in
            self?.executeCommand("npm run build")
        }
        
        voiceCommands["テスト"] = VoiceCommand { [weak self] in
            self?.executeCommand("npm test")
        }
        
        voiceCommands["実行環境"] = VoiceCommand { [weak self] in
            self?.executeCommand("npm run dev")
        }
        
        // エディタコマンド
        voiceCommands["編集"] = VoiceCommand { [weak self] in
            self?.speak("エディタを開きます")
            self?.executeCommand("vim")
        }
        
        voiceCommands["保存"] = VoiceCommand { [weak self] in
            self?.speak("保存します")
            self?.executeCommand("\u{001B}:w\n") // Vim save
        }
        
        voiceCommands["終了"] = VoiceCommand { [weak self] in
            self?.speak("エディタを終了します")
            self?.executeCommand("\u{001B}:q\n") // Vim quit
        }
    }
    
    // MARK: - Public Methods
    
    func startBackgroundMode(sessionId: String) {
        currentSessionId = sessionId
        isInBackgroundMode = true
        startListening()
        speak("ハンズフリーモードを開始しました。コマンドをどうぞ。")
    }
    
    func stopBackgroundMode() {
        isInBackgroundMode = false
        stopListening()
        speak("ハンズフリーモードを終了しました。")
    }
    
    func startListening() {
        guard !isListening else { return }
        
        do {
            try startSpeechRecognition()
            isListening = true
        } catch {
            speak("音声認識を開始できませんでした")
        }
    }
    
    func stopListening() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        
        recognitionRequest = nil
        recognitionTask = nil
        isListening = false
    }
    
    // MARK: - Private Methods
    
    private func startSpeechRecognition() throws {
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else { return }
        
        recognitionRequest.shouldReportPartialResults = true
        recognitionRequest.requiresOnDeviceRecognition = false
        
        let inputNode = audioEngine.inputNode
        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self = self else { return }
            
            if let result = result {
                self.processRecognizedText(result.bestTranscription.formattedString)
                
                if result.isFinal {
                    self.restartListeningIfNeeded()
                }
            }
            
            if error != nil {
                self.stopListening()
                if self.isInBackgroundMode {
                    // バックグラウンドモードでは自動的に再開
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                        self.startListening()
                    }
                }
            }
        }
        
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            recognitionRequest.append(buffer)
        }
        
        audioEngine.prepare()
        try audioEngine.start()
    }
    
    private func processRecognizedText(_ text: String) {
        // 音声コマンドをチェック
        for (keyword, command) in voiceCommands {
            if text.contains(keyword) {
                command.execute()
                return
            }
        }
        
        // コマンドとして蓄積
        currentCommand = text
    }
    
    private func sendCurrentCommand() {
        guard !currentCommand.isEmpty else {
            speak("コマンドが入力されていません")
            return
        }
        
        executeCommand(currentCommand)
        currentCommand = ""
    }
    
    private func executeCommand(_ command: String) {
        guard let sessionId = currentSessionId else {
            speak("セッションが接続されていません")
            return
        }
        
        speak("実行します: \(command)")
        
        Task {
            do {
                try await SessionService.shared.sendInput(to: sessionId, text: command + "\n")
            } catch {
                speak("コマンドの実行に失敗しました")
            }
        }
    }
    
    private func readLastResponse() {
        if !lastResponse.isEmpty {
            speak(lastResponse)
        } else {
            speak("読み上げる内容がありません")
        }
    }
    
    private func speakHelp() {
        let helpText = """
        基本コマンド:
        実行: 入力したコマンドを実行
        クリア: コマンドをクリア
        読み上げ: 最後の出力を読み上げ
        
        ナビゲーション:
        戻る: 前のディレクトリへ
        ホーム: ホームディレクトリへ
        リスト: ファイル一覧表示
        上へ、下へ: 履歴移動
        
        画面操作:
        スクロールアップ、スクロールダウン
        キャンセル、停止: 処理中断
        
        開発:
        ステータス、差分: Git操作
        ビルド、テスト、実行環境
        
        エディタ:
        編集、保存、終了
        """
        speak(helpText)
    }
    
    private func speak(_ text: String) {
        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = 0.5
        utterance.voice = AVSpeechSynthesisVoice(language: "ja-JP")
        synthesizer.speak(utterance)
    }
    
    private func restartListeningIfNeeded() {
        if isInBackgroundMode {
            stopListening()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.startListening()
            }
        }
    }
    
    @objc private func handleInterruption(notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            return
        }
        
        switch type {
        case .began:
            // 中断開始（電話など）
            stopListening()
        case .ended:
            // 中断終了
            if isInBackgroundMode {
                startListening()
            }
        @unknown default:
            break
        }
    }
    
    // WebSocket出力を受信して読み上げ
    func handleTerminalOutput(_ text: String) {
        lastResponse = text
        if isInBackgroundMode {
            // 制御文字を除去してクリーンなテキストを読み上げ
            let cleanedText = text.replacingOccurrences(of: "\u{001B}\\[[0-9;]*m", with: "", options: .regularExpression)
                                 .trimmingCharacters(in: .whitespacesAndNewlines)
            
            if !cleanedText.isEmpty {
                speak(cleanedText)
            }
        }
    }
}

// MARK: - AVSpeechSynthesizerDelegate

extension BackgroundVoiceService: AVSpeechSynthesizerDelegate {
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in
            // 読み上げ完了後、音声認識を再開
            if isInBackgroundMode && !isListening {
                startListening()
            }
        }
    }
}

// MARK: - VoiceCommand

struct VoiceCommand {
    let execute: () -> Void
}