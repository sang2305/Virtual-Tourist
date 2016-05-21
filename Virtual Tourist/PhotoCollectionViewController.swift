//
//  PhotoCollectionViewController.swift
//  Virtual Tourist
//
//  Created by Sangeetha on 12/7/15.
//  Copyright © 2015 Sangeetha. All rights reserved.
//

import Foundation
import UIKit
import MapKit
import CoreData

class PhotoCollectionViewController : UIViewController,MKMapViewDelegate,UICollectionViewDataSource, UICollectionViewDelegate{

    
    @IBOutlet weak var mapView: MKMapView!
    
    @IBOutlet weak var photoCollection: UICollectionView!
    @IBOutlet weak var newCollectionButton: UIButton!
    
    var pin: Pin!
    
    let fileManager = NSFileManager.defaultManager()
    
    lazy var sharedContext: NSManagedObjectContext = {
        return CoreDataStackManager.sharedInstance().managedObjectContext!
    }()
    
    
    var fetchedResultsController: NSFetchedResultsController!

    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.mapViewwithLocation()
        self.navigationController!.navigationBarHidden = false
        newCollectionButton.enabled = false
        
        photoCollection.delegate = self
        photoCollection.dataSource   = self
        
        // Add a tap gesture recognizer to the photoCollection
        let tapRecognizer = UITapGestureRecognizer(target: self, action: "tappedCell:")
        self.photoCollection.addGestureRecognizer(tapRecognizer)
        
        fetchedResultsController = getFetchedResultsController()
        
        do {
            try fetchedResultsController.performFetch()
        } catch let error as NSError {
            print("Error fetching photos for pin: \(error)")
        }
        
