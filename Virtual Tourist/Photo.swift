//
//  Photo.swift
//  Virtual Tourist
//
//  Created by Sangeetha on 12/10/15.
//  Copyright © 2015 Sangeetha. All rights reserved.
//

import Foundation
import CoreData

class Photo: NSManagedObject {
    
    @NSManaged var path: String
    @NSManaged var id: NSNumber
    @NSManaged var photo_pin: Pin
    
       var url: NSURL?
    
    override init(entity: NSEntityDescription, insertIntoManagedObjectContext context: NSManagedObjectContext?) {
        super.init(entity:entity, insertIntoManagedObjectContext: context)
    }
    
    init(url: NSURL, pin: Pin, context: NSManagedObjectContext) {
        let entity = NSEntityDescription.entityForName("Photo", inManagedObjectContext: context)!
        super.init(entity: entity, insertIntoManagedObjectContext: context)
        
        self.url = url
        
        // Grab the lastPathComponent of the URL for the value of the path for
        // the photo.
        self.path = (url.lastPathComponent)!
        self.photo_pin = pin
        
    }
    
    // Delete the image data from the Documents directory when deleting a photo
    override func prepareForDeletion() {
        let photoPath = documentsDirectory.stringByAppendingPathComponent(path)
        do {
            // Make sure that the image data file exists. It may not exist since the photo
            // may not be in a cell that is displayed, so the photo exists, but the image
            // data has not been retrieved and stored yet.
            if NSFileManager.defaultManager().fileExistsAtPath(photoPath) {
                try NSFileManager.defaultManager().removeItemAtPath(photoPath)
            }
        } catch let error as NSError {
            print("Error deleting photo image data from Documents directory: \(error)")
        }
    }
    
    
}

