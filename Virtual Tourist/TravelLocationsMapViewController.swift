//
//  TravelLocationsMapViewController.swift
//  Virtual Tourist
//
//  Created by Sangeetha on 12/1/15.
//  Copyright © 2015 Sangeetha. All rights reserved.
//

import UIKit
import MapKit
import CoreData

class TravelLocationsMapViewController: UIViewController, MKMapViewDelegate {
    
    @IBOutlet weak var mapView: MKMapView!
    
    var longPressGestureRecognizer: UILongPressGestureRecognizer?
    
    // Get the managed object context5
    lazy var sharedContext: NSManagedObjectContext = {
        return CoreDataStackManager.sharedInstance().managedObjectContext!
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.navigationController!.navigationBarHidden = true
        // Do any additional setup after loading the view.
        
        // Prepare the map view
       
        mapView.delegate = self
        restoreMapRegion(false)
        
        // Add the long press gesture recognizer to the map view
        let longPressGestureRecognizer = UILongPressGestureRecognizer(target: self, action: "addPinToMap:")
        mapView.addGestureRecognizer(longPressGestureRecognizer)
        
        }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    //To persist the mapview region each time the app restarts
    
    var filePath : String {
        let manager = NSFileManager.defaultManager()
        let url = manager.URLsForDirectory(.DocumentDirectory, inDomains: .UserDomainMask).first! as NSURL
        return url.URLByAppendingPathComponent("mapRegionArchive").path!
    }
    
    func saveMapRegion() {
        
        // Place the "center" and "span" of the map into a dictionary
        // The "span" is the width and height of the map in degrees.
        // It represents the zoom level of the map.
        
        let dictionary = [
            "latitude" : mapView.region.center.latitude,
            "longitude" : mapView.region.center.longitude,
            "latitudeDelta" : mapView.region.span.latitudeDelta,
            "longitudeDelta" : mapView.region.span.longitudeDelta
        ]
        
        // Archive the dictionary into the filePath
        NSKeyedArchiver.archiveRootObject(dictionary, toFile: filePath)
    }
    
    func restoreMapRegion(animated: Bool) {
        
        // if we can unarchive a dictionary, we will use it to set the map back to its
        // previous center and span
        if let regionDictionary = NSKeyedUnarchiver.unarchiveObjectWithFile(filePath) as? [String : AnyObject] {
            
            let longitude = regionDictionary["longitude"] as! CLLocationDegrees
            let latitude = regionDictionary["latitude"] as! CLLocationDegrees
            let center = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
            
            let longitudeDelta = regionDictionary["latitudeDelta"] as! CLLocationDegrees
            let latitudeDelta = regionDictionary["longitudeDelta"] as! CLLocationDegrees
            let span = MKCoordinateSpan(latitudeDelta: latitudeDelta, longitudeDelta: longitudeDelta)
            
            let savedRegion = MKCoordinateRegion(center: center, span: span)
            
            print("lat: \(latitude), lon: \(longitude), latD: \(latitudeDelta), lonD: \(longitudeDelta)")
            
            mapView.setRegion(savedRegion, animated: animated)
            
            // Now get all the pins that are stored in CoreData and add them to the map
            let pinFetchRequest = NSFetchRequest(entityName: "Pin")
            do {
                let pins = try sharedContext.executeFetchRequest(pinFetchRequest) as! [Pin]
                dispatch_async(dispatch_get_main_queue(), {
                    self.mapView.addAnnotations(pins)
                })
                
            } catch let error as NSError {
                print("Error fetching pins from CoreData: \(error)")
            }

        }
    }
    
    func mapView(mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
        saveMapRegion()
    }
    
    // MARK: - Navigation
    
    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        // Set the pin for the PhotoViewController
        let photoController = segue.destinationViewController as! PhotoCollectionViewController
        let pin = sender as? Pin
        photoController.pin = pin
    }
   
    // Add a pin to the map when the user does a long press on the map.
    func addPinToMap(gestureRecogizer: UILongPressGestureRecognizer) {
        if gestureRecogizer.state == UIGestureRecognizerState.Ended {
            // Get the map coordinates from the point where the user pressed
            let coordinate = mapView.convertPoint(gestureRecogizer.locationInView(self.mapView), toCoordinateFromView: self.mapView)
            // Create a new pin
            let pin = Pin(latitude: coordinate.latitude, longitude: coordinate.longitude, photos: NSSet(), context: sharedContext)
            do {
                try
                    self.sharedContext.save()
            } catch let error  as NSError {
                print("Error saving new pin: \(error)")
            }
            // Update the map view with the new pin
            dispatch_async(dispatch_get_main_queue(), {
                self.mapView.addAnnotation(pin)
            })
        }
        
    }
    
    
    // Get the view for the pin's annotation
    func mapView(mapView: MKMapView, viewForAnnotation annotation: MKAnnotation) -> MKAnnotationView? {
        let reuseIdentifier = "pin"
        var view = mapView.dequeueReusableAnnotationViewWithIdentifier(reuseIdentifier) as? MKPinAnnotationView
        if view == nil {
            view = MKPinAnnotationView(annotation: annotation, reuseIdentifier: reuseIdentifier)
        }
        
        return view
    }
    
    // When the user taps the pin we will segue to the photo collection
    func mapView(mapView: MKMapView, didSelectAnnotationView view: MKAnnotationView) {
        // Fetch the pin from CoreData based on the latitude and longitude of the annotation view.
        let fetchRequest = NSFetchRequest(entityName: "Pin")
        
        let latitudePredicate = NSPredicate(format: "latitude = %@", NSNumber(double: (view.annotation?.coordinate.latitude)!))
        let longitudePredicate = NSPredicate(format: "longitude = %@", NSNumber(double: (view.annotation?.coordinate.longitude)!))
        fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [latitudePredicate, longitudePredicate])
        var pin: Pin
        do {
            let result = try sharedContext.executeFetchRequest(fetchRequest) as! [Pin]
            if result.count > 0 {
                pin = result.first! as Pin
                self.mapView.deselectAnnotation(view.annotation, animated: true)
                self.performSegueWithIdentifier("showPhotos", sender: pin)
            }
        } catch let error as NSError {
            print("Error fetching pin for the annotation view: \(error)")
        }
    }
}

    






