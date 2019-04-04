//
//	NetworkDataRequest.swift
//	Places Near
//
//	Created by Michael Valentiner on 3/15/19.
//	Copyright © 2019 Michael Valentiner. All rights reserved.
//
//	Inspired by http://matteomanferdini.com/network-requests-rest-apis-ios-swift/
//

import PromiseKit
import PMKFoundation
import UIKit

//** Result type returned from DataRequests
enum DataRequestResult<RequestedDataType> {
	case success(RequestedDataType)
	case failure(DataRequestError, Data?)
	// Constructs a .success wrapping a `value`.
	internal init(success : RequestedDataType) {
		self = .success(success)
	}
	// Constructs a .failure wrapping an `error`.
	internal init(error : Error, data : Data? = nil) {
		self = .failure(.sessionDataTaskError(error), data)
	}
}

//** Error types for DataRequestResult
enum DataRequestError: Error {
	case decodeError
	case sessionDataTaskError(Error)
	internal init(error: Error) {
		self = .sessionDataTaskError(error)
	}
}

//** UnauthenticatedDataRequest - generic http request to request json data of associated type <RequestedDataType>
protocol UnauthenticatedDataRequest : class {
	// 1) Define the type of data being requested.
	associatedtype RequestedDataType : Decodable
	// 2) Define the endpoint to call.
	var endpointURL : String { get }
	// 3) Request the data.
	func load() throws -> Promise<RequestedDataType>

	// Extension point
	func makeRequest(for url: URL) -> URLRequest
}

extension UnauthenticatedDataRequest {
	internal func load() throws -> Promise<RequestedDataType> {
        guard let url = URL(string: endpointURL) else {
            fatalError(#function + "Could not make url from \(endpointURL)")
        }
		let request = makeRequest(for: url)
		return try sendRequest(request).map { decodedData in
			decodedData
		}
	}

	internal func makeRequest(for url: URL) -> URLRequest {
		return URLRequest(url: url)
	}
	
	internal func sendRequest(_ request: URLRequest) throws -> Promise<RequestedDataType> {
		return firstly {
			URLSession.shared.dataTask(.promise, with: request).validate()
		}.compactMap { data, response in
			try JSONDecoder().decode(RequestedDataType.self, from: data)
		}
	}
}
