//
//  AppProperties.swift
//  Places
//
//  Created by Michael Valentiner on 3/20/19.
//  Copyright © 2019 Michael Valentiner. All rights reserved.
//

import Foundation

internal struct AppPropertiesServiceName {
	static let name = "AppPropertiesService"
}

extension ServiceRegistry {
	var appPropertiesService : AppPropertiesService {
		get {
			return serviceWith(name: AppPropertiesServiceName.name) as! AppPropertiesService	// Intentional forced unwrapping
		}
	}
}

protocol AppPropertiesService : Service {
	var appAppStoreURL : String { get }
	var appBuildNumber : String { get }
	var appStoreId : String { get }
	var appVersion : String { get }
}

extension AppPropertiesService {
	// MARK: Service protocol requirement
	internal var serviceName : String {
		get {
			return AppPropertiesServiceName.name
		}
	}

	// MARK: AppPropertiesService service implementation

	internal var appAppStoreURL : String {
		get {
			return getPropertyListString(forKey: "AppAppStoreURL")
		}
	}

    internal var appBuildNumber : String {
        get {
            return getPropertyListString(forKey: "CFBundleVersion")
        }
    }
	
	internal var appStoreId : String {
		get {
			let appStoreUrl = URL(string: getPropertyListString(forKey: "AppAppStoreURL"))
			let idPath = appStoreUrl?.lastPathComponent
			guard let id = idPath?.replacingOccurrences(of: "id", with: "") else {
				fatalError("Developer error. AppstoreURL is missing from plist")
			}
			return id
		}
	}

	internal var appVersion: String {
		get {
			return getPropertyListString(forKey: "CFBundleShortVersionString")
		}
	}

	private func getPropertyListString(forKey: String) -> String {
		guard let value = Bundle.main.object(forInfoDictionaryKey: forKey) as? String else {
			fatalError("Error: No plist entry for \(forKey)")
		}
		return value
	}
	
    private func getBundleResourcePath(forFileName resource: String, withExtension type: String) -> String {
        guard let path = Bundle.main.path(forResource: resource, ofType: type) else {
            fatalError("Error: \(resource).\(type) does not exist in app bundle")
        }
        return path
    }
}

internal class AppPropertiesServiceImplementation : AppPropertiesService {
	static func register() {
		SR.add(service: AppPropertiesServiceImplementation())
	}
}
