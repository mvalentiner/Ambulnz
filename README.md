# **Ambulnz**
Ambulnz Code Challenge

For this project, I utilized an exiting app I'm working on that plots places on a map. Lucky me, my app is ideal base app for this code challenge.

For the app UI, I chose to model it after the Apple Maps app.  To implement the UI, I used a third party framework called Pulley. It provides the sliding drawer that the user can drag open from the bottom of the screen.  The drawer is where I put my search bar and search results, the main ocus of the code challenge.

## **To build**
The project uses Carthage. Make sure you have it installed. In a bash shell, cd to the Ambulnz directory (the one with the Cartfile), and execute:
	`carthage update --platform iOS`
When it's done, in Xcode, select the scheme and device (or simulator) you want to run on, and build. If running on a device, you will need to set the team for code signing: `project file -> Ambulnz target -> General -> Code signing -> team.`

It should build and run.  If not, contact me to troubleshoot.

## **API Key Configuration**
Google API key configuration: to call the Google service, you will need to provide a Google api key. (Mine is tied to my account and credit card and, so, is to remain private).  You mostly likely already have one and one that works. I've had difficulties getting the Geocoding API to work with my api key. (I get a response, "This IP, site or mobile application is not authorized to use this API key. Request received from IP address 2604:2000:1304:8280:28a7:b03:e5fa:3d69, with empty referer.")
• in *GooglePlaceService.swift, line 136*, modify the **apiKey** String to use yout api key:
			let apiKey = "<replace with your api key here>"

As stated, I've been unable to the Geocoding API to work with my api key, but it does work with the GooglePlaces framework. I've worked around the problem for the most part, but can not geocode an address through the `maps.googleapis.com/maps/api/geocode/` endpoint due to a "*This IP, site or mobile application is not authorized to use this API key. Request received from IP address 2604:2000:1304:8280:28a7:b03:e5fa:3d69, with empty referer" error*.

## **Running the App**
My intent is for the user to have to interact with the UI only using their thumb.
	• tapping on the search bar expands the drawer.
	• typing characters shows suggestions.  I set a mimimum character limit of four characters, be for suggestions show up.
	• the drawer can be dragged open or collapsed.
	• selecting a suggestion collapses the drawer and the map centers on that location.
	• zoom in and zoom out buttons work, as does the user tracking button.

## **The Code**

As mentioned above, I utilized Pulley for the draggable drawer.  Anything under Pulley-master is NOT my code and I knew nothing about Pulley till last Friday. My code is the code in the content views that it manages:
• *MapViewController* and
• *LocationSearchViewController* This is primary code that addresses the goals and requirements laid out in the code challenge.
In addition, is
• *GooglePlaceService* It does the work of interfacing with Google services and SDK query for data and get results that are displayed by LocationSearchViewController. It uses the Service Oriented Architecture (SOA) software pattern I've developed. More on that later.

### **Frameworks**
The Cartfile shows the frameworks I am using. I , generally, try to keep thirdparty frameworks to a minimum to reduce the number of external dependencies, but there are good ones that yield big benefits, so I use them when appropriate. In this project is:
• *PromiseKit*I'm fairly new to this one, but it certainly reduces nested closures when making asychronous network calls and makes for highly readable code.
• *ReactiveSwift* It's probably overkill for how little I utilize this in this project, but it's what I'm using these days. I use it to bind view models to UI, so when the models change, it triggers update to the UI.  It takes very little code to wire this up and I wrote a bind() function to make it look nice.

### **MapViewController**
This is carried over from my previous project with a few modifications for the task at hand. It is the UIViewController for the underlying MKMapView and all it's associated behaviors. It, also, implements the SOA MapService, which is used to expose functionality to the LocationSearchViewController, so it can update the map to show a place when it needs to.

### **LocationSearchViewController**
This is the bulk of the code pertaining to the code challenge.  It consists of a `UISearchBar` and `UITableView`.
The search bar takes input, character by character, and finds suggested matches by calling the *GooglePlaceService*. *GooglePlaceService* implements those requests using the Google Places `findAutocompletePredictionsFromQuery()` function.
Suggested matches are stored in the `locations` ReactiveSwift property.  `locations`  is bound to a closure (line 75) that updates the `resultsTableView` when it changes.
`LocationSearchViewController` implements various callback functions from `UISearchBarDelegate, UITableViewDataSource ,UITableViewDelegate`.
Lastly, `LocationSearchViewController` contains an extension to `PulleyViewController` for managing the presentation of the soft keyboard on the device.

### **GooglePlaceService**
`GooglePlaceService` is one of two SOA Services in this project (the other is `MapService`).  `GooglePlaceService` follows a typical pattern I use to write these services.  It consists of a 
• **protocol** that defines the public interface to the service (that is, the interface all implementations must provide):
	`protocol GooglePlaceService : Service {
		func getPlaces(forSearchText searchText: String, completionHandler: @escaping (Place?) -> Void)
		func search(forAddress searchText: String, completionHandler: @escaping (Place?) -> Void)
	}`
• a **protocol extension** that provides the default implementation;
• a **concrete implementation** of the service:
	`internal class GooglePlaceServiceImplementation : PrivateGooglePlaceService {`
• support for use with the SOA `ServiceRegistry`:
	- `Service.serviceName` - unique name for the service
	- `static func register()` - a convenience function to register the service with the `serviceName` with the `ServiceRegistry`
	- a `ServiceRegistry` extension that creates a convenient means of accessing the service.

In addition, **GooglePlaceService** contains some ancillary functionality:
• a protocol and extension `PrivateGooglePlaceService` that provides private implementation functionality. This hides implementation detail from the public interface.
• a mock implementation of the service used for testing.  This exemplifies the power of SOA. More on this below.

### **Service.swift**
This is core of SOA. A very simply protocol, `Service` and `ServiceRegistry`, a means for accessing services. It contains:
• `Service` is the protocol all SOA Services must implement.  They must have a unique name. (Currently, there is nothing in the system to guarantee uniqueness).
• `ServiceRegistry` is a wrapper struct around a static, associative Dictionary, `[String : Service]`.
• `SR` is a shorthand, global object for accessing the ServiceRegistry.

As in **GooglePlaceService.swift**, a service can implement a `ServiceRegistry` extension that creates a convenience computed property for accessing the service:
	`extension ServiceRegistry {
		var googlePlaceService : GooglePlaceService {
			get {
				return serviceWith(name: GooglePlaceServiceName.serviceName) as! GooglePlaceService	// Intentional force unwrapping
			}
		}
	}`
Application code can then access the service like this:
	`let googlePlaceService = SR.googlePlaceService`
and call a service function:
	`googlePlaceService.getPlaces(forSearchText: searchText)`

• `static func register()` - as mentioned above, services implement a convenience function to register themselves with the `ServiceRegistry`.
SOA Services are typically registered at App startup.  In this project, in `AppDelegate.application(application:, didFinishLaunchingWithOptions:).`
 • `GooglePlaceServiceMockImplementation.register()`
 You will also see in `application(application:, didFinishLaunchingWithOptions:)`, a commented out line:
	 `// GooglePlaceServiceMockImplementation.register()`
Because I was unable to get the Google address geocoding endpoint working, I created a mock test implementation that returns the expected json to verify that I am parsing it correctly. By simply registering my mock implementation instead of the production version, I could test as much of my code as possible. This exemplifies the power of SOA.  You can see the `GooglePlaceServiceMockImplementation` in GooglePlaceService.swift, line 172.

### **class GoogleGeocodingRequest : UnauthenticatedDataRequest**

