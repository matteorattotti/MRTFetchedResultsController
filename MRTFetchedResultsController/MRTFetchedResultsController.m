//
//  MRTFetchedResultsController.m
//  MRTFetchedResultsController
//
//  Created by Matteo Rattotti on 14/05/15.
//
//

#import "MRTFetchedResultsController.h"

const NSString *SFNewContainerKey = @"SFNewContainerKey";

struct MRTFetchedResultsControllerDelegateHasMethods {
    BOOL delegateHasWillBeginChanging;
    BOOL delegateHasDidChangeWithChanges;
    BOOL delegateHasDidChangeWithProgressiveChanges;
    BOOL delegateHasDidEndChanging;
    BOOL delegateHasDidEndChangingWithChanges;
    BOOL delegateHasDidEndChangingWithProgressiveChanges;
};

@interface MRTFetchedResultsControllerChange ()

@property (nonatomic, strong, readwrite) NSManagedObject *object;
@property (nonatomic, assign, readwrite) MRTFetchedResultsChangeType type;
@property (nonatomic, assign, readwrite) NSUInteger index;
@property (nonatomic, assign, readwrite) NSUInteger newIndex;

@property (nonatomic, assign) NSUInteger computedHash;

- (instancetype)initWithObject:(id)anObject
                         index:(NSUInteger)index
                      newIndex:(NSUInteger)newIndex
                          type:(MRTFetchedResultsChangeType)type;

@end

@interface MRTFetchedResultsController ()
{
    NSMutableArray *_fetchedObjects;
    NSMutableArray *_arrangedObjects;
}

@property (nonatomic, strong) NSFetchRequest *arrangedObjectInMemoryFetchRequest;

@property (nonatomic, retain) NSManagedObjectContext *managedObjectContext;
@property (nonatomic, retain) NSFetchRequest *fetchRequest;

@property (nonatomic, retain) NSArray *fetchedObjects;
@property (nonatomic, retain) NSArray *arrangedObjects;

@property (nonatomic) struct MRTFetchedResultsControllerDelegateHasMethods delegateHas;

@property (nonatomic, strong) NSMutableArray <MRTFetchedResultsControllerChange *> *currentBatchChanges;
@property (nonatomic, strong) NSMutableArray <MRTFetchedResultsControllerChange *> *currentBatchProgressiveChanges;

@end


@implementation MRTFetchedResultsController

#pragma mark - Initialization

- (id)initWithManagedObjectContext:(NSManagedObjectContext*)context fetchRequest:(NSFetchRequest *)request
{
    self = [super init];
    if (self) {
        
        _managedObjectContext = context;
        _fetchRequest = request;
    }

    return self;
}

#pragma mark - NSCopying

- (id)copyWithZone:(NSZone *)zone
{
    typeof(self) copy = [[[self class] alloc] init];
    
    copy.delegate = _delegate;
    copy.delegateHas = _delegateHas;

    copy.managedObjectContext = _managedObjectContext;
    copy.fetchRequest = [_fetchRequest copy];
    copy.arrangedObjectInMemoryFetchRequest = [_arrangedObjectInMemoryFetchRequest copy];
    
    copy.fetchedObjects = [_fetchedObjects mutableCopy];
    copy.arrangedObjects = [_arrangedObjects mutableCopy];
    
    copy.filterPredicate = [self.filterPredicate copy];
    copy.sortDescriptors = [self.sortDescriptors copy];
    
    [copy setupMocObserver];

    return copy;
}

#pragma mark - Dealloc

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - Moc Observation

- (void) setupMocObserver
{
    // Processing changes to avoid notification about objects we alrady have
    [self.managedObjectContext processPendingChanges];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(managedObjectContextObjectsDidChange:)
                                                 name:NSManagedObjectContextObjectsDidChangeNotification
                                               object:_managedObjectContext];
}

#pragma mark - Fetched Objects

