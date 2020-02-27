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

@class MRTFetchedResultsControllerChange;
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
 Creates a new MRTFetchedResultsController object with the specified managed object context and fetch request
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

#pragma mark - BEFORE THE CHANGES ARE APPLIED

/**
 Called right before the controller is about to make one or more changes to the content array
 @param controller The fetched results controller
 */
- (void)fetchedResultsControllerWillBeginChanging:(MRTFetchedResultsController *)controller;

#pragma mark - THE CHANGES ARE BEING APPLIED
/* Implement *only one* of these callbacks (if more than one are implemented - only the one with more arguments will be called) */

/**
 Called for each change that is made to the content array. This method could be called multiple times throughout the change processing. This method is called if fetchedResultsController:didChange:progressiveChange: is not implemented
 @param controller The fetched results controller
 @param change The complete information of the change referred to the initial state of the managed objects
 */
- (void)fetchedResultsController:(MRTFetchedResultsController *)controller
                       didChange:(MRTFetchedResultsControllerChange *)change;

/**
 Called for each change that is made to the content array. This method could be called multiple times throughout the change processing. If this method is implemented no other didChange callback is called
 @param controller The fetched results controller
 @param change The complete information of the change referred to the initial state of the managed objects
 @param progressiveChange The complete information of the change with the indexes referred to the state of the managed objects after the previous changes are applied
 */
- (void)fetchedResultsController:(MRTFetchedResultsController *)controller
                       didChange:(MRTFetchedResultsControllerChange *)change
               progressiveChange:(MRTFetchedResultsControllerChange *)progressiveChange;

#pragma mark - AFTER THE CHANGES ARE APPLIED
/* Implement *only one* of these callbacks (if more than one are implemented - only the one with more arguments will be called) */

/**
 Called right after the controller has finished making changes to the content array. This method is called if fetchedResultsController:didChangeContent:progressiveChange AND fetchedResultsController:didChangeContent are both not implemented
 @param controller The fetched results controller
 */
- (void)fetchedResultsControllerDidEndChanging:(MRTFetchedResultsController *)controller;

/**
 Called right after the controller has finished making changes to the content array. This method is called if fetchedResultsController:didChangeContent:progressiveChange is not implemented
 @param controller The fetched results controller
 @param changes The array of changes performed in the current change batch referred to the initial state of the managed objects before the changes batch
 */
- (void)fetchedResultsController:(MRTFetchedResultsController *)controller
                  didEndChanging:(NSArray <MRTFetchedResultsControllerChange *> *)changes;

/**
 Called right after the controller has finished making changes to the content array. If this method is implemented no other didEndChanging: callback is called
 @param controller The fetched results controller
 @param changes The array of changes performed in the current change batch referred to the initial state of the managed objects before the changes batch
 @param progressiveChanges The array of changes performed in the current change batch each referred to the state/indexes of the managed objects after the previous change was applied
 */
- (void)fetchedResultsController:(MRTFetchedResultsController *)controller
                  didEndChanging:(NSArray <MRTFetchedResultsControllerChange *> *)changes
              progressiveChanges:(NSArray <MRTFetchedResultsControllerChange *> *)progressiveChanges;

@end


@interface MRTFetchedResultsControllerChange : NSObject

/**
 Changed object
 */
@property (nonatomic, strong, readonly) NSManagedObject *object;
/**
 The type of change (update, insert, delete, or move)
 */
@property (nonatomic, assign, readonly) MRTFetchedResultsChangeType type;
/**
 The original index of the object. If the object was inserted and did not exist previously, this will be NSNotFound
 */
@property (nonatomic, assign, readonly) NSUInteger index;
/**
 The new index of the object. If the object was deleted, the newIndex will be NSNotFound.
 */
@property (nonatomic, assign, readonly) NSUInteger newIndex;

@end
