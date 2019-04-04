//
//  Service.swift
//  Places
//
//  Created by Michael Valentiner on 3/20/19.
//  Copyright © 2019 Michael Valentiner. All rights reserved.
//

protocol Service : class {
	var serviceName : String { get }
}

struct ServiceRegistry {
	private static var serviceDictionary : [String : Service] = [:]
	
	internal func add(service: Service) {
		ServiceRegistry.serviceDictionary[service.serviceName] = service
	}

	private func get(serviceWithName name: String) -> Service? {
		return ServiceRegistry.serviceDictionary[name]
	}

	internal func serviceWith(name: String) -> Service {
		guard let resolvedService = ServiceRegistry().get(serviceWithName: name) else {
			fatalError("Error: Service \(name) is not registered with the ServiceRegistry.")
		}
		return resolvedService
	}
}

let SR = ServiceRegistry()
