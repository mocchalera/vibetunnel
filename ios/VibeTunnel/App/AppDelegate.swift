import UIKit
import BackgroundTasks
import AVFoundation

class AppDelegate: NSObject, UIApplicationDelegate {
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        // バックグラウンドタスクの登録
        registerBackgroundTasks()
        
        // オーディオセッションの設定
        configureAudioSession()
        
        return true
    }
    
    private func registerBackgroundTasks() {
        // バックグラウンドでの音声認識継続
        BGTaskScheduler.shared.register(forTaskWithIdentifier: "com.vibetunnel.voiceprocessing", using: nil) { task in
            self.handleVoiceProcessing(task: task as! BGProcessingTask)
        }
    }
    
    private func configureAudioSession() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playAndRecord,
                                       mode: .voiceChat,
                                       options: [.mixWithOthers, .allowBluetooth, .defaultToSpeaker])
            try audioSession.setActive(true)
        } catch {
            print("Failed to configure audio session: \(error)")
        }
    }
    
    private func handleVoiceProcessing(task: BGProcessingTask) {
        // バックグラウンドでの音声処理
        task.expirationHandler = {
            // タスクの期限切れ処理
            task.setTaskCompleted(success: false)
        }
        
        // バックグラウンド音声サービスの継続
        if BackgroundVoiceService.shared.isInBackgroundMode {
            BackgroundVoiceService.shared.startListening()
        }
        
        task.setTaskCompleted(success: true)
        
        // 次のバックグラウンドタスクをスケジュール
        scheduleVoiceProcessing()
    }
    
    func applicationDidEnterBackground(_ application: UIApplication) {
        // バックグラウンドに入った時の処理
        scheduleVoiceProcessing()
        
        // バックグラウンドタスクの開始
        var backgroundTask: UIBackgroundTaskIdentifier = .invalid
        backgroundTask = application.beginBackgroundTask {
            application.endBackgroundTask(backgroundTask)
        }
        
        // ハンズフリーモードの場合は音声認識を継続
        if BackgroundVoiceService.shared.isInBackgroundMode {
            print("Continuing voice recognition in background...")
        }
    }
    
    private func scheduleVoiceProcessing() {
        let request = BGProcessingTaskRequest(identifier: "com.vibetunnel.voiceprocessing")
        request.requiresNetworkConnectivity = true
        request.requiresExternalPower = false
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60) // 15分後
        
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            print("Could not schedule voice processing: \(error)")
        }
    }
}