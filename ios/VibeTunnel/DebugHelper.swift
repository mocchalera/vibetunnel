import Foundation
import os

/// デバッグ用ヘルパー
struct DebugHelper {
    static let logger = Logger(subsystem: "com.vibetunnel", category: "Debug")
    
    /// ネットワーク接続のデバッグ情報を出力
    static func logNetworkConnection(_ address: String) {
        #if DEBUG
        logger.debug("=== ネットワーク接続デバッグ ===")
        logger.debug("接続先: \(address)")
        logger.debug("タイムスタンプ: \(Date())")
        
        #if targetEnvironment(simulator)
        logger.debug("環境: iOS Simulator")
        logger.debug("ホストマシン接続可能: localhost, 127.0.0.1")
        #else
        logger.debug("環境: 実機")
        #endif
        
        // スタックトレース
        logger.debug("呼び出し元: \(Thread.callStackSymbols[1...3].joined(separator: "\n"))")
        #endif
    }
    
    /// WebSocket接続のデバッグ
    static func logWebSocketEvent(_ event: String, data: Any? = nil) {
        #if DEBUG
        logger.debug("WebSocket: \(event)")
        if let data = data {
            logger.debug("データ: \(String(describing: data))")
        }
        #endif
    }
    
    /// クラッシュ前の状態を記録
    static func logCriticalState(_ description: String, file: String = #file, line: Int = #line) {
        logger.fault("⚠️ クリティカル: \(description) [\(file):\(line)]")
    }
}

// 使用例
extension APIClient {
    func debugConnect(to address: String) async throws {
        DebugHelper.logNetworkConnection(address)
        
        do {
            // 実際の接続処理
            try await connect(to: address)
        } catch {
            DebugHelper.logCriticalState("接続失敗: \(error)")
            throw error
        }
    }
}