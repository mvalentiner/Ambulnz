//
//  GooglePlaceService.swift
//  Places
//
//  Created by Michael Valentiner on 4/7/19.
//  Copyright © 2019 Michael Valentiner. All rights reserved.
//

import CoreLocation
import Foundation

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

protocol GooglePlaceService : Service {
	func getPlaces(forSearchText : String, completionHandler : @escaping ([Place]) -> Void)
}

extension GooglePlaceService {
	var serviceName : String {
		get {
			return GooglePlaceServiceName.serviceName
		}
	}

	func getPlaces(forSearchText : String, completionHandler : @escaping ([Place]) -> Void) {
		completionHandler([
			Place(uid: PlaceUID(placeSourceUID: "GooglePlaces", nativePlaceId: ""), location: CLLocationCoordinate2D(), title: "Place 01"),
			Place(uid: PlaceUID(placeSourceUID: "GooglePlaces", nativePlaceId: ""), location: CLLocationCoordinate2D(), title: "Place 02"),
			Place(uid: PlaceUID(placeSourceUID: "GooglePlaces", nativePlaceId: ""), location: CLLocationCoordinate2D(), title: "Place 03"),
		])
	}
}

internal class GooglePlaceServiceImplementation : GooglePlaceService {
	static func register() {
		SR.add(service: GooglePlaceServiceImplementation())
	}
}
