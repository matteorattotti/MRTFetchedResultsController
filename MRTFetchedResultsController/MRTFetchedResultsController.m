//
//  MRTFetchedResultsController.m
//  MRTFetchedResultsController
//
//  Created by Matteo Rattotti on 14/05/15.
//
//

#import "MRTFetchedResultsController.h"

@interface MRTFetchedResultsController ()
{
    NSMutableArray *_fetchedObjects;
    NSMutableArray *_arrangedObjects;

    BOOL didCallDelegateWillChangeContent;
    
    struct {
        BOOL delegateHasWillChangeContent;
        BOOL delegateHasDidChangeContent;
        BOOL delegateHasDidChangeObject;
    } delegateHas;
}

@property (nonatomic, strong) NSFetchRequest *arrangedObjectInMemoryFetchRequest;

@end

@interface MRTFetchedResultsUpdate : NSObject

@property (nonatomic, retain) NSManagedObject *object;
@property (nonatomic, assign) NSUInteger originalIndex;

@end

@implementation MRTFetchedResultsController

@synthesize fetchedObjects  = _fetchedObjects;
@synthesize arrangedObjects = _arrangedObjects;

#pragma mark - Initialization

- (id)initWithManagedObjectContext:(NSManagedObjectContext*)context fetchRequest:(NSFetchRequest *)request
{
    self = [super init];
    if (self) {
        _managedObjectContext = context;
        _fetchRequest = request;

        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(managedObjectContextObjectsDidChange:)
                                                     name:NSManagedObjectContextObjectsDidChangeNotification
                                                   object:_managedObjectContext];
    }
    return self;
}

#pragma mark - Dealloc

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - Fetched Objects

- (BOOL)performFetch:(NSError**)error
{
    if (!self.fetchRequest) { return NO; }
    _fetchedObjects = [NSMutableArray arrayWithArray:[self.managedObjectContext executeFetchRequest:self.fetchRequest error:error]];

    [self updateArrangedObjects];
    
    return (_fetchedObjects != nil);
}

- (id)objectAtIndex:(NSUInteger)index
{
    return [_arrangedObjects ?: _fetchedObjects objectAtIndex:index];
}

- (NSArray*)objectsAtIndexes:(NSIndexSet*)indexes
{
    return [_arrangedObjects ?: _fetchedObjects objectsAtIndexes:indexes];
}

- (NSUInteger)indexOfObject:(id)object
{
    return [_arrangedObjects ?: _fetchedObjects indexOfObject:object];
}

- (NSUInteger)count
{
    return [_arrangedObjects ?: _fetchedObjects count];
}

#pragma mark - Accessors

- (void)setDelegate:(id<MRTFetchedResultsControllerDelegate>)delegate
{
    _delegate = delegate;
    delegateHas.delegateHasWillChangeContent = [_delegate respondsToSelector:@selector(controllerWillChangeContent:)];
    delegateHas.delegateHasDidChangeContent  = [_delegate respondsToSelector:@selector(controllerDidChangeContent:)];
    delegateHas.delegateHasDidChangeObject   = [_delegate respondsToSelector:@selector(controller:didChangeObject:atIndex:forChangeType:newIndex:)];
}

- (void)setSortDescriptors:(NSArray *)sortDescriptors
{
    _sortDescriptors = sortDescriptors;
    
    [self updateArrangedObjects];
}

- (void) setFilterPredicate:(NSPredicate *)filterPredicate
{
    _filterPredicate = filterPredicate;
    
    [self updateArrangedObjects];
}

- (NSArray *) arrangedObjects
{
    if (_arrangedObjects) {
        return _arrangedObjects;
    }
    
    return _fetchedObjects;
}

- (void) updateArrangedObjects
{

    if (!_sortDescriptors && !_filterPredicate) {
        _arrangedObjects = nil;
        _arrangedObjectInMemoryFetchRequest = nil;
    }
    else {
        // Rebuilding the arrangedObjectArray
        _arrangedObjects = [NSMutableArray arrayWithArray:_fetchedObjects];
        
        // filtering with the new filter predicate
        if (_filterPredicate) {
            [_arrangedObjects filterUsingPredicate:_filterPredicate];
        }

        // resorting it
        if (_sortDescriptors) {
            [_arrangedObjects sortUsingDescriptors:_sortDescriptors];
        }

        // creating the in memory fetch request
        _arrangedObjectInMemoryFetchRequest = [[NSFetchRequest alloc] init];
        _arrangedObjectInMemoryFetchRequest.entity = _fetchRequest.entity;
        _arrangedObjectInMemoryFetchRequest.sortDescriptors = _sortDescriptors;
        _arrangedObjectInMemoryFetchRequest.predicate = _filterPredicate;
    }
}

#pragma mark - Objects change evaluation

- (void)managedObjectContextObjectsDidChange:(NSNotification*)notification
{
    if (!self.fetchRequest) { return; }
    didCallDelegateWillChangeContent = NO;
    
    // Array are way faster to enumerate than sets
    NSArray *insertedObjects = [[notification.userInfo valueForKey:NSInsertedObjectsKey] allObjects];
    NSArray *deletedObjects = [[notification.userInfo valueForKey:NSDeletedObjectsKey] allObjects];
    NSArray *updatedObjects = [[notification.userInfo valueForKey:NSUpdatedObjectsKey] allObjects];
    NSArray *refreshedObjects = [[notification.userInfo valueForKey:NSRefreshedObjectsKey] allObjects];
    
    BOOL notifyDelegateForFetchedObjects = YES;
    
    // Evaluating for arrangedObjects
    if (_arrangedObjects) {
        notifyDelegateForFetchedObjects = NO;
        
        // Objects to insert and sort at the end
        NSMutableArray *inserted = [NSMutableArray array];

        [self evaluateDeletedObjects:deletedObjects inContainer:_arrangedObjects fetchRequest:self.arrangedObjectInMemoryFetchRequest notifyDelegate:YES];
        [self evaluateUpdatedObjects:updatedObjects inContainer:_arrangedObjects fetchRequest:self.arrangedObjectInMemoryFetchRequest notifyDelegate:YES newlyInsertedObjects:inserted forceResort:NO];
        [self evaluateUpdatedObjects:refreshedObjects inContainer:_arrangedObjects fetchRequest:self.arrangedObjectInMemoryFetchRequest notifyDelegate:YES newlyInsertedObjects:inserted forceResort:YES];
        [self evaluateInsertedObjects:insertedObjects inContainer:_arrangedObjects fetchRequest:self.arrangedObjectInMemoryFetchRequest notifyDelegate:YES newlyInsertedObjects:inserted];
    }
    
    // Objects to insert and sort at the end
    NSMutableArray *inserted = [NSMutableArray array];

    // Evaluating for fetchedObjects
    [self evaluateDeletedObjects:deletedObjects inContainer:_fetchedObjects fetchRequest:self.fetchRequest notifyDelegate:notifyDelegateForFetchedObjects];
    [self evaluateUpdatedObjects:updatedObjects inContainer:_fetchedObjects fetchRequest:self.fetchRequest notifyDelegate:notifyDelegateForFetchedObjects newlyInsertedObjects:inserted forceResort:NO];
    [self evaluateUpdatedObjects:refreshedObjects inContainer:_fetchedObjects fetchRequest:self.fetchRequest notifyDelegate:notifyDelegateForFetchedObjects newlyInsertedObjects:inserted forceResort:YES];
    [self evaluateInsertedObjects:insertedObjects inContainer:_fetchedObjects fetchRequest:self.fetchRequest notifyDelegate:notifyDelegateForFetchedObjects newlyInsertedObjects:inserted];
    
    // if delegateWillChangeContent: was called then delegateDidChangeContent: must also be called
    if (didCallDelegateWillChangeContent) {
        [self delegateDidChangeContent];
    }
}

- (void) evaluateDeletedObjects: (NSArray *) deletedObjects
                    inContainer: (NSMutableArray *) container
                   fetchRequest: (NSFetchRequest *) fetchRequest
                 notifyDelegate: (BOOL) notifyDelegate
{
    NSEntityDescription *entity = [fetchRequest entity];

    for (NSManagedObject *object in deletedObjects) {
        
        // Don't care about objects of a different entity
        if (![[object entity] isKindOfEntity:entity]) { continue; }
        
        // Check to see if the content array contains the deleted object
        NSUInteger index = [container indexOfObject:object];
        if (index == NSNotFound) { continue; }
        
        // Removing object
        [container removeObjectAtIndex:index];

        // Delegate notification
        if (notifyDelegate) {
            [self delegateDidChangeObject:object atIndex:index forChangeType:MRTFetchedResultsChangeDelete newIndex:NSNotFound];
        }
        
    }
}

- (void) evaluateUpdatedObjects: (NSArray *) updatedObjects
                    inContainer: (NSMutableArray *) container
                   fetchRequest: (NSFetchRequest *) fetchRequest
                 notifyDelegate: (BOOL) notifyDelegate
           newlyInsertedObjects: (NSMutableArray *) newlyInsertedObjects
                    forceResort: (BOOL) forceResort
{
    NSEntityDescription *entity = [fetchRequest entity];
    NSPredicate *predicate = [fetchRequest predicate];
    NSArray *sortDescriptors = [fetchRequest sortDescriptors];
    NSArray *sortKeys = [sortDescriptors valueForKey:@"key"];

    NSMutableArray *updated = [NSMutableArray array];
    
    for (NSManagedObject *object in updatedObjects) {
        // Ignore objects of a different entity
        if (![[object entity] isKindOfEntity:entity]) { continue; }
        
        // Check to see if the predicate evaluates regardless of whether the object exists in the content array or not
        // because changes to the attributes of the object can result in it either being removed or added to the
        // content array depending on whether it affects the evaluation of the predicate
        BOOL predicateEvaluates = (predicate != nil) ? [predicate evaluateWithObject:object] : YES;
        NSUInteger objectIndex = [container indexOfObject:object];
        BOOL containsObject = (objectIndex != NSNotFound);
        
        // If the content array already contains the object but the update resulted in the predicate
        // no longer evaluating to TRUE, then it needs to be removed
        if (containsObject && !predicateEvaluates) {
            [container removeObjectAtIndex:objectIndex];
            if(notifyDelegate) [self delegateDidChangeObject:object atIndex:objectIndex forChangeType:MRTFetchedResultsChangeDelete newIndex:NSNotFound];
        }
        
        // If the content array does not contain the object but the object's update resulted in the predicate now
        // evaluating to TRUE, then it needs to be inserted
        else if (!containsObject && predicateEvaluates) {
            [newlyInsertedObjects addObject:object];
        }
        
        else if (containsObject) {
            // Check if the object's updated keys are in the sort keys
            // This means that the sorting would have to be updated
            BOOL sortingChanged = NO;
            
            // Refreshed objects doesn't seem to carry the "changedValuesForCurrentEvent" so the we are forced to resort
            if ([sortKeys count] && !forceResort) {
                NSMutableSet *keySet = [NSMutableSet set];
                
                [keySet addObjectsFromArray:[[object changedValuesForCurrentEvent] allKeys]];
                //[keySet addObjectsFromArray:[[object changedValues] allKeys]];
                
                NSArray *keys = [keySet allObjects];
                
                for (NSString *key in sortKeys) {
                    if ([keys containsObject:key]) {
                        sortingChanged = YES;
                        break;
                    }
                }
            }
            
            if (sortingChanged || forceResort) {
                // Create a wrapper object that keeps track of the original index for later
                MRTFetchedResultsUpdate *update = [MRTFetchedResultsUpdate new];
                update.originalIndex = objectIndex;
                update.object = object;
                [updated addObject:update];
            } else {
                // If there's no change in sorting then just update the object as-is
                if (notifyDelegate) [self delegateDidChangeObject:object atIndex:objectIndex forChangeType:MRTFetchedResultsChangeUpdate newIndex:objectIndex];
            }
        }
    }
    // If there were updated objects that changed the sorting then resort and notify the delegate of changes
    if ([updated count] && [sortDescriptors count]) {
        [container sortUsingDescriptors:sortDescriptors];
        for (MRTFetchedResultsUpdate *update in updated) {
            // Find out then new index of the object in the content array
            NSUInteger newIndex = [container indexOfObject:update.object];
            // If the new index is different from the old one
            if (update.originalIndex != newIndex && notifyDelegate) {
                [self delegateDidChangeObject:update.object atIndex:update.originalIndex forChangeType:MRTFetchedResultsChangeMove newIndex:newIndex];
            }
            // If there's no change in index then just update the object as-is
            else if(notifyDelegate){
                [self delegateDidChangeObject:update.object atIndex:newIndex forChangeType:MRTFetchedResultsChangeUpdate newIndex:newIndex];
            }
        }
    }
}



