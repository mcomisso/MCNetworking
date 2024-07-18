import Foundation

public typealias RequestResponseCapsule = ResponseParser & RequestMaker

public protocol ResponseParser<ResponseType> where ResponseType: Decodable {
    associatedtype ResponseType

    func parse(_ responseData: Data) throws -> ResponseType
}

public protocol RequestMaker {
    func makeRequest() throws -> URLRequest
}