- (BOOL)performFetch:(NSError**)error
{
    if (!self.fetchRequest) { return NO; }
    
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
    _fetchedObjects = [NSMutableArray arrayWithArray:[self.managedObjectContext executeFetchRequest:self.fetchRequest error:error]];

    BOOL success = (_fetchedObjects != nil);
    
    if (success) {
        // Arranging objects
        //[self updateArrangedObjects];
        [self filterArrangedObjects];
        [self sortArrangedObjects];
        
        // Setting us as observer of the managed object context
        [self setupMocObserver];
    }
    
    return success;
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
    _delegateHas.delegateHasWillBeginChanging = [_delegate respondsToSelector:@selector(fetchedResultsControllerWillBeginChanging:)];
    _delegateHas.delegateHasDidChangeWithChanges = [_delegate respondsToSelector:@selector(fetchedResultsController:didChange:)];
    _delegateHas.delegateHasDidChangeWithProgressiveChanges = [_delegate respondsToSelector:@selector(fetchedResultsController:didChange:progressiveChange:)];
    _delegateHas.delegateHasDidEndChanging = [_delegate respondsToSelector:@selector(fetchedResultsControllerDidEndChanging:)];
    _delegateHas.delegateHasDidEndChangingWithChanges = [_delegate respondsToSelector:@selector(fetchedResultsController:didEndChanging:)];
    _delegateHas.delegateHasDidEndChangingWithProgressiveChanges = [_delegate respondsToSelector:@selector(fetchedResultsController:didEndChanging:progressiveChanges:)];
}

- (void)setSortDescriptors:(NSArray *)sortDescriptors
{
    _sortDescriptors = sortDescriptors;
    
    [self sortArrangedObjects];
}

- (void) setFilterPredicate:(NSPredicate *)filterPredicate
{
    _filterPredicate = filterPredicate;
    
    [self filterArrangedObjects];
}

- (NSArray *) arrangedObjects
{
    if (_arrangedObjects) {
        return _arrangedObjects;
    }
    
    return _fetchedObjects;
}

- (void)filterArrangedObjects
{
    if (!_sortDescriptors && !_filterPredicate) {
        _arrangedObjects = nil;
    }
    else {
        // Rebuilding the arrangedObjectArray
        _arrangedObjects = [NSMutableArray arrayWithArray:_fetchedObjects];
        
        // filtering with the new filter predicate
        if (_filterPredicate) {
            [_arrangedObjects filterUsingPredicate:_filterPredicate];
        }
    }
    
    [self updateArrangedObjectInMemoryFetchRequest];
}

- (void)sortArrangedObjects
{
    if (!_sortDescriptors && !_filterPredicate) {
        _arrangedObjects = nil;
    }
    else {
        // resorting it
        if (_sortDescriptors) {
            if (!_arrangedObjects) {
                _arrangedObjects = [NSMutableArray arrayWithArray:_fetchedObjects];
            }
            [_arrangedObjects sortUsingDescriptors:_sortDescriptors];
        }
    }
    
    [self updateArrangedObjectInMemoryFetchRequest];
}

- (void)updateArrangedObjectInMemoryFetchRequest
{
    if (!_sortDescriptors && !_filterPredicate) {
        _arrangedObjectInMemoryFetchRequest = nil;
    }
    else {
        
        // creating the in memory fetch request
        _arrangedObjectInMemoryFetchRequest = [[NSFetchRequest alloc] init];
        _arrangedObjectInMemoryFetchRequest.entity = _fetchRequest.entity;
        
        // Adding the sort descriptor (the custom one, or the original one, or nothing)
        if (_sortDescriptors) {
            _arrangedObjectInMemoryFetchRequest.sortDescriptors = _sortDescriptors;
        }
        else if(_fetchRequest.sortDescriptors) {
            _arrangedObjectInMemoryFetchRequest.sortDescriptors = _fetchRequest.sortDescriptors;
        }
        else {
            _arrangedObjectInMemoryFetchRequest.sortDescriptors = nil;
        }
        
        // Adding the predicate, need the fetch request one + the filter one
        NSMutableArray *predicates = [NSMutableArray array];
        if (_filterPredicate) { [predicates addObject:_filterPredicate]; }
        if (_fetchRequest.predicate) { [predicates addObject:_fetchRequest.predicate]; }
        
        if (predicates.count) {
            NSPredicate * inMemoryPredicate = [NSCompoundPredicate andPredicateWithSubpredicates:predicates];
            _arrangedObjectInMemoryFetchRequest.predicate = inMemoryPredicate;
        }
        else {
            _arrangedObjectInMemoryFetchRequest.predicate = nil;
        }
    }
}

#pragma mark - Objects change evaluation

