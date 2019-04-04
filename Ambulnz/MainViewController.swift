//
//	MainViewController.swift
//	Places Near
//
//	Created by Michael Valentiner on 3/15/19.
//	Copyright © 2019 Michael Valentiner. All rights reserved.
//

import MBProgressHUD
import MapKit
import PromiseKit
import PMKCoreLocation
import ReactiveSwift
import Result
import UIKit

class MainViewController: UIViewController, CLLocationManagerDelegate, MKMapViewDelegate {
	// MARK: UI
	@IBOutlet weak var mapView : MKMapView!
	private var progressView : MBProgressHUD?

	// MARK: Model
	private var annotations = MutableProperty<[PlaceAnnotation]>([])

	// MARK: State
	private var hasFirstLocation = false // This is used to make sure mapView(_:didUpdate:) is called before doing anything in mapView(_:regionDidChangeAnimated:)
	private var lastRegion = MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: 0, longitude: 0), span: MKCoordinateSpan(latitudeDelta: 0, longitudeDelta: 0))
	fileprivate var selectedAnnotation : PlaceAnnotation?
	internal var userLocation = CLLocationCoordinate2D(latitude: 0, longitude: 0)

	// MARK: Location support
	private let locationManager = CLLocationManager()

	private func isLocationServicesEnabled() -> Promise<Bool> {
		return Promise<Bool>.value(CLLocationManager.locationServicesEnabled())
	}

	// MARK: UIViewController overrides
	override func viewDidLoad() {
		super.viewDidLoad()

		//** UI
		// Create the buttonBarView container view.
		let buttonBarView = UIStackView()
		buttonBarView.axis = .vertical
		buttonBarView.distribution = .equalSpacing
		buttonBarView.constrainTo(width: 44)
		buttonBarView.constrainTo(height: 89)
		view.addSubview(buttonBarView)
		buttonBarView.anchorTo(top: view.safeAreaTopAnchor, right: view.safeAreaRightAnchor, topPadding: 32, rightPadding: 8)

		// Create the buttons for the buttonBarView.
		let button = UIButton(type: .infoDark)
		button.addTarget(self, action: #selector(handleInfoButtonTap), for: .touchUpInside)
		let infoButton = makeButtonItem(with: button, andRoundedCorners: [.layerMinXMinYCorner,.layerMaxXMinYCorner])
		buttonBarView.insertArrangedSubview(infoButton, at: 0)

		let userLocationButton = makeButtonItem(with: MKUserTrackingButton(mapView: mapView), andRoundedCorners: [.layerMinXMaxYCorner,.layerMaxXMaxYCorner])
		buttonBarView.insertArrangedSubview(userLocationButton, at: 1)

		//** Location
		// Initialize the locationManager.
		locationManager.delegate = self
		locationManager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
		locationManager.distanceFilter = 10.0
		
		if CLLocationManager.locationServicesEnabled() {
			locationManager.requestWhenInUseAuthorization()
		}
		else {
			// Location Services is not on
			showLocationServicesRequestDialog()
		}

		// Bind action to model
		annotations.bindTo { self.updateMap() }

//		createAndShowProgressHUD()

//		SR.reachabilityService.setReachableHandler { (reachability) in
//			guard let window = self.view.window,
//				let rootViewController = window.rootViewController,
//				let navigationController = rootViewController as? UINavigationController,
//				navigationController.topViewController == self else {
//					return
//			}
//			if let presentedViewController = self.presentedViewController {
//				presentedViewController.dismiss(animated: true)
//			}
//			self.updateMapAnnotations()
//		}
	}

	// ButtonBar helper function
	private func makeButtonItem(with button: UIView, andRoundedCorners cornersMask: CACornerMask) -> UIView {
		let containerView = UIView()
		containerView.backgroundColor = .clear
		containerView.constrainTo(height: 44)

		let backgroundView = UIView()
		backgroundView.alpha = 0.333
		backgroundView.backgroundColor = .lightGray
		backgroundView.clipsToBounds = true
		backgroundView.constrainTo(height: 44)
		backgroundView.layer.cornerRadius = 10
		backgroundView.layer.maskedCorners = cornersMask

		containerView.addSubview(backgroundView)
		backgroundView.anchorTo(left: containerView.leftAnchor, top: containerView.topAnchor, right: containerView.rightAnchor, bottom: containerView.bottomAnchor)

		containerView.addSubview(button)
		button.anchorTo(left: containerView.leftAnchor, top: containerView.topAnchor, right: containerView.rightAnchor, bottom: containerView.bottomAnchor)
		return containerView
	}

	@objc func handleInfoButtonTap() {
//		self.performSegue(withIdentifier: "segueToSettingsViewController", sender:self)
	}

	private func showLocationServicesRequestDialog() {
		let alertController = UIAlertController(
			title: "Places Near uses your location to find photos near you.",
			message: "Authorize access to your location to use Places Near. Go to Settings > Privacy > Location Services.",
			preferredStyle:UIAlertController.Style.alert)
		let okAction = UIAlertAction(title: "OK", style: UIAlertAction.Style.default) { (_: UIAlertAction) in
			UIApplication.shared.open(URL(string:UIApplication.openSettingsURLString)!)
		}
		alertController.addAction(okAction)
		self.present(alertController, animated: true)
	}

	private func showProgressHUD() {
		guard self.progressView == nil else {
			return
		}

		let progressView = MBProgressHUD.showAdded(to: self.view, animated: true)
		progressView.graceTime = 0.5
		progressView.minShowTime = 1.0
		progressView.bezelView.alpha = 0.5
		progressView.bezelView.backgroundColor = UIColor.darkGray
		progressView.bezelView.isOpaque = false
		progressView.removeFromSuperViewOnHide = true
		self.progressView = progressView
	}

	// MARK: CLLocationManagerDelegate methods

	internal func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
		if status == CLAuthorizationStatus.authorizedAlways || status == CLAuthorizationStatus.authorizedWhenInUse {
			// we are authorized.
			locationManager.startMonitoringSignificantLocationChanges()
			mapView.showsUserLocation = true
		}
		else if status == CLAuthorizationStatus.denied {
			showLocationServicesRequestDialog()
		}
	}

	internal func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
		if error._code == CLError.Code.denied.rawValue {
			showLocationServicesRequestDialog()
		}
		else {
			//TODO: alert the user?
		}
	}

	// MARK: MKMapViewDelegate methods

	private var didSelectAnnotation = false
		// didSelectAnnotation tracks when an annotation is selected so we don't make unnecessary calls to get more annoations, if
		// showing the annotation made the map move.

    internal func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
		didSelectAnnotation = true
	}

    internal func mapView(_ mapView: MKMapView, didDeselect view: MKAnnotationView) {
		didSelectAnnotation = false
	}

    internal func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
		guard hasFirstLocation == true else {
			// Wait until mapView(_:didUpdate:) has been called
			return
		}

		guard self.isRegionChangeWithinTolerance(mapView, tolerance:0.3333) == true else {
			return
		}

		requestMapPlacesAndUpdateAnnotations()
	}

	private func isRegionChangeWithinTolerance(_ mapView: MKMapView, tolerance: Double) -> Bool {
		let currentRegion = mapView.region
		let currentRegionInViewCoords = mapView.convert(currentRegion, toRectTo: mapView)

		let lastRegionInViewCoords = mapView.convert(lastRegion, toRectTo: mapView)

		let xMaxTolerance = Int(currentRegionInViewCoords.size.width * CGFloat(tolerance))

		let xOriginDelta = abs(Int(lastRegionInViewCoords.origin.x - currentRegionInViewCoords.origin.x))
		if xOriginDelta > xMaxTolerance {
			return false
		}

		let yMaxTolerance = Int(currentRegionInViewCoords.size.height * CGFloat(tolerance))

		let yOriginDelta = abs(Int(lastRegionInViewCoords.origin.y - currentRegionInViewCoords.origin.y))
		if yOriginDelta > yMaxTolerance {
			return false
		}

		return true
	}

	internal func mapView(_ mapView: MKMapView, didUpdate updatedUserLocation: MKUserLocation) {
		guard hasFirstLocation == true else {
			hasFirstLocation = true

			let initialSpan = MKCoordinateSpan.init(latitudeDelta: 0.2, longitudeDelta: 0.2)
			let initialRegion = MKCoordinateRegion(center: updatedUserLocation.coordinate, span: initialSpan)
			mapView.region = initialRegion	// this causes mapView(_:regionDidChangeAnimated:) to get called
			mapView.centerCoordinate = updatedUserLocation.coordinate
			mapView.userTrackingMode = MKUserTrackingMode.follow

			lastRegion = mapView.region
			userLocation = updatedUserLocation.coordinate
			return
		}

		guard self.isRegionChangeWithinTolerance(mapView, tolerance:0.3333) == true else {
			return
		}

		requestMapPlacesAndUpdateAnnotations()
	}

	internal func requestMapPlacesAndUpdateAnnotations() {
		guard didSelectAnnotation == false else {
			// Don't get more annotations if the map is displaying an annotation.
			return
		}

//		showProgressHUD()

		lastRegion = mapView.region
		mapView.removeAnnotations(annotations.value)
		annotations.value.removeAll(keepingCapacity: true)

//		guard SR.reachabilityService.isReachable == true else {
//			DispatchQueue.main.async {
//				if let progressView = self._progressView {
//					self._progressView = nil
//					progressView.hide(animated: true)
//				}
//				let alertController = UIAlertController(title: "Network", message: "Network is unavailable",
//					preferredStyle:UIAlertController.Style.alert)
//				let okAction = UIAlertAction(title: "OK", style: UIAlertAction.Style.default, handler:nil)
//				alertController.addAction(okAction)
//				self.present(alertController, animated: true, completion: {})
//			}
//			return
//		}

//		var maximumNumberOfPhotos = 100
//		let maxDimension = Int(max(UIScreen.main.bounds.width, UIScreen.main.bounds.height))
//		if maxDimension > 768 {
//			// http://www.paintcodeapp.com/news/ultimate-guide-to-iphone-resolutions
//			maximumNumberOfPhotos = 204
//		}

		let topRight = CLLocationCoordinate2D(
			latitude:(mapView.centerCoordinate.latitude + mapView.region.span.latitudeDelta),
			longitude:(mapView.centerCoordinate.longitude + mapView.region.span.longitudeDelta))
		let bottomLeft = CLLocationCoordinate2D(
			latitude:(mapView.region.center.latitude - mapView.region.span.latitudeDelta),
			longitude:(mapView.centerCoordinate.longitude - mapView.region.span.longitudeDelta))

		let rect = CoordinateRect(topRight: topRight, bottomLeft: bottomLeft)
		SR.placesService.getPlaces(forRegion: rect) { places in
			let annotations = places.map { place -> PlaceAnnotation in
				return PlaceAnnotation(withPlace: place, andDelegate: self)
			}
			self.annotations.value.append(contentsOf: annotations)
		}
	}

	private func updateMap() {
		DispatchQueue.main.async {
			self.annotations.value.forEach { (annotation) in
				self.mapView.addAnnotation(annotation)
			}

			self.mapView.setNeedsDisplay()

//			if let progressView = self._progressView {
//				self._progressView = nil
//				progressView.hide(animated: true)
//			}
//			self._photosButton.isEnabled = self.annotations.value.isEmpty == false
		}
	}

    internal func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
		guard annotation is MKUserLocation == false else {
			// Don't return a view if the annotation is our location.
			return nil
		}

		guard let placeAnnotation = annotation as? PlaceAnnotation else {
			// If annotation is not a PlaceAnnotation, then we don't know what to do with it.
			return nil
		}

		let annotationViewId = "placeAnnotationId"
		let annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: annotationViewId) ??
				MKPinAnnotationView(annotation: annotation, reuseIdentifier: annotationViewId)
		annotationView.annotation = annotation
		annotationView.detailCalloutAccessoryView = nil

		let containerView = UIView()
		var yOffset : CGFloat = 0.0

		let textLabelHeight : CGFloat = 16.0
		let smallestScreenDimension = min(UIScreen.main.bounds.size.width, UIScreen.main.bounds.size.height)
		let width = smallestScreenDimension * 0.667

		let titleLabel : UILabel = {
			let titleText = placeAnnotation.title ?? ""
			let textLabelFrame = CGRect(x: 0.0, y: 0.0, width: width, height: textLabelHeight)
			let label = UILabel(frame: textLabelFrame)
			label.textAlignment = .center
			let attributedText = NSAttributedString(string: titleText, attributes: [.font: UIFont.boldSystemFont(ofSize: 14)])
			label.attributedText = attributedText
			label.translatesAutoresizingMaskIntoConstraints = false
			label.widthAnchor.constraint(equalToConstant: width).isActive = true
			label.heightAnchor.constraint(equalToConstant: textLabelHeight).isActive = true
			return label
		}()
		containerView.addSubview(titleLabel)
		yOffset += textLabelHeight + 4

