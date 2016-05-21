//
//  FlickrClient.swift
//  Virtual Tourist
//
//  Created by Sangeetha on 12/10/15.
//  Copyright © 2015 Sangeetha. All rights reserved.
//

import Foundation
import UIKit
import CoreData

let BASE_URL = "https://api.flickr.com/services/rest/"
let METHOD_NAME = "flickr.photos.search"
let API_KEY = "a77c536bed8f7827e6b68c3d2c2f85de"
let EXTRAS = "url_m"
let SAFE_SEARCH = "1"
let DATA_FORMAT = "json"
let NO_JSON_CALLBACK = "1"
let BOUNDING_BOX_HALF_WIDTH = 1.0
let BOUNDING_BOX_HALF_HEIGHT = 1.0
let LAT_MIN = -90.0
let LAT_MAX = 90.0
let LON_MIN = -180.0
let LON_MAX = 180.0
let PER_PAGE = 30


let documentsDirectory: NSString = NSSearchPathForDirectoriesInDomains(.DocumentDirectory, .UserDomainMask, true)[0]
var pin: Pin!

class FlickrClient : NSObject{
    
    /* Shared session */
    var session: NSURLSession
    
    lazy var sharedContext: NSManagedObjectContext = {
        return CoreDataStackManager.sharedInstance().managedObjectContext!
    }()
    

    
    override init() {
        session = NSURLSession.sharedSession()
        super.init()
    }
    
    func downloadImagesFromFlickr(pin: Pin, completion_handler: (success:Bool, errorString:String?)-> Void){
        let methodArguments = [
            "method": METHOD_NAME,
            "api_key": API_KEY,
            "bbox": createBoundingBoxString(pin),
            "safe_search": SAFE_SEARCH,
            "extras": EXTRAS,
            "format": DATA_FORMAT,
            "nojsoncallback": NO_JSON_CALLBACK,
            "per_page":PER_PAGE
           ]
        
        self.getImageFromFlickrBySearch(pin,methodArguments: methodArguments as! [String : AnyObject]){success,errorString in
            if success{
                completion_handler(success: true, errorString: nil)
            }else{
                completion_handler(success: false, errorString: errorString)
            }
 
    }
    }
    
    
    func getImageFromFlickrBySearch(pin: Pin, methodArguments: [String : AnyObject], completionHandler: (success: Bool,  errorString: String?) -> Void){
        let urlString = BASE_URL + escapedParameters(methodArguments)
        let url = NSURL(string: urlString)!
        let request = NSURLRequest(URL: url)
        
        let task = session.dataTaskWithRequest(request) {data, response, downloadError in
            if let error = downloadError {
                completionHandler(success: false, errorString: "Could not complete the request \(error)")
                
            } else {
                let parsedResult = (try! NSJSONSerialization.JSONObjectWithData(data!, options: NSJSONReadingOptions.AllowFragments)) as! NSDictionary
                
                if let photosDictionary = parsedResult.valueForKey("photos") as? [String:AnyObject] {
                    
                    if let totalPages = photosDictionary["pages"] as? Int {
                        
                        
                        /* Flickr API - will only return up the 4000 images (100 per page * 40 page max) */
                        let pageLimit = min(totalPages, 40)
                        let randomPage = Int(arc4random_uniform(UInt32(pageLimit))) + 1
                        self.getImageFromFlickrBySearchWithPage(pin,methodArguments: methodArguments, pageNumber: randomPage) { success,  errorString in
                            if success {
                                completionHandler(success: true, errorString: nil)
                            } else {
                                completionHandler(success: false, errorString: errorString)
                            }
                        }
                        
                    } else {
                        completionHandler(success: false, errorString: "Cant find key 'pages' in \(photosDictionary)")
                    }
                } else {
                    completionHandler(success: false, errorString: "Cant find key 'photos' in \(parsedResult)")
                }
            }
        }
        
        task.resume()

        
            }
    
