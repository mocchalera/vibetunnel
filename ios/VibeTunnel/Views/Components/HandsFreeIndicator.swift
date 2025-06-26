import SwiftUI
import AVFoundation

/// ハンズフリーモードのステータスを表示するフローティングインジケーター
struct HandsFreeIndicator: View {
    @ObservedObject var voiceService = BackgroundVoiceService.shared
    @State private var isPulsing = false
    
    var body: some View {
        if voiceService.isInBackgroundMode {
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    
                    VStack(spacing: 8) {
                        // マイクアイコンとステータス
                        ZStack {
                            Circle()
                                .fill(voiceService.isListening ? Color.green : Color.orange)
                                .frame(width: 60, height: 60)
                                .overlay(
                                    Circle()
                                        .stroke(Color.white, lineWidth: 2)
                                )
                                .shadow(color: .black.opacity(0.3), radius: 5, x: 0, y: 2)
                                .scaleEffect(isPulsing ? 1.1 : 1.0)
                                .animation(
                                    voiceService.isListening ?
                                        .easeInOut(duration: 1.0).repeatForever(autoreverses: true) :
                                        .default,
                                    value: isPulsing
                                )
                            
                            Image(systemName: voiceService.isListening ? "mic.fill" : "mic.slash.fill")
                                .font(.system(size: 24))
                                .foregroundColor(.white)
                        }
                        
                        // 現在のコマンド表示
                        if !voiceService.currentCommand.isEmpty {
                            Text(voiceService.currentCommand)
                                .font(.caption)
                                .foregroundColor(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(
                                    RoundedRectangle(cornerRadius: 15)
                                        .fill(Color.black.opacity(0.7))
                                )
                                .lineLimit(2)
                                .frame(maxWidth: 200)
                        }
                        
                        // ステータステキスト
                        Text(voiceService.isListening ? "聞いています..." : "ハンズフリーモード")
                            .font(.caption2)
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(Color.black.opacity(0.5))
                            )
                    }
                    .padding()
                }
                .padding(.bottom, 100) // ツールバーの上に表示
            }
            .allowsHitTesting(false) // タップを下のビューに通す
            .onAppear {
                isPulsing = voiceService.isListening
            }
            .onChange(of: voiceService.isListening) { _, newValue in
                isPulsing = newValue
            }
        }
    }
}

/// ハンズフリーモードのインジケーターを追加するビューモディファイア
struct HandsFreeOverlay: ViewModifier {
    func body(content: Content) -> some View {
        ZStack {
            content
            HandsFreeIndicator()
        }
    }
}

extension View {
    func handsFreeIndicator() -> some View {
        modifier(HandsFreeOverlay())
    }
}