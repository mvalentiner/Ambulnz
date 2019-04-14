//
//  LocationSearchViewController.swift
//  Ambulnz
//
//  Created by Michael Valentiner on 4/6/19.
//  Copyright © 2019 Heliotropix, LLC. All rights reserved.
//

import ReactiveSwift
import UIKit

class LocationSearchViewController : UIViewController, UISearchBarDelegate, UITableViewDataSource, UITableViewDelegate {

	private var resultsTableView: UITableView!	// Intentional forced unwrapping
	private var searchBar : UISearchBar!	// Intentional forced unwrapping

	private let locationCellId = "LocationCellId"

	// locations is a ReactiveSwift property that we can bind an action to that gets called whenever if changes.
	var locations = MutableProperty<[Place]>([])

	override func viewDidLoad() {
		super.viewDidLoad()

		//** UI - build the view hierarchy.
		let tableViewWidth = view.frame.size.width
		let spacerViewHeight : CGFloat = 12.0

		self.searchBar = {
			let searchBarFrame = CGRect(x: 0.0, y: spacerViewHeight, width: tableViewWidth, height: 44.0)
			let searchBar = UISearchBar(frame: searchBarFrame)
			searchBar.delegate = self
			searchBar.placeholder = "Search Location"
			return searchBar
		}()

		let headerViewHeight = searchBar.frame.size.height + spacerViewHeight

		let headerView : UIView = {
			let spacerViewFrame = CGRect(x: 0.0, y: 0.0, width: tableViewWidth, height: spacerViewHeight + 1.0) // +1.0 gets rid of the fine dark line.
			let spacerView = UIView(frame: spacerViewFrame)
			spacerView.backgroundColor = UIColor(white: 0.785, alpha: 1.0)

			let headerViewFrame = CGRect(x: 0.0, y: 0.0, width: tableViewWidth, height: headerViewHeight)
			let view = UIView(frame: headerViewFrame)
			view.addSubview(searchBar)	 // position z-order below spacerView gets rid of the fine dark line.
			view.addSubview(spacerView)
			return view
		}()
		view.addSubview(headerView)

		self.resultsTableView = {
			let tableViewHeight = view.frame.size.height - headerViewHeight
			let tableViewFrame = CGRect(x: 0.0, y: headerViewHeight, width: tableViewWidth, height: tableViewHeight)
			let tableView = UITableView(frame: tableViewFrame)
			tableView.dataSource = self
			tableView.delegate = self
			tableView.keyboardDismissMode = UIScrollView.KeyboardDismissMode.interactive
			tableView.register(UITableViewCell.self, forCellReuseIdentifier: locationCellId)
			return tableView
		}()
		view.addSubview(self.resultsTableView)

		//** UI - add a UITapGestureRecognizer that we use to manage the keyboard.
		let tapGesture : UITapGestureRecognizer = {
			let gestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(handleTap))
			gestureRecognizer.delegate = self
			return gestureRecognizer
		}()
		guard let window = UIApplication.shared.windows.first else {
			return
		}
		window.addGestureRecognizer(tapGesture)

		//** Bind the RectiveSwift locations model to UI
		locations.bindTo {
			self.resultsTableView.reloadData()
		}
	}

	// MARK: UISearchBarDelegate functions

	public func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
		locations.value.removeAll()
		guard searchText != "" && searchText.count > 3 else {
			return
		}
		let googlePlaceService = SR.googlePlaceService
		googlePlaceService.getPlaces(forSearchText: searchText) { (place) in
			guard let place = place else {
				return
			}
			self.locations.value.append(place)
		}
   }

	public func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
		guard let searchText = searchBar.text, searchText != "" else {
			return
		}

		let googlePlaceService = SR.googlePlaceService
		googlePlaceService.search(forAddress: searchText) { (place) in
	
			searchBar.resignFirstResponder()
	
			guard let place = place else {
				return
			}
			self.locations.value.removeAll()
			self.locations.value.append(place)
			self.show(place: place)
		}
	}

	public func searchBarTextDidEndEditing(_ searchBar: UISearchBar) {
		searchBar.resignFirstResponder()
	}

	// MARK: UITableViewDataSource functions

	func numberOfSections(in tableView: UITableView) -> Int {
		return 1
	}

	public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		return locations.value.count
	}

	public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		let cell = tableView.dequeueReusableCell(withIdentifier: locationCellId, for: indexPath)
		cell.textLabel?.text = locations.value[indexPath.row].title
		return cell
	}

	// MARK: UITableViewDelegate functions
	func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
		let place = locations.value[indexPath.row]
		show(place: place)
		searchBar.resignFirstResponder()
	}
	
	// Helper function to update the map
	private func show(place: Place) {
		SR.mapService.show(place: place)
	}
}

// MARK: UIGestureRecognizerDelegate - used to manage the keyboard.
extension LocationSearchViewController : UIGestureRecognizerDelegate {
    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
		if touch.view?.isDescendant(of: self.resultsTableView) == true {
			// Make sure the user is not tapping on the table view. This allows tap event to propogate to the table view.
			return false
		}
		return true
	}

	@objc func handleTap(_ sender: UIGestureRecognizer) {
		searchBar.resignFirstResponder()
	}
}

// MARK: PulleyViewController extension - add functionality to respond to hide/show events
extension PulleyViewController {
	override open func viewWillAppear(_ animated: Bool) {
		super.viewWillAppear(animated)
		NotificationCenter.default.addObserver(self, selector: #selector(handleKeyboardWillAppear), name: UIResponder.keyboardWillShowNotification, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(handleKeyboardWillDisappear), name: UIResponder.keyboardWillHideNotification, object: nil)
	}

	@objc func handleKeyboardWillAppear(notification: NSNotification) {
    	guard let userInfo = notification.userInfo, let rect = userInfo[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else {
			return
		}
		// Resize the view to accommodate the height of the keyboard popping up.
		let height = rect.size.height
		let frame = view.frame
		let newFrame = CGRect(x: frame.origin.x, y: frame.origin.y, width: frame.size.width, height: frame.size.height - height)
		view.frame = newFrame

		// If the drawer is not, at least, partially open, open it.
		guard drawerPosition != .open &&  drawerPosition != .partiallyRevealed else {
			return
		}
		setDrawerPosition(position: .partiallyRevealed, animated: true)
	}

	@objc func handleKeyboardWillDisappear(notification: NSNotification) {
    	guard let userInfo = notification.userInfo, let rect = userInfo[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else {
			return
		}
		// Resize the view to accommodate the height of the keyboard going away.
		let height = rect.size.height
		let frame = view.frame
		let newFrame = CGRect(x: frame.origin.x, y: frame.origin.y, width: frame.size.width, height: frame.size.height + height)
		view.frame = newFrame

		setDrawerPosition(position: .collapsed, animated: true)
	}
}