- (void) evaluateInsertedObjects: (NSArray *) insertedObjects
                     inContainer: (NSMutableArray *) container
                    fetchRequest: (NSFetchRequest *) fetchRequest
                  notifyDelegate: (BOOL) notifyDelegate
            newlyInsertedObjects: (NSMutableArray *) newlyInsertedObjects
{
    NSEntityDescription *entity = [fetchRequest entity];
    NSPredicate *predicate = [fetchRequest predicate];
    NSArray *sortDescriptors = [fetchRequest sortDescriptors];

    for (NSManagedObject *object in insertedObjects) {
        // Objects of a different entity or objects that don't evaluate to the predicate are ignored (or if the object is already contained in the container)
        if (![[object entity] isKindOfEntity:entity] || (predicate && ![predicate evaluateWithObject:object]) || [container containsObject:object]) {
            continue;
        }
        [newlyInsertedObjects addObject:object];
    }
    // If there were inserted objects then insert them into the content array and resort
    NSUInteger insertedCount = [newlyInsertedObjects count];
    if (insertedCount) {
        // Dump the inserted objects into the content array
        [container addObjectsFromArray:newlyInsertedObjects];
        
        // If there are sort descriptors, then resort the array
        if ([sortDescriptors count]) {
            [container sortUsingDescriptors:sortDescriptors];

            if (notifyDelegate) {
                // Enumerate through each of the inserted objects and notify the delegate of their new position
                [container enumerateObjectsUsingBlock:^(NSManagedObject *object, NSUInteger idx, BOOL *stop) {
                    if (![newlyInsertedObjects containsObject:object]) {
                        return;
                    }
                    
                    [self delegateDidChangeObject:object atIndex:NSNotFound forChangeType:MRTFetchedResultsChangeInsert newIndex:idx];
                }];
            }
        }
        
        // If there are no sort descriptors, then the inserted objects will just be added to the end of the array
        // so we don't need to figure out what indexes they were inserted in
        else  if(notifyDelegate){
            NSUInteger objectsCount = [container count];
            for (NSInteger i = (objectsCount - insertedCount); i < objectsCount; i++) {
                [self delegateDidChangeObject:[container objectAtIndex:i] atIndex:NSNotFound forChangeType:MRTFetchedResultsChangeInsert newIndex:i];
            }
        }
    }
   
}

#pragma mark - Notifications

- (void)delegateWillChangeContent
{
    if (delegateHas.delegateHasWillChangeContent) {
        [self.delegate controllerWillChangeContent:self];
    }
}

- (void)delegateDidChangeContent
{
    if (delegateHas.delegateHasDidChangeContent) {
        [self.delegate controllerDidChangeContent:self];
    }
}

- (void)delegateDidChangeObject:(id)anObject atIndex:(NSUInteger)index forChangeType:(MRTFetchedResultsChangeType)type newIndex:(NSUInteger)newIndex
{
    // NSLog(@"Changing object: %@\nAt index: %lu\nChange type: %d\nNew index: %lu", anObject, index, (int)type, newIndex);
    if (!didCallDelegateWillChangeContent) {
        [self delegateWillChangeContent];
        didCallDelegateWillChangeContent = YES;
    }
    if (delegateHas.delegateHasDidChangeObject) {
        [self.delegate controller:self didChangeObject:anObject atIndex:index forChangeType:type newIndex:newIndex];
    }
}

@end

#pragma mark - MRTFetchedResultsUpdate

@implementation MRTFetchedResultsUpdate
@synthesize object = sObject;
@synthesize originalIndex = sOriginalIndex;
@end