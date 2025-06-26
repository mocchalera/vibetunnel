import Observation
import SwiftUI

/// View for establishing connection to a VibeTunnel server.
///
/// Displays the app branding and provides interface for entering
/// server connection details with saved server management.
struct ConnectionView: View {
    @Environment(ConnectionManager.self)
    var connectionManager
    @State private var networkMonitor = NetworkMonitor.shared
    @State private var viewModel = ConnectionViewModel()
    @State private var logoScale: CGFloat = 0.8
    @State private var contentOpacity: Double = 0

    var body: some View {
        NavigationStack {
            ScrollView {
                // Content
                VStack(spacing: Theme.Spacing.extraExtraLarge) {
                    // Logo and Title
                    VStack(spacing: Theme.Spacing.large) {
                        ZStack {
                            // Glow effect
                            Image(systemName: "terminal.fill")
                                .font(.system(size: 80))
                                .foregroundColor(Theme.Colors.primaryAccent)
                                .blur(radius: 20)
                                .opacity(0.5)

                            // Main icon
                            Image(systemName: "terminal.fill")
                                .font(.system(size: 80))
                                .foregroundColor(Theme.Colors.primaryAccent)
                                .glowEffect()
                        }
                        .scaleEffect(logoScale)
                        .onAppear {
                            withAnimation(Theme.Animation.smooth.delay(0.1)) {
                                logoScale = 1.0
                            }
                        }

                        VStack(spacing: Theme.Spacing.small) {
                            Text("VibeTunnel")
                                .font(.system(size: 42, weight: .bold, design: .rounded))
                                .foregroundColor(Theme.Colors.terminalForeground)

                            Text("Terminal Multiplexer")
                                .font(Theme.Typography.terminalSystem(size: 16))
                                .foregroundColor(Theme.Colors.terminalForeground.opacity(0.7))
                                .tracking(2)

                            // Network status
                            ConnectionStatusView()
                                .padding(.top, Theme.Spacing.small)
                        }
                    }
                    .padding(.top, 60)

                    // Connection Form
                    ServerConfigForm(
                        host: $viewModel.host,
                        port: $viewModel.port,
                        name: $viewModel.name,
                        password: $viewModel.password,
                        isConnecting: viewModel.isConnecting,
                        errorMessage: viewModel.errorMessage,
                        onConnect: connectToServer
                    )
                    .opacity(contentOpacity)
                    .onAppear {
                        withAnimation(Theme.Animation.smooth.delay(0.3)) {
                            contentOpacity = 1.0
                        }
                    }

                    Spacer()
                }
                .padding()
            }
            .scrollBounceBehavior(.basedOnSize)
            .toolbar(.hidden, for: .navigationBar)
            .background {
                // Background
                Theme.Colors.terminalBackground
                    .ignoresSafeArea()
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .preferredColorScheme(.dark)
        .onAppear {
            viewModel.loadLastConnection()
        }
        .sheet(isPresented: $viewModel.showLoginView) {
            if let config = viewModel.pendingServerConfig,
               let authService = connectionManager.authenticationService {
                LoginView(
                    isPresented: $viewModel.showLoginView,
                    serverConfig: config,
                    authenticationService: authService
                )                    {
                        // Authentication successful, mark as connected
                        connectionManager.isConnected = true
                    }
            }
        }
    }

    private func connectToServer() {
        guard networkMonitor.isConnected else {
            viewModel.errorMessage = "インターネット接続がありません"
            return
        }

        Task {
            await viewModel.testConnection { config in
                connectionManager.saveConnection(config)
                // Show login view to authenticate
                viewModel.showLoginView = true
            }
        }
    }
}

/// View model for managing connection form state and validation.
@Observable
class ConnectionViewModel {
    var host: String = "127.0.0.1"
    var port: String = "4020"
    var name: String = ""
    var password: String = ""
    var isConnecting: Bool = false
    var errorMessage: String?
    var showLoginView: Bool = false
    var pendingServerConfig: ServerConfig?

    func loadLastConnection() {
        if let config = UserDefaults.standard.data(forKey: "savedServerConfig"),
           let serverConfig = try? JSONDecoder().decode(ServerConfig.self, from: config)
        {
            self.host = serverConfig.host
            self.port = String(serverConfig.port)
            self.name = serverConfig.name ?? ""
        }
    }

    @MainActor
    func testConnection(onSuccess: @escaping (ServerConfig) -> Void) async {
        errorMessage = nil

        guard !host.isEmpty else {
            errorMessage = "サーバーアドレスを入力してください"
            return
        }

        guard let portNumber = Int(port), portNumber > 0, portNumber <= 65_535 else {
            errorMessage = "有効なポート番号を入力してください"
            return
        }

        isConnecting = true
        
        print("🔵 === VibeTunnel 接続デバッグ開始 ===")
        print("🔵 ホスト: \(host)")
        print("🔵 ポート: \(port)")
        print("🔵 タイムスタンプ: \(Date())")

        let config = ServerConfig(
            host: host,
            port: portNumber,
            name: name.isEmpty ? nil : name
        )
        
        print("🔵 接続URL: \(config.baseURL)")

        do {
            // Test basic connectivity by checking health endpoint
            let url = config.baseURL.appendingPathComponent("api/health")
            print("🔵 ヘルスチェックURL: \(url)")
            let request = URLRequest(url: url)
            print("🔵 URLリクエスト送信中...")
            let (_, response) = try await URLSession.shared.data(for: request)
            
            print("🔵 レスポンス受信: \(response)")

            if let httpResponse = response as? HTTPURLResponse,
               httpResponse.statusCode == 200
            {
                print("✅ 接続成功！")
                // Connection successful, save config and trigger authentication
                pendingServerConfig = config
                onSuccess(config)
            } else {
                print("🔴 HTTPステータスエラー: \((response as? HTTPURLResponse)?.statusCode ?? -1)")
                errorMessage = "サーバーへの接続に失敗しました"
            }
        } catch {
            print("🔴 エラーキャッチ: \(error)")
            print("🔴 エラータイプ: \(type(of: error))")
            
            if let urlError = error as? URLError {
                print("🔴 URLErrorコード: \(urlError.code.rawValue)")
                switch urlError.code {
                case .notConnectedToInternet:
                    errorMessage = "インターネット接続がありません"
                case .cannotFindHost:
                    errorMessage = "サーバーが見つかりません"
                case .cannotConnectToHost:
                    errorMessage = "サーバーに接続できません"
                case .timedOut:
                    errorMessage = "接続がタイムアウトしました"
                default:
                    errorMessage = "接続失敗: \(error.localizedDescription)"
                }
            } else {
                errorMessage = "接続失敗: \(error.localizedDescription)"
            }
            print("🔴 最終エラーメッセージ: \(errorMessage ?? "nil")")
        }

        isConnecting = false
    }
}
