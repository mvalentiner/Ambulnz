//
//  MutableProperty+bindTo.swift
//  Places
//
//  Created by Michael Valentiner on 3/22/19.
//  Copyright © 2019 Michael Valentiner. All rights reserved.
//

import ReactiveSwift

extension MutableProperty {
	func bindTo(action: @escaping ()->Void) {
		signal.observeValues { (value) in
			action()
        }
	}
}

