//
//  GooglePlaceService.swift
//  Places
//
//  Created by Michael Valentiner on 4/7/19.
//  Copyright © 2019 Michael Valentiner. All rights reserved.
//

import CoreLocation
import Foundation
import GooglePlaces

private struct GooglePlaceServiceName {
	static let serviceName = "GooglePlaceService"
}

extension ServiceRegistry {
	var googlePlaceService : GooglePlaceService {
		get {
			return serviceWith(name: GooglePlaceServiceName.serviceName) as! GooglePlaceService	// Intentional force unwrapping
		}
	}
}

//** GooglePlaceService - public interface
protocol GooglePlaceService : Service {
	func getPlaces(forSearchText searchText: String, completionHandler: @escaping (Place?) -> Void)
	func search(forAddress searchText: String, completionHandler: @escaping (Place?) -> Void)
}

//** GooglePlaceService - private implementation interface
protocol PrivateGooglePlaceService : GooglePlaceService {
	var apiKey : String { get }
	var googlePlaceSourceUID : String { get }
	var sessionToken : GMSAutocompleteSessionToken { get }
}

//** GooglePlaceService - default implementation
extension PrivateGooglePlaceService {
	var serviceName : String {
		get {
			return GooglePlaceServiceName.serviceName
		}
	}

	var googlePlaceSourceUID : String {
		get {
			return "GooglePlaceSourceId"
		}
	}

	var sessionToken : GMSAutocompleteSessionToken {
		get {
			return GMSAutocompleteSessionToken.init()
		}
	}

	internal func getPlaces(forSearchText searchText: String, completionHandler: @escaping (Place?) -> Void) {
		let filter = GMSAutocompleteFilter()
		filter.type = .establishment
		GMSPlacesClient.shared().findAutocompletePredictions(fromQuery: searchText, bounds: nil, boundsMode: GMSAutocompleteBoundsMode.bias,
				filter: filter, sessionToken: self.sessionToken) { (results, error) in
			guard error == nil else {
//				print("Autocomplete error == \(String(describing: error))")
				return
			}
			guard let results = results else {
				completionHandler(nil)
				return
			}
			results.forEach { (prediction) in
				self.makePlace(from: prediction, completionHandler: completionHandler)
			}
		}
	}

	private func makePlace(from prediction: GMSAutocompletePrediction, completionHandler: @escaping (Place?) -> Void) {
		let placeId = prediction.placeID
		GMSPlacesClient.shared().fetchPlace(fromPlaceID: placeId, placeFields: GMSPlaceField.coordinate, sessionToken: self.sessionToken) { (place, error) in
			guard error == nil else {
				completionHandler(nil)
				return
			}
			guard let place = place else {
				completionHandler(nil)
				return
			}
			let coordinate = place.coordinate
			let placeUID = PlaceUID(placeSourceUID: self.googlePlaceSourceUID, nativePlaceId: prediction.placeID)
			completionHandler(Place(uid: placeUID, location: coordinate, title: prediction.attributedFullText.string))
		}
	}

	func search(forAddress searchText: String, completionHandler: @escaping (Place?) -> Void) {
		do {
			let request = try GoogleGeocodingRequest(withSearchText: searchText, apiKey: self.apiKey)
			try request.load().done { (json) in
				guard let status = json["status"]?.stringValue, status == "OK" else {
					completionHandler(nil)
					return
				}
				guard let results = json["results"]?.arrayValue else {
					completionHandler(nil)
					return
				}
				results.forEach { (json) in
					guard let formattedAddress = json["formatted_address"]?.stringValue, formattedAddress != "" else {
						completionHandler(nil)
						return
					}
					guard let location = json["geometry"]?["location"]?.objectValue,
							let lat = location["lat"]?.floatValue, let lon = location["lng"]?.floatValue else {
						completionHandler(nil)
						return
					}
					guard let placeId = json["place_id"]?.stringValue else {
						completionHandler(nil)
						return
					}
					let placeUId = PlaceUID(placeSourceUID: self.googlePlaceSourceUID, nativePlaceId: placeId)
					let coordinate = CLLocationCoordinate2D(latitude: Double(lat), longitude: Double(lon))
					let place = Place(uid: placeUId, location: coordinate, title: formattedAddress)
					completionHandler(place)
				}
			}.catch { error in
				completionHandler(nil)
			}
		}
		catch {
			completionHandler(nil)
		}
	}
}

internal class GooglePlaceServiceImplementation : PrivateGooglePlaceService {
	let apiKey = "<replace with your api key here>"

	static func register() {
		SR.add(service: GooglePlaceServiceImplementation())
	}
	
	init() {
		GMSPlacesClient.provideAPIKey(self.apiKey)
	}
}

enum GoogleGeocodingRequestError : Error {
	case searchTextEncodingError
}

private class GoogleGeocodingRequest : UnauthenticatedDataRequest {
	typealias RequestedDataType = JSON
	var endpointURL : String {
		get {
			return "https://maps.googleapis.com/maps/api/geocode/json?\(queryParams)"
		}
	}

	private let apiKey : String
	private let queryParams : String

	init(withSearchText searchText: String, apiKey: String) throws {
		self.apiKey = apiKey
		let replacementSearchText = searchText.replacingOccurrences(of: " ", with: "+")
		guard let queryParams = "address=\(replacementSearchText)&key=\(apiKey)".addingPercentEncoding(withAllowedCharacters: CharacterSet.urlQueryAllowed) else {
			throw GoogleGeocodingRequestError.searchTextEncodingError
		}
		self.queryParams = queryParams
	}
}

internal class GooglePlaceServiceMockImplementation : PrivateGooglePlaceService {
	var apiKey: String = ""
	
	static func register() {
		SR.add(service: self.init())
	}

	required init() {
//		GMSPlacesClient.provideAPIKey(self.apiKey)
	}

	func search(forAddress searchText: String, completionHandler: @escaping (Place?) -> Void) {
		do {
			let jsonDict = [
				"results" : [
					[
						"formatted_address" : "1600 Amphitheatre Parkway, Mountain View, CA 94043, USA",
							"geometry" : [
							"location" : [
								"lat" : 37.4224764,
								"lng" : -122.0842499
							],
						],
						"place_id" : "ChIJ2eUgeAK6j4ARbn5u_wAGqWA",
						"types" : [ "street_address" ]
					]
				],
				"status" : "OK"
			] as [String : JSON]
			let jsonEncoder = JSONEncoder()
			let jsonData = try! jsonEncoder.encode(jsonDict)
			let json = try JSONDecoder().decode(JSON.self, from: jsonData)

			guard let status = json["status"]?.stringValue, status == "OK" else {
				completionHandler(nil)
				return
			}
			guard let results = json["results"]?.arrayValue else {
				completionHandler(nil)
				return
			}
			results.forEach { (json) in
				guard let formattedAddress = json["formatted_address"]?.stringValue, formattedAddress != "" else {
					completionHandler(nil)
					return
				}
				guard let location = json["geometry"]?["location"]?.objectValue,
						let lat = location["lat"]?.floatValue, let lon = location["lng"]?.floatValue else {
					completionHandler(nil)
					return
				}
				guard let placeId = json["place_id"]?.stringValue else {
					completionHandler(nil)
					return
				}
				let placeUId = PlaceUID(placeSourceUID: self.googlePlaceSourceUID, nativePlaceId: placeId)
				let coordinate = CLLocationCoordinate2D(latitude: Double(lat), longitude: Double(lon))
				let place = Place(uid: placeUId, location: coordinate, title: formattedAddress)
				completionHandler(place)
			}
		}
		catch {
			completionHandler(nil)
		}
	}
}