- (void)managedObjectContextObjectsDidChange:(NSNotification*)notification
{
    if (!self.fetchRequest) { return; }
    
    // Array are way faster to enumerate than sets
    NSArray *insertedObjects = [[notification.userInfo valueForKey:NSInsertedObjectsKey] allObjects];
    NSArray *deletedObjects = [[notification.userInfo valueForKey:NSDeletedObjectsKey] allObjects];
    NSArray *updatedObjects = [[notification.userInfo valueForKey:NSUpdatedObjectsKey] allObjects];
    
    NSMutableSet *refreshedObjectsSet = [[notification.userInfo valueForKey:NSRefreshedObjectsKey] mutableCopy];
    [refreshedObjectsSet minusSet:[notification.userInfo valueForKey:NSInsertedObjectsKey]];
    [refreshedObjectsSet minusSet:[notification.userInfo valueForKey:NSDeletedObjectsKey]];
    [refreshedObjectsSet minusSet:[notification.userInfo valueForKey:NSUpdatedObjectsKey]];
    
    NSArray *updatedAndRefreshedObject = updatedObjects ? [updatedObjects arrayByAddingObjectsFromArray:refreshedObjectsSet.allObjects] : refreshedObjectsSet.allObjects;

    
    BOOL notifyDelegateForFetchedObjects = YES;

    // Evaluating for arrangedObjects
    if (_arrangedObjects) {
        notifyDelegateForFetchedObjects = NO;

        NSDictionary *results = [self evaluateDeletedObjects:deletedObjects
                                             insertedObjects:insertedObjects
                                              updatedObjects:updatedAndRefreshedObject
                                                 inContainer:_arrangedObjects
                                                fetchRequest:_arrangedObjectInMemoryFetchRequest];
        
        if (results) {
            
            NSMutableArray *newContainer = [results objectForKey:SFNewContainerKey];
            NSMutableArray *oldContainer = [_arrangedObjects copy];

            [self delegateWillChangeContent];
            _arrangedObjects = newContainer;

            [self notifyChangesForOldContainer:oldContainer
                                  newContainer:newContainer
                                deletedObjects:results[NSDeletedObjectsKey]
                               insertedObjects:results[NSInsertedObjectsKey]
                                updatedObjects:results[NSUpdatedObjectsKey]];

            [self delegateDidChangeContent];
        }

    }
    
    // Evaluating for fetchedObjects
    NSDictionary *results = [self evaluateDeletedObjects:deletedObjects
                                         insertedObjects:insertedObjects
                                          updatedObjects:updatedAndRefreshedObject
                                             inContainer:_fetchedObjects
                                            fetchRequest:self.fetchRequest];
    
    if (results) {
        
        NSMutableArray *newContainer = [results objectForKey:SFNewContainerKey];
        NSMutableArray *oldContainer = [_fetchedObjects copy];

        if (notifyDelegateForFetchedObjects) {
            
            [self delegateWillChangeContent];
            _fetchedObjects = newContainer;

            [self notifyChangesForOldContainer:oldContainer
                                  newContainer:newContainer
                                deletedObjects:results[NSDeletedObjectsKey]
                               insertedObjects:results[NSInsertedObjectsKey]
                                updatedObjects:results[NSUpdatedObjectsKey]];
            
            [self delegateDidChangeContent];
        }
        else {
            _fetchedObjects = newContainer;
        }
        
    }
}




- (NSDictionary *) evaluateDeletedObjects: (NSArray *) deletedObjects
                            insertedObjects: (NSArray *) insertedObjects
                             updatedObjects: (NSArray *) updatedObjects
                                inContainer: (NSMutableArray *) container
                               fetchRequest: (NSFetchRequest *) fetchRequest
{
    
    NSMutableArray *containerDeletedObjects = [NSMutableArray array];
    NSMutableArray *containerInsertedObjects = [NSMutableArray array];
    NSMutableArray *containerUpdatedObjects = [NSMutableArray array];
    
    NSMutableArray *newContainer = [container mutableCopy];
    
    // DELETED objects
    for (NSManagedObject *deletedObj in deletedObjects) {
        if (![container containsObject:deletedObj]) {
            continue;
        }

        [newContainer removeObject:deletedObj];
        [containerDeletedObjects addObject:deletedObj];
    }
    
    // INSERTED objects
    for (NSManagedObject *insertedObj in insertedObjects) {
        if (![self object:insertedObj isConformToFetchRequest:fetchRequest]) {
            continue;
        }
        
        [newContainer addObject:insertedObj];
        [containerInsertedObjects addObject:insertedObj];
    }

    // UPDATED objects (after the update they can be inserted/deleted/updated/moved in the container)
    for (NSManagedObject *updatedObj in updatedObjects) {

        // Object is inside the container, but no longer conform to the fetch request (deleted)
        if (![self object:updatedObj isConformToFetchRequest:fetchRequest]) {

            if ([container containsObject:updatedObj]) {
                [newContainer removeObject:updatedObj];
                [containerDeletedObjects addObject:updatedObj];
                
            }            
        }

        // Object conform to the fetch request
        else {
            // Already inside the container (updated)
            if ([container containsObject:updatedObj]) {
                [containerUpdatedObjects addObject:updatedObj];
            }
            // Not inside the container (inserted)
            else {
                [newContainer addObject:updatedObj];
                [containerInsertedObjects addObject:updatedObj];
            }
        }
    }
    
    // Resorting the arrays
    NSArray *sortDescriptors = [fetchRequest sortDescriptors];
    if ([sortDescriptors count]) {
        [newContainer sortUsingDescriptors:sortDescriptors];
        
        [containerInsertedObjects sortUsingDescriptors:sortDescriptors];
        [containerDeletedObjects sortUsingDescriptors:sortDescriptors];
        [containerUpdatedObjects sortUsingDescriptors:sortDescriptors];
    }
    
    if ((containerDeletedObjects.count || containerUpdatedObjects.count || containerInsertedObjects.count)) {
        return @{
                 NSInsertedObjectsKey:containerInsertedObjects,
                 NSDeletedObjectsKey:containerDeletedObjects,
                 NSUpdatedObjectsKey:containerUpdatedObjects,
                 SFNewContainerKey: newContainer,
                 };
    }
 
    return nil;
}

- (BOOL) object: (NSManagedObject *) object isConformToFetchRequest: (NSFetchRequest *) fetchRequest
{
    // Evaluating entity
    NSEntityDescription *entity = [fetchRequest entity];
    if (![[object entity] isKindOfEntity:entity]) {
        return NO;
    }
    
    // Evalutating eventual predicate
    NSPredicate *predicate = [fetchRequest predicate];
    if (predicate != nil && ![predicate evaluateWithObject:object]) {
        return NO;
    }
    
    return YES;
}


#pragma mark - Notifications

- (void)delegateWillChangeContent
{
    if (self.delegateHas.delegateHasWillBeginChanging) {
        [self.delegate fetchedResultsControllerWillBeginChanging:self];
    }
}

- (void)delegateDidChangeContent
{
    if (self.delegateHas.delegateHasDidEndChangingWithProgressiveChanges) {
        [self.delegate fetchedResultsController:self
                                 didEndChanging:self.currentBatchChanges
                             progressiveChanges:self.currentBatchProgressiveChanges];
    }
    else if (self.delegateHas.delegateHasDidEndChangingWithChanges) {
        [self.delegate fetchedResultsController:self
                                 didEndChanging:self.currentBatchChanges];
    }
    else if (self.delegateHas.delegateHasDidEndChanging) {
        [self.delegate fetchedResultsControllerDidEndChanging:self];
    }
}

