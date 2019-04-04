//
//  Places.swift
//  Places
//
//  Created by Michael Valentiner on 3/20/19.
//  Copyright © 2019 Michael Valentiner. All rights reserved.
//

import MapKit
import PromiseKit

struct PlaceUID {
	let placeSourceUID : PlaceSourceUID
	let nativePlaceId : String
}

struct Place {
	let uid : PlaceUID
	let location : CLLocationCoordinate2D
	let title : String
	let description : String?
	let preview : UIImage?
}

struct PlaceDetail {
	let place : Place
	let detail : String?
	let images : [UIImage]?
}

typealias PlaceSourceUID = String

protocol PlaceSource {
	var placeSourceUID : PlaceSourceUID { get }
	var placeSourceName : String  { get }
//	func getPlaces(forRegion : CoordinateRect) -> Promise<[Place]>
	func getPlaces(forRegion : CoordinateRect, completionHandler : ([Place]) -> Void)
	func getPlaceDetail(forUID : PlaceUID, completionHandler : (PlaceDetail?) -> Void)
}
