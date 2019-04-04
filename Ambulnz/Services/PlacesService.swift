//
//  PlacesService.swift
//  Places
//
//  Created by Michael Valentiner on 3/20/19.
//  Copyright © 2019 Michael Valentiner. All rights reserved.
//

import PromiseKit
import UIKit

//** PlacesServiceName
internal struct PlacesServiceName {
	static let serviceName = "PlacesService"
}

//** ServiceRegistry extension
extension ServiceRegistry {
	var placesService : PlacesService {
		get {
			return serviceWith(name: PlacesServiceName.serviceName) as! PlacesService	// Intentional force unwrapping
		}
	}
}

//** PlacesService Interface
protocol PlacesService : Service {
	func getPlaces(forRegion : CoordinateRect, completionHandler : @escaping ([Place]) -> Void)
	func getPlaceDetail(forUID : PlaceUID, completionHandler : @escaping (PlaceDetail?) -> Void)

	var placeSources : [PlaceSourceUID : PlaceSource] { get }
}

//** PlacesService Service requirement
extension PlacesService {
	var serviceName : String {
		get {
			return PlacesServiceName.serviceName
		}
	}
}

//** PlacesService default implementation
extension PlacesService {
	func getPlaces(forRegion region: CoordinateRect, completionHandler : @escaping ([Place]) -> Void) {
		placeSources.values.forEach { (placeSource) in
			placeSource.getPlaces(forRegion: region, completionHandler: { (places) in
				completionHandler(places)
			})
		}
	}

//			firstly {
//				placeSource.getPlaces(forRegion: region)
//			}.done { (places) in
//				completionHandler(places)
//			}.catch { error in
//			}

//typealias Photo = Place
//
//	func getPhotos() -> Promise<Photo> {
//		let photos : [Photo] = ...
//		photos.forEach { photo in
//			return Promise<Photo>.value(photo)
//		}
//	}
//
//func foo {
//	firstly {
//		getPhotos()
//	}.done { place in
//		self.persist(place)
//	}
//}
//
//func getPhotos(completionHandler : @escaping (Photo) -> Void) {
//	let photos : [Photo] = ...
//	photos.forEach { photo in
//		completionHandler(photo)
//	}
//}

	func getPlaceDetail(forUID placeUID: PlaceUID, completionHandler : @escaping (PlaceDetail?) -> Void) {
		let placeSourceUID = placeUID.placeSourceUID
		guard let placeSource = placeSources[placeSourceUID] else {
			fatalError("Error: PlacesServiceImplementation misconfiguration. No PlaceSource found for \(placeSourceUID)")
		}
		placeSource.getPlaceDetail(forUID: placeUID) { (placeDetail) in
			completionHandler(placeDetail)
		}
	}
}

//** PlacesServiceImplementation
internal class PlacesServiceImplementation : PlacesService {
	static func register(placeSources : [PlaceSource]) {
		SR.add(service: PlacesServiceImplementation(placeSources: placeSources))
	}
	
	internal var placeSources : [PlaceSourceUID : PlaceSource] = [:]

	init(placeSources: [PlaceSource]) {
		placeSources.forEach { (placeSource) in
			self.placeSources[placeSource.placeSourceUID] = placeSource
		}
	}
}
