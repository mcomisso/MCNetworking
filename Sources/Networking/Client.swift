import Foundation
import os.log
import Network
import Observation

public enum HTTPMethod: String {
    case GET
    case POST
    case PUT
    case DELETE

    /*
     Verb    Description
     GET    Select one or more items. Success returns 200 status code.
     POST    Create a new item. Success returns 201 status code.
     PUT    Update an item. Success returns 200 status code.
     DELETE    Delete an item. Success returns 200 or 204 status code.
     */
}

public extension URLRequest {
    var method: HTTPMethod {
        get {
            HTTPMethod(rawValue: httpMethod ?? "GET")!
        }
        set {
            self.httpMethod = newValue.rawValue
        }
    }
}

extension Client {
    enum Status: String {
        case reachable
        case unreachable
    }
}

@Observable
public final class Client: ObservableObject, Sendable {

    public static let shared: Client = .init()

    private var pathMonitor = NWPathMonitor()
    private var networkStatus: Status = .reachable

    private let logger = Logger(subsystem: "com.mcomisso.untitledStreamingApp", category: "Client")
    private let session: URLSession

    public init(sessionConfiguration: URLSessionConfiguration = .default) {
        self.session = URLSession(configuration: sessionConfiguration)

        pathMonitor.pathUpdateHandler = { [weak self] path in
            switch path.status {
                case .satisfied:
                    self?.networkStatus = .reachable
                default:
                    self?.networkStatus = .unreachable
            }
        }
    }

    public func request<T: RequestResponseCapsule>(_ requestResponse: T) async throws -> T.ResponseType {
        let urlRequest = try requestResponse.makeRequest()
        let data = try await request(urlRequest)

        return try requestResponse.parse(data)
    }

    public func request(_ request: URLRequest, validRange: Range<Int> = 200..<400) async throws -> Data {
        var mutableRequest = request
        logger.info("\(request.url!.absoluteString)")

        mutableRequest.cachePolicy = .returnCacheDataDontLoad

        if networkStatus == .reachable {
            mutableRequest.cachePolicy = .reloadIgnoringLocalCacheData
        }

        let (data, response) = try await session.data(for: mutableRequest)

        guard let response = response as? HTTPURLResponse else {
            throw URLError(.cannotParseResponse)
        }

        guard validRange.contains(response.statusCode) else {
            throw ClientNetworkError.invalidStatusCode(response.statusCode)
        }

        logger.info("Status code: \(response.statusCode)")
        return data
    }
}

// MARK: - Background Requests

extension Client {

    private func backgroundRequest(_ request: URLRequest) async throws -> Data {
        logger.info("Background: \(request.url!.absoluteString)")

        let task = session.dataTask(with: request)
        task.resume()

        try await Task.sleep(for: .seconds(5))
        return Data()
    }

    public func backgroundRequest<T: RequestResponseCapsule>(_ requestResponse: T) async throws ->T.ResponseType {
        let urlRequest = try requestResponse.makeRequest()
        let data = try await backgroundRequest(urlRequest)
        
        return try requestResponse.parse(data)
    }
}

extension Client {
    public enum ClientNetworkError: Error {
        case invalidStatusCode(Int)
    }
}
