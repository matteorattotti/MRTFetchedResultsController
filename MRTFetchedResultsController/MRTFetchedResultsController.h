//
//  MRTFetchedResultsController.h
//  MRTFetchedResultsController
//
//  Created by Matteo Rattotti on 14/05/15.
//
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

enum {
    MRTFetchedResultsChangeInsert = 1,
    MRTFetchedResultsChangeDelete = 2,
    MRTFetchedResultsChangeMove   = 3,
    MRTFetchedResultsChangeUpdate = 4,
};
typedef NSUInteger MRTFetchedResultsChangeType;

@protocol MRTFetchedResultsControllerDelegate;

@interface MRTFetchedResultsController : NSObject <NSCopying>

@property (nonatomic, assign) id<MRTFetchedResultsControllerDelegate> delegate;

/** 
 Objects fetched from the managed object context. -performFetch: must be called before accessing fetchedObjects, otherwise a nil array will be returned 
 */
@property (nonatomic, retain, readonly) NSArray *fetchedObjects;

/** 
 Objects fetched from the managed object context and arranged using the filterPredicate and the sortDescriptors.
 If filterPredicate and sortDescriptors are not set, this will return the fetchedObjects
 */
@property (nonatomic, retain, readonly) NSArray *arrangedObjects;

/** Managed object context and fetch request used to execute the fetch */
@property (nonatomic, retain, readonly) NSManagedObjectContext *managedObjectContext;
@property (nonatomic, retain, readonly) NSFetchRequest *fetchRequest;

/** In memory filter and sorts, affects the arrangedObjects array */
@property (nonatomic, strong) NSPredicate *filterPredicate;
@property (nonatomic, copy) NSArray *sortDescriptors;

/**
 Creates a new SNRFetchedResultsController object with the specified managed object context and fetch request
 @param context The managed object context
 @param request The fetch request
 */
- (id)initWithManagedObjectContext:(NSManagedObjectContext*)context fetchRequest:(NSFetchRequest*)request;

/**
 Performs a fetch to populate the fetchedObjects array. Will immediately return NO if there is no fetchRequest
 @param error A pointer to an NSError object that can be used to retrieve more detailed error information in the case of a failure
 @return A BOOL indicating whether the fetch was successful
 */
- (BOOL)performFetch:(NSError**)error;

/** These are just a few wrapper methods to allow easy access to the fetchedObjects array */
- (id)objectAtIndex:(NSUInteger)index;
- (NSArray*)objectsAtIndexes:(NSIndexSet*)indexes;
- (NSUInteger)indexOfObject:(id)object;
- (NSUInteger)count;

@end


@protocol MRTFetchedResultsControllerDelegate <NSObject>
@optional
/**
 Called right before the controller is about to make one or more changes to the content array
 @param controller The fetched results controller
 */
- (void)controllerWillChangeContent:(MRTFetchedResultsController *)controller;
/**
 Called right after the controller has made one or more changes to the content array
 @param controller The fetched results controller
 */
- (void)controllerDidChangeContent:(MRTFetchedResultsController *)controller;
/**
 Called for each change that is made to the content array. This method will be called multiple times throughout the change processing.
 @param controller The fetched results controller
 @param anObject The object that was updated, deleted, inserted, or moved
 @param index The original index of the object. If the object was inserted and did not exist previously, this will be NSNotFound
 @param type The type of change (update, insert, delete, or move)
 @param newIndex The new index of the object. If the object was deleted, the newIndex will be NSNotFound.
 */
- (void)controller:(MRTFetchedResultsController *)controller didChangeObject:(id)anObject atIndex:(NSUInteger)index forChangeType:(MRTFetchedResultsChangeType)type newIndex:(NSUInteger)newIndex;

/**
 Called for each change that is made to the content array. This method will be called multiple times throughout the change processing.
 If the delegate implement this methods this will called instead of controller:didChangeObject:atIndex:forChangeType:newIndex:
 @param controller The fetched results controller
 @param anObject The object that was updated, deleted, inserted, or moved
 @param index The original index of the object. If the object was inserted and did not exist previously, this will be NSNotFound
 @param progressiveIndex the original index corrected keeping in consideration the previous change in the same batch (Usefull for keeping another array in sync, or for macOS NSTableView as it does't batch changes like on iOS
 @param type The type of change (update, insert, delete, or move)
 @param newIndex The new index of the object. If the object was deleted, the newIndex will be NSNotFound.
 @param newProgressiveIndex new index of the object keeping in consideration the previous change in the same batch.
 */
- (void)controller:(MRTFetchedResultsController *)controller didChangeObject:(id)anObject atIndex:(NSUInteger)index progressiveIndex:(NSUInteger) progressiveIndex forChangeType:(MRTFetchedResultsChangeType)type newIndex:(NSUInteger)newIndex newProgressiveIndex:(NSUInteger) newProgressiveIndex;

@end