- (void)delegateDidChangeObject:(id)anObject
                        atIndex:(NSUInteger)index
               progressiveIndex:(NSUInteger)progressiveIndex
                     changeType:(MRTFetchedResultsChangeType)changeType
          progressiveChangeType:(MRTFetchedResultsChangeType)progressiveChangeType
                       newIndex:(NSUInteger)newIndex
            newProgressiveIndex:(NSUInteger)newProgressiveIndex
{
    // NSLog(@"Changing object: %@\nAt index: %lu\nChange type: %d\nNew index: %lu", anObject, index, (int)type, newIndex);
    MRTFetchedResultsControllerChange *change = [[MRTFetchedResultsControllerChange alloc] initWithObject:anObject
                                                                                                    index:index
                                                                                                 newIndex:newIndex
                                                                                                     type:changeType];
    MRTFetchedResultsControllerChange *pChange = nil;
    if (self.delegateHas.delegateHasDidChangeWithProgressiveChanges || self.delegateHas.delegateHasDidEndChangingWithProgressiveChanges) {
        pChange = [[MRTFetchedResultsControllerChange alloc] initWithObject:anObject
                                                                      index:progressiveIndex
                                                                   newIndex:newProgressiveIndex
                                                                       type:progressiveChangeType];
    }
    
    // saving the changes for the didChangeContent callbacks if needed
    if (self.delegateHas.delegateHasDidEndChangingWithChanges || self.delegateHas.delegateHasDidEndChangingWithProgressiveChanges) {
        [self.currentBatchChanges addObject:change];
    }
    if (self.delegateHas.delegateHasDidEndChangingWithProgressiveChanges) {
        [self.currentBatchProgressiveChanges addObject:pChange];
    }
    
    // calling the delegate callbacks
    if (self.delegateHas.delegateHasDidChangeWithProgressiveChanges) {
        [self.delegate fetchedResultsController:self
                                      didChange:change
                              progressiveChange:pChange];
    }
    else if (self.delegateHas.delegateHasDidChangeWithChanges) {
        [self.delegate fetchedResultsController:self
                                      didChange:change];
    }
}

- (void) notifyChangesForOldContainer: (NSArray *) oldContainer
                         newContainer: (NSArray *) newContainer
                       deletedObjects: (NSArray *) deletedObjects
                      insertedObjects: (NSArray *) insertedObjects
                       updatedObjects: (NSArray *) updatedObjects
{
    // Tmp array used to keep track of middle states
    NSMutableArray *progressiveArray = [oldContainer mutableCopy];
    
    BOOL wantProgressiveChanges = self.delegateHas.delegateHasDidChangeWithProgressiveChanges || self.delegateHas.delegateHasDidEndChangingWithProgressiveChanges;
    
    NSMutableIndexSet *deletedIndexes = [NSMutableIndexSet indexSet];
    NSMutableIndexSet *insertedIndexes = [NSMutableIndexSet indexSet];
    
    // used to keep track of the changes we are making to be able to return them
    // in the didChangeContent callbacks; these are populated in
    // -delegateDidChangeObject:atIndex:progressiveIndex:changeType:progressiveChangeType:newIndex:newProgressiveIndex:
    self.currentBatchChanges = [NSMutableArray array];
    self.currentBatchProgressiveChanges = [NSMutableArray array];
    
    // DELETED
    for (id obj in deletedObjects) {
        NSUInteger index = [oldContainer indexOfObjectIdenticalTo:obj];
        NSUInteger progressiveIndex = [progressiveArray indexOfObjectIdenticalTo:obj];
        
        [deletedIndexes addIndex:index];
        
        [progressiveArray removeObjectAtIndex:progressiveIndex];
        
        [self delegateDidChangeObject:obj
                              atIndex:index
                     progressiveIndex:progressiveIndex
                           changeType:MRTFetchedResultsChangeDelete
                progressiveChangeType:MRTFetchedResultsChangeDelete
                             newIndex:NSNotFound
                  newProgressiveIndex:NSNotFound];

    }
    
    // INSERTED
    for (id obj in insertedObjects) {
        NSUInteger newIndex = [newContainer indexOfObjectIdenticalTo:obj];
        [progressiveArray insertObject:obj atIndex:newIndex];
        
        [insertedIndexes addIndex:newIndex];
        
        [self delegateDidChangeObject:obj
                              atIndex:NSNotFound
                     progressiveIndex:NSNotFound
                           changeType:MRTFetchedResultsChangeInsert
                progressiveChangeType:MRTFetchedResultsChangeInsert
                             newIndex:newIndex
                  newProgressiveIndex:newIndex];

    }
    
    // UPDATED OR MOVED
    NSInteger previousSegmentLocation = -1;
    NSInteger previousInsert = -1;

    for (id obj in updatedObjects) {
    
        __block NSUInteger index = [oldContainer indexOfObjectIdenticalTo:obj];
        __block NSUInteger newIndex = [newContainer indexOfObjectIdenticalTo:obj];
        __block NSUInteger progressiveIndex = [progressiveArray indexOfObjectIdenticalTo:obj];
        __block NSUInteger newProgressiveIndex = newIndex;

        // Offsetting newProgressiveIndex for delegate who want the progressive changes
        if (wantProgressiveChanges) {
            // First object and it's moving to the top if the array, no offset needed
            if (previousSegmentLocation == -1 && newIndex == 0) {
            }
            // This object is adjacent to the previous one inserted, we can just add 1 to the index
            else if (previousSegmentLocation == newIndex -1) {
                newProgressiveIndex = previousInsert +1;
            }
            // Found a gap, finding the previous object in the final array and inserting next to it to pass the gap
            else {
                // Still haven't found why this happens...
                if (newIndex == 0 || newIndex == NSNotFound) {
                    continue;
                }
                newProgressiveIndex = [progressiveArray indexOfObjectIdenticalTo:[newContainer objectAtIndex:newIndex-1]] +1;
            }
            
            // Removing element from the top and moving it to the bottom requires adjusting the index by 1
            if (newProgressiveIndex > progressiveIndex) {
                newProgressiveIndex--;
            }

            previousSegmentLocation = newIndex;
            previousInsert = newProgressiveIndex;
        }
        
        // Checking if the change is an update or a move
        MRTFetchedResultsChangeType changeType = (index == newIndex) ? MRTFetchedResultsChangeUpdate : MRTFetchedResultsChangeMove;
        MRTFetchedResultsChangeType progressiveChangeType = (progressiveIndex == newProgressiveIndex) ? MRTFetchedResultsChangeUpdate : MRTFetchedResultsChangeMove;
        
        // There is a special case where we still need to mark an update as a move (just to maintain the compatibility with NSFetchedResultsController)
        // Check "testUpdateThatActuallyIsAMove" to understand this :)
        if (changeType == MRTFetchedResultsChangeUpdate) {
            NSUInteger deletions = [deletedIndexes countOfIndexesInRange:NSMakeRange(0, index)];
            NSUInteger insertions = [insertedIndexes countOfIndexesInRange:NSMakeRange(0, index)];
            
            if (deletions != insertions) {
                changeType = MRTFetchedResultsChangeMove;
            }
        }
        
        [self delegateDidChangeObject:obj
                              atIndex:index
                     progressiveIndex:progressiveIndex
                           changeType:changeType
                progressiveChangeType:progressiveChangeType
                             newIndex:newIndex
                  newProgressiveIndex:newProgressiveIndex];
        
        if (changeType == MRTFetchedResultsChangeMove || progressiveChangeType == MRTFetchedResultsChangeMove) {
            [progressiveArray removeObjectAtIndex:progressiveIndex];
            [progressiveArray insertObject:obj atIndex:newProgressiveIndex];
        }
    }
}