    func getImageFromFlickrBySearchWithPage(pin: Pin, methodArguments: [String : AnyObject], pageNumber: Int, completionHandler: (success: Bool, errorString: String?) -> Void) {
        
        /* Add the page to the method's arguments */
        var withPageDictionary = methodArguments
        withPageDictionary["page"] = pageNumber
        
        //let session = NSURLSession.sharedSession()
        let urlString = BASE_URL + escapedParameters(withPageDictionary)
        let url = NSURL(string: urlString)!
        let request = NSURLRequest(URL: url)
        
        let task = session.dataTaskWithRequest(request) {data, response, downloadError in
            if let _ = downloadError {
                completionHandler(success: false, errorString: "Error Handling Request")
            } else {
                let parsedResult = (try! NSJSONSerialization.JSONObjectWithData(data!, options: NSJSONReadingOptions.AllowFragments)) as! NSDictionary
                
                guard let stat = parsedResult["stat"] as? String where stat == "ok" else {
                    print("Flickr API returned an error. See error code and message in \(parsedResult)")
                    return
                }
                
                guard let photosDictionary = parsedResult.valueForKey("photos") as? NSDictionary else {
                    print("Cannot find key 'photos' in \(parsedResult)")
                    return
                }
                
                guard let totalPhotos = (photosDictionary["total"] as? NSString)?.integerValue else {
                    print("Cannot find key 'total' in \(parsedResult)")
                    return
                }
                
                if totalPhotos > 0 {
                    
                    guard let photosArray = photosDictionary["photo"] as? [[String : AnyObject]] else {
                        print("Cannot find key 'photo' in \(photosDictionary)")
                        return
                    }
                    
                    let photoSet: NSMutableSet = NSMutableSet()
                    
                    // For each result returned from Flickr, create a photo object and add it to
                    // the set of photos
                    for photo in photosArray {
                        self.sharedContext.performBlockAndWait({
                            // Create a new Photo object
                            let newPhoto = Photo(url: self.getFlickrUrlForPhoto(photo), pin: pin, context: self.sharedContext)
                            
                            // Get the image data from the photo's URL and store it in the Documents directory
                            self.getPhotoFromUrl(newPhoto.url!) { data, error in
                                guard (error == nil) else {
                                    return
                                }
                            }
                            photoSet.addObject(newPhoto)
                        })
                    }
                    
                    completionHandler(success: true, errorString: nil)
                }
                              
                
            }
        }
        
        task.resume()

          }
    
    // MARK: Escape HTML Parameters
    
    func escapedParameters(parameters: [String : AnyObject]) -> String {
        
        var urlVars = [String]()
        
        for (key, value) in parameters {
            
            /* Make sure that it is a string value */
            let stringValue = "\(value)"
            
            /* Escape it */
            let escapedValue = stringValue.stringByAddingPercentEncodingWithAllowedCharacters(NSCharacterSet.URLQueryAllowedCharacterSet())
            
            /* Append it */
            urlVars += [key + "=" + "\(escapedValue!)"]
            
        }
        
        return (!urlVars.isEmpty ? "?" : "") + urlVars.joinWithSeparator("&")
    }

    func createBoundingBoxString(pin: Pin) -> String {
        
        let latitude = pin.latitude as Double
        let longitude = pin.longitude as Double
        
        /* Fix added to ensure box is bounded by minimum and maximums */
        let bottom_left_lon = max(longitude - BOUNDING_BOX_HALF_WIDTH, LON_MIN)
        let bottom_left_lat = max(latitude - BOUNDING_BOX_HALF_HEIGHT, LAT_MIN)
        let top_right_lon = min(longitude + BOUNDING_BOX_HALF_HEIGHT, LON_MAX)
        let top_right_lat = min(latitude + BOUNDING_BOX_HALF_HEIGHT, LAT_MAX)
        
        return "\(bottom_left_lon),\(bottom_left_lat),\(top_right_lon),\(top_right_lat)"
    }

    // Retrieve the photo image data from Flickr using the URL of the photo.
    // This will run in the background.
    func getPhotoFromUrl(url: NSURL, completionHandler: (data: NSData?, error: NSError?) -> Void) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0)) {
            // If Flickr returned data, then write it to the Documents directory
            if let imageData = NSData(contentsOfURL:url) {
                let photoPath = documentsDirectory.stringByAppendingPathComponent(url.lastPathComponent!)
                imageData.writeToFile(photoPath, atomically: true)
                completionHandler(data: imageData, error: nil)
            } else {
                completionHandler(data: nil, error: NSError(domain: "getPhotoFromUrl", code: -1, userInfo: [NSLocalizedDescriptionKey : "Could not retrieve image fron url"]))
            }
        }
    }

    
    // Returns the URL for a Flickr photo from the photo data Flickr sent back in the response.
    func getFlickrUrlForPhoto(photoData : [String : AnyObject]) -> NSURL {
        // The URL has the form: https://farm{farm-id}.staticflickr.com/{server-id}/{id}_{secret}_[mstzb].jpg
        var farm = photoData["farm"] as? String
        if farm == nil {
            farm = "1"
        }
        let server = photoData["server"] as? String
        let id = photoData["id"] as? String
        let secret = photoData["secret"] as? String
        
        return NSURL(string: "https://farm\(farm!).staticflickr.com/\(server!)/\(id!)_\(secret!)_m.jpg")!
    }


class func sharedInstance() -> FlickrClient {
    
    struct Singleton {
        static var sharedInstance = FlickrClient()
    }
    
    return Singleton.sharedInstance
}
    
}

