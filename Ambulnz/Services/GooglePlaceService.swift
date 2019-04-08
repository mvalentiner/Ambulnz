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
	func getPlaces(forSearchText : String, completionHandler : @escaping ([Place]) -> Void)
}

//** GooglePlaceService - private implementation interface
protocol PrivateGooglePlaceService : GooglePlaceService {
	var apiKey : String { get }
	var googlePlaceSourceUID : String { get }
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

	internal func getPlaces(forSearchText searchText: String, completionHandler: @escaping ([Place]) -> Void) {
		let placesClient = GMSPlacesClient.shared()
		let filter = GMSAutocompleteFilter()
		filter.type = .establishment
		let token = GMSAutocompleteSessionToken.init()
		placesClient.findAutocompletePredictions(fromQuery: searchText, bounds: nil, boundsMode: GMSAutocompleteBoundsMode.bias,
				filter: filter, sessionToken: token) { (results, error) in
			guard error == nil else {
				print("Autocomplete error == \(String(describing: error))")
				return
			}
			guard let results = results else {
				completionHandler([])
				return
			}
			let places = results.map { (prediction) -> Place in
				self.makePlace(from: prediction)
			}
			completionHandler(places)
		}
	}

	private func makePlace(from prediction: GMSAutocompletePrediction) -> Place {
		let placeUID = PlaceUID(placeSourceUID: self.googlePlaceSourceUID, nativePlaceId: prediction.placeID)
		return Place(uid: placeUID, location: CLLocationCoordinate2D(), title: prediction.attributedFullText.string)
	}
}

internal class GooglePlaceServiceImplementation : PrivateGooglePlaceService {
	let apiKey = "AIzaSyCmh0opHRdyjL_a5gizLINf8PVaIocnW8g"

	static func register() {
		SR.add(service: GooglePlaceServiceImplementation())
	}
	
	init() {
		GMSPlacesClient.provideAPIKey(self.apiKey)
	}
}

class GoogleFindPlaceRequest : UnauthenticatedDataRequest {
	typealias RequestedDataType = JSON
	var endpointURL : String {
		get {
			return "https://maps.googleapis.com/maps/api/place/findplacefromtext/json?"
				+ "key=\(apiKey)&inputtype=textquery&input=\(searchText)"
				+ "&fields=formatted_address,geometry,icon,id,name,permanently_closed,photos,place_id,plus_code,scope,types,user_ratings_total"
//				+ "&locationbias=rectangle:south,west|north,east"
		}
	}
	let apiKey : String
	let searchText : String
	init(withSearchText searchText: String, apiKey: String) {
		self.apiKey = apiKey
		self.searchText = searchText
	}
}
