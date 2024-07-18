import Foundation

public protocol NetworkConfiguration {

    var baseURL: URL { get }

    var requiredHeaders: [String: String] { get }

    var path: String { get }
    
    var queryItems: [URLQueryItem] { get }
    
    func makeRequest(method: HTTPMethod) -> URLRequest
}

extension NetworkConfiguration {
    public func makeRequest(method: HTTPMethod = .GET) -> URLRequest {
        let url = self.baseURL.appending(path: path)
        var components = URLComponents(url: url, resolvingAgainstBaseURL: true)!
        components.queryItems = self.queryItems

        var request = URLRequest(url: components.url!)
        request.method = method
        requiredHeaders.forEach {
            request.setValue($0.value, forHTTPHeaderField: $0.key)
        }
        return request
    }
}
