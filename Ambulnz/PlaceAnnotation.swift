//
//  PlaceAnnotation.swift
//  Places Near
//
//  Created by Michael Valentiner on 3/15/19.
//  Copyright © 2019 Michael Valentiner. All rights reserved.
//

import Foundation
import MapKit

protocol PlaceAnnotationDelegate {
    func handleAnnotationPress(forAnnotation: PlaceAnnotation)
}

typealias PlaceInfoDictionary = [String: Any]

class PlaceAnnotation: NSObject, MKAnnotation {
	// protocol MKAnnotation requirement
    internal let coordinate: CLLocationCoordinate2D
	// protocol MKAnnotation optionals
	internal let title: String?
	internal let subtitle: String?
	// Places
	private let placeUID : PlaceUID
	// Places optional
	internal let image: UIImage?
	// Event handler
	private let delegate: PlaceAnnotationDelegate

	init(withPlace place: Place, andDelegate delegate: PlaceAnnotationDelegate) {
		self.coordinate = place.location
		self.title = place.title
		self.subtitle = place.description
		self.placeUID = place.uid
		self.delegate = delegate
		self.image = place.preview
		super.init()
    }

	@objc internal func doButtonPress() {
		delegate.handleAnnotationPress(forAnnotation: self)
	}
}
