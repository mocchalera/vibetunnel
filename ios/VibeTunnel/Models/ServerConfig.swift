import Foundation

/// Configuration for connecting to a VibeTunnel server.
///
/// ServerConfig stores all necessary information to establish
/// a connection to a VibeTunnel server, including host, port,
/// optional authentication, and display name.
struct ServerConfig: Codable, Equatable {
    let host: String
    let port: Int
    let name: String?

    init(
        host: String,
        port: Int,
        name: String? = nil
    ) {
        self.host = host
        self.port = port
        self.name = name
    }

    /// Constructs the base URL for API requests.
    ///
    /// - Returns: A URL constructed from the host and port.
    ///
    /// The URL uses HTTP protocol. If URL construction fails
    /// (which should not happen with valid host/port), returns
    /// a file URL as fallback to ensure non-nil return.
    var baseURL: URL {
        // Handle IPv6 addresses by wrapping in brackets
        let formattedHost = host.contains(":") && !host.hasPrefix("[") ? "[\(host)]" : host
        
        // HTTPとHTTPSの両方に対応
        let urlString: String
        if host.hasPrefix("http://") || host.hasPrefix("https://") {
            // すでにプロトコルが含まれている場合
            urlString = "\(host):\(port)"
        } else {
            // プロトコルがない場合はhttpを追加
            urlString = "http://\(formattedHost):\(port)"
        }
        
        guard let url = URL(string: urlString) else {
            print("⚠️ 無効なURL: \(urlString)")
            return URL(fileURLWithPath: "/")
        }
        
        return url
    }

    /// User-friendly display name for the server.
    ///
    /// Returns the custom name if set, otherwise formats
    /// the host and port as "host:port".
    var displayName: String {
        name ?? "\(host):\(port)"
    }

    /// Creates a URL for an API endpoint path.
    ///
    /// - Parameter path: The API path (e.g., "/api/sessions")
    /// - Returns: A complete URL for the API endpoint
    func apiURL(path: String) -> URL {
        baseURL.appendingPathComponent(path)
    }
    
    /// Unique identifier for this server configuration.
    ///
    /// Used for keychain storage and identifying server instances.
    var id: String {
        "\(host):\(port)"
    }
}