@end

@implementation MRTFetchedResultsControllerChange

- (instancetype)initWithObject:(id)anObject
                         index:(NSUInteger)index
                      newIndex:(NSUInteger)newIndex
                          type:(MRTFetchedResultsChangeType)type
{
    self = [super init];
    if (self) {
        self.object = anObject;
        self.index = index;
        self.newIndex = newIndex;
        self.type = type;
    }
    return self;
}

- (BOOL)isEqual:(id)object
{
    if (object == self) { return YES; };
    if (!object || ![object isKindOfClass:[self class]]) { return NO; };
     
    MRTFetchedResultsControllerChange *typedChange = (MRTFetchedResultsControllerChange *)object;
    return self.object == typedChange.object &&
           self.index == typedChange.index &&
           self.newIndex == typedChange.newIndex &&
           self.type == typedChange.type;
}

- (NSString *)typeDescription
{
    switch (self.type)
    {
        case MRTFetchedResultsChangeInsert:
            return @"insert";
            break;
        case MRTFetchedResultsChangeDelete:
            return @"delete";
            break;
        case MRTFetchedResultsChangeMove:
            return @"move";
            break;
        case MRTFetchedResultsChangeUpdate:
            return @"update";
            break;
    }
    return @"undefined";
}

- (NSUInteger)hash
{
    if (_computedHash == 0) {
        _computedHash = [[NSString stringWithFormat:@"%lu-%lu-%lu-%lu", [self.object hash], self.index, self.newIndex, self.type] hash];
    }
    
    return _computedHash;
}


- (NSString *)description
{
    return [NSString stringWithFormat:@"%@ change with index: %lu newIndex: %lu", [self.typeDescription uppercaseString], self.index, self.newIndex];
}

@end