//
//
//		if let image = placeAnnotation.previewImage {
//			let imageSize = image.size
//			let maxImageDimension = max(imageSize.height, imageSize.width)
//			let largestImageDimension = smallestScreenDimension * 0.667
//			let height = min((imageSize.height / maxImageDimension) * largestImageDimension, imageSize.height)
//			let width = min((imageSize.width / maxImageDimension) * largestImageDimension, imageSize.width)
//
//
//			let button = UIButton(type:UIButton.ButtonType.custom)
//			let buttonYOffset = yOffset
//			button.frame = CGRect(x: 0, y: buttonYOffset, width: width, height: buttonYOffset + height)
//			button.addTarget(photoAnnotation, action: #selector(PhotoAnnotation.doButtonPress), for: UIControl.Event.touchUpInside)
//			button.setImage(image, for: UIControl.State())
//			containerView.addSubview(button)
//			yOffset += buttonYOffset
//
//			containerView.translatesAutoresizingMaskIntoConstraints = false
//			containerView.widthAnchor.constraint(equalToConstant: width).isActive = true
//			containerView.heightAnchor.constraint(equalToConstant: yOffset + height).isActive = true
//
//			annotationView.detailCalloutAccessoryView = containerView
//			annotationView.canShowCallout = true
//		}
//		else {
//			print("photoAnnotation == \((annotation as? PhotoAnnotation).debugDescription)")
//			print("photoInfoDict == \(String(describing: (annotation as? PhotoAnnotation)?.photoInfoDict))")
//		}

		return annotationView
	}
}

extension MainViewController : PlaceAnnotationDelegate {
    internal func handleAnnotationPress(forAnnotation annotation: PlaceAnnotation) {
		self.selectedAnnotation = annotation
//TODO
//		self.performSegue(withIdentifier: "segueToPhotoView", sender:self)
	}
}
