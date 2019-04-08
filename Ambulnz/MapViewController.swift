//
//	MapViewController.swift
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

private struct MapServiceName {
	static let serviceName = "MapService"
}

extension ServiceRegistry {
	var mapService : MapService {
		get {
			return serviceWith(name: MapServiceName.serviceName) as! MapService	// Intentional force unwrapping
		}
	}
}

// Expose the MapViewController as the MapService
protocol MapService : Service {
	func show(place: Place)
}

class MapViewController: UIViewController, CLLocationManagerDelegate, MKMapViewDelegate, MapService {

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

	var serviceName : String {
		get {
			return MapServiceName.serviceName
		}
	}

    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }

    override open func loadView() {
        super.loadView()
		// Expose the MapViewController as the MapService by registering self with the ServiceRegistry
		SR.add(service: self)
	}

	// MARK: UIViewController overrides
	override func viewDidLoad() {
		super.viewDidLoad()

		//** UI
		// Create the userLocationButtonBarView container view.
		let userLocationButtonBarView = UIStackView()
		userLocationButtonBarView.axis = .vertical
		userLocationButtonBarView.distribution = .equalSpacing
		userLocationButtonBarView.constrainTo(width: 44)
		userLocationButtonBarView.constrainTo(height: 44)
		view.addSubview(userLocationButtonBarView)
		userLocationButtonBarView.anchorTo(top: view.safeAreaTopAnchor, right: view.safeAreaRightAnchor, topPadding: 32, rightPadding: 16)

		// Create the buttons for the userLocationButtonBarView.
		let userLocationButton = makeButtonItem(with: MKUserTrackingButton(mapView: mapView), andRoundedCorners: [.layerMinXMinYCorner,.layerMaxXMinYCorner, .layerMinXMaxYCorner,.layerMaxXMaxYCorner])
		userLocationButtonBarView.insertArrangedSubview(userLocationButton, at: 0)

		// Create the zoomButtonBarView container view.
		let zoomButtonBarView = UIStackView()
		zoomButtonBarView.axis = .vertical
		zoomButtonBarView.distribution = .equalSpacing
		zoomButtonBarView.constrainTo(width: 44)
		zoomButtonBarView.constrainTo(height: 92)
		view.addSubview(zoomButtonBarView)
		zoomButtonBarView.anchorTo(top: userLocationButtonBarView.bottomAnchor, right: view.safeAreaRightAnchor, topPadding: 44, rightPadding: 16)

		// Create the buttons for the zoomButtonBarView.
		let inButton = UIButton(type: .custom)
		inButton.setImage(UIImage(named: "plus-button-icon"), for: .normal)
		inButton.addTarget(self, action: #selector(handleZoomInButtonTap), for: .touchUpInside)
		let zoomInButton = makeButtonItem(with: inButton, andRoundedCorners: [.layerMinXMinYCorner,.layerMaxXMinYCorner])
		zoomButtonBarView.insertArrangedSubview(zoomInButton, at: 0)

		let outButton = UIButton(type: .custom)
		outButton.setImage(UIImage(named: "minus-button-icon"), for: .normal)
		outButton.addTarget(self, action: #selector(handleZoomOutButtonTap), for: .touchUpInside)
		let zoomOutButton = makeButtonItem(with: outButton, andRoundedCorners: [.layerMinXMaxYCorner,.layerMaxXMaxYCorner])
		zoomButtonBarView.insertArrangedSubview(zoomOutButton, at: 1)

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
		
		// Center on the user's initial location on the map.
		guard let userLocation = locationManager.location else {
			return
		}
		let initialSpan = MKCoordinateSpan.init(latitudeDelta: 0.1, longitudeDelta: 0.1)
		let initialRegion = MKCoordinateRegion(center: userLocation.coordinate, span: initialSpan)
		mapView.region = initialRegion	// this causes mapView(_:regionDidChangeAnimated:) to get called
		mapView.centerCoordinate = userLocation.coordinate
		mapView.userTrackingMode = MKUserTrackingMode.none
	}

	// ButtonBar helper function
	private func makeButtonItem(with button: UIView, andRoundedCorners cornersMask: CACornerMask) -> UIView {
		let containerView = UIView()
		containerView.backgroundColor = .clear
		containerView.constrainTo(height: 44)

		let backgroundView = UIView()
		backgroundView.alpha = 0.445
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

	@objc func handleZoomInButtonTap() {
		mapView.zoom(byFactor: 0.5)
	}

	@objc func handleZoomOutButtonTap() {
		mapView.zoom(byFactor: 2.0)
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

	//** MapService functions
	func show(place : Place) {
		mapView.userTrackingMode = MKUserTrackingMode.none	// the map doesn't center on a new location unless is not tracking the user.
		mapView.centerCoordinate = place.location

		let annotation = PlaceAnnotation(withPlace: place, andDelegate: self)
		self.annotations.value.removeAll()
		self.annotations.value.append(annotation)
	}

	// MARK: CLLocationManagerDelegate methods

	internal func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
		if status == CLAuthorizationStatus.authorizedAlways || status == CLAuthorizationStatus.authorizedWhenInUse {
			// we are authorized.
			locationManager.startMonitoringSignificantLocationChanges()
			mapView.showsUserLocation = true

			guard let userLocation = locationManager.location else {
				return
			}
			let initialSpan = MKCoordinateSpan.init(latitudeDelta: 0.1, longitudeDelta: 0.1)
			let initialRegion = MKCoordinateRegion(center: userLocation.coordinate, span: initialSpan)
			mapView.region = initialRegion	// this causes mapView(_:regionDidChangeAnimated:) to get called
			mapView.centerCoordinate = userLocation.coordinate
			mapView.userTrackingMode = MKUserTrackingMode.none
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

	internal func mapView(_ mapView: MKMapView, didUpdate updatedUserLocation: MKUserLocation) {
		guard hasFirstLocation == true else {
			hasFirstLocation = true

			let initialSpan = MKCoordinateSpan.init(latitudeDelta: 0.2, longitudeDelta: 0.2)
			let initialRegion = MKCoordinateRegion(center: updatedUserLocation.coordinate, span: initialSpan)
			mapView.region = initialRegion	// this causes mapView(_:regionDidChangeAnimated:) to get called
			mapView.centerCoordinate = updatedUserLocation.coordinate
			mapView.userTrackingMode = MKUserTrackingMode.none

			lastRegion = mapView.region
			userLocation = updatedUserLocation.coordinate
			return
		}
	}

	private func updateMap() {
		DispatchQueue.main.async {
			self.mapView.removeAnnotations(self.mapView.annotations)
			self.annotations.value.forEach { (annotation) in
				self.mapView.addAnnotation(annotation)
			}
			self.mapView.setNeedsDisplay()
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

extension MapViewController : PlaceAnnotationDelegate {
    internal func handleAnnotationPress(forAnnotation annotation: PlaceAnnotation) {
		self.selectedAnnotation = annotation
//TODO
//		self.performSegue(withIdentifier: "segueToPhotoView", sender:self)
	}
}
