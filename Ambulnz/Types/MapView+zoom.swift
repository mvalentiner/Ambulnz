//
//  MapView+zoom.swift
//
//  Created by Michael Valentiner on 4/7/19.
//  Copyright © 2019 Heliotropix, LLC. All rights reserved.
//

import MapKit

extension MKMapView {
	open func zoom(byFactor factor: Double) {
		let latitudeDelta = self.region.span.latitudeDelta * factor
		let longitudeDelta = self.region.span.longitudeDelta * factor
		let newSpan = MKCoordinateSpan(latitudeDelta: latitudeDelta, longitudeDelta: longitudeDelta)
		let newRegion = MKCoordinateRegion(center: self.region.center, span: newSpan)
		guard newRegion.isValid else {
			return
		}
		self.setRegion(newRegion, animated: true)
	}
}