        // If the fetchedResultsController did not return any objects
        // then download the photos from Flickr. Otherwise, call reloadData
        // to place the photos in the collection view.
        if fetchedResultsController.fetchedObjects?.count == 0 {
            loadPhotosFromFlickr()
        } else {
            dispatch_async(dispatch_get_main_queue(), {
                self.photoCollection.reloadData()
                self.newCollectionButton.enabled = true
            })
        }
        
 
    }
    
    override func viewDidDisappear(animated: Bool) {
        fetchedResultsController = nil
        super.viewDidDisappear(animated)
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        
    }

   
    //Actions for new Collection button
    @IBAction func newCollectionTouchUp(sender: AnyObject) {
        fetchedResultsController = nil
        deletePhotosForPin()
        loadPhotosFromFlickr()
    }
    
    func collectionView(collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        if let count = fetchedResultsController.fetchedObjects?.count {
            return count
        } else {
            return 0
        }
    }
    
    // Return a cell with the photo image
    func collectionView(collectionView: UICollectionView, cellForItemAtIndexPath indexPath: NSIndexPath) -> UICollectionViewCell {
        
        let cell = collectionView.dequeueReusableCellWithReuseIdentifier("PhotoCell", forIndexPath: indexPath) as! PhotoCollectionViewCell
        
        cell.activityIndicator.hidden = false
        cell.activityIndicator.startAnimating()
        
        // Use a placeholder image until the actual image is loaded.
        cell.imageView.image = UIImage(named: "placeholder")
        
        
        // If there are no results returned from the fetch just return the cell
        guard (fetchedResultsController.fetchedObjects?.count != 0) else {
            return cell
        }
        
        // Get the photo from the fetchedResultsController for the indexPath
        let p = fetchedResultsController.objectAtIndexPath(indexPath) as! Photo
        
        var imageData: NSData?
        
        // Check and see if the photo image data has already been stored in the Documents
        // directory. If it has, then get the image data from the file and set the image
        // property of the cell's image view.
        let photoPath = documentsDirectory.stringByAppendingPathComponent(p.path)
        if fileManager.fileExistsAtPath(photoPath) {
            imageData  = NSData(contentsOfFile: photoPath)!
            dispatch_async(dispatch_get_main_queue(), {
                cell.imageView.image = UIImage(data: imageData!)
                cell.activityIndicator.stopAnimating()
            })
        } else {
            // The image data is not in the Documents directory, so download it from Flickr.
            if let photoUrl = p.url {
                FlickrClient.sharedInstance().getPhotoFromUrl(photoUrl) { data, error in
                    // If we get data back set the cell's image with a UIImage from the data.
                    if data != nil {
                        imageData = data
                        dispatch_async(dispatch_get_main_queue(), {
                            cell.imageView.image = UIImage(data: imageData!)
                            cell.activityIndicator.stopAnimating()
                        })
                    } else {
                        dispatch_async(dispatch_get_main_queue(), {
                            cell.activityIndicator.stopAnimating()
                        })
                    }
                }
            }
        }
        
        return cell
        
    }
    
    // When a cell is tapped, delete the photo
    func tappedCell(gestureRecognizer: UITapGestureRecognizer) {
        // Map the point the user tapped to a cell in the photo collection view
        let tappedPoint: CGPoint = gestureRecognizer.locationInView(photoCollection)
        if let tappedCellPath: NSIndexPath = photoCollection.indexPathForItemAtPoint(tappedPoint) {
            let photo = fetchedResultsController.objectAtIndexPath(tappedCellPath) as! Photo
            sharedContext.deleteObject(photo)
            do {
                try sharedContext.save()
            } catch let error as NSError {
                print("Error deleting photo: \(error)")
            }
        }
    }

    
    // Returns a fetchedResultController for fetching photos associated with a pin
    func getFetchedResultsController() -> NSFetchedResultsController {
        // Fetch photo objects
        let fetchRequest = NSFetchRequest(entityName: "Photo")
        
        // Sorted by id
        let sortDescriptor = NSSortDescriptor(key: "id", ascending: true)
        fetchRequest.sortDescriptors = [sortDescriptor]
        
        // Where the photo is assocaited with the pin
        fetchRequest.predicate = NSPredicate(format: "photo_pin == %@", self.pin)
        fetchedResultsController = NSFetchedResultsController(fetchRequest: fetchRequest, managedObjectContext: sharedContext, sectionNameKeyPath: nil, cacheName: nil)
        fetchedResultsController.delegate = self
        return fetchedResultsController
    }
    
    // Delete all the photos associated with the pin
    func deletePhotosForPin() {
        if pin.pin_photo.count > 0 {
            for photo in pin.pin_photo {
                sharedContext.deleteObject(photo as! Photo)
            }
            do {
                try sharedContext.save()
            } catch let error as NSError {
                print("Error clearing photos from Pin: \(error)")
            }
        }
    }
    
    func loadPhotosFromFlickr() {
        newCollectionButton.enabled = false
       
        fetchedResultsController = getFetchedResultsController()
        
        FlickrClient.sharedInstance().downloadImagesFromFlickr(pin) { success, error in
            guard (error == nil) else {
                print("getPhotosForPin returned an error: \(error)")
                return
            }
            
            if (success) {
                do {
                    // Fetch the photos from CoreData and display them in the
                    // collection view.
                    try self.fetchedResultsController.performFetch()
                    dispatch_async(dispatch_get_main_queue(), {
                        self.photoCollection.reloadData()
                        self.newCollectionButton.enabled = true
                    })
                    
                } catch let error as NSError {
                    print("Error fetching photos for pin: \(error)")
                }
            } else {
                // No photos were found for the location specified by the
                // pin, so display the "No Photos" alert
                dispatch_async(dispatch_get_main_queue(), {
                    let alertController = UIAlertController(title: "No Photos Found for the given location", message: nil, preferredStyle: UIAlertControllerStyle.Alert)
                    alertController.addAction(UIAlertAction(title: "Dismiss", style: UIAlertActionStyle.Default, handler: nil))
                    self.presentViewController(alertController, animated: true, completion: nil)
                    return
                })
                
            }
        }
    }


    
    //To display mapview with the selected pin location
    func mapViewwithLocation(){
        let pinlocation = CLLocationCoordinate2D(latitude: pin.coordinate.latitude, longitude: pin.coordinate.longitude)
        let region = MKCoordinateRegionMake(pinlocation, MKCoordinateSpanMake(0.4, 0.4))
        mapView.setRegion(region, animated: true)
        let annotation = MKPointAnnotation()
        annotation.coordinate = pinlocation
        mapView.addAnnotation(annotation)

    }
    
}

extension PhotoCollectionViewController: NSFetchedResultsControllerDelegate {
    
    // When a photo is deleted, the fetchedResultsController has the photoCollection reload data
    func controller(controller: NSFetchedResultsController, didChangeObject anObject: AnyObject, atIndexPath indexPath: NSIndexPath?, forChangeType type: NSFetchedResultsChangeType, newIndexPath: NSIndexPath?) {
        switch type {
        case .Insert:
            break
        case .Delete:
            photoCollection.deleteItemsAtIndexPaths([indexPath!])
            dispatch_async(dispatch_get_main_queue(), {
                self.photoCollection.reloadData()
            })
        case .Update:
            break
        case .Move:
            break
        }
    }
}

