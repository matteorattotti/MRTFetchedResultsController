//
//  MRTFetchedResultsController.m
//  MRTFetchedResultsController
//
//  Created by Matteo Rattotti on 14/05/15.
//
//

#import "MRTFetchedResultsController.h"

const NSString *SFNewContainerKey = @"SFNewContainerKey";


@interface MRTChange : NSObject

@property (assign) NSUInteger index;
@property (assign) NSUInteger newIndex;
@property (assign) NSUInteger progressiveIndex;
@property (assign) MRTFetchedResultsChangeType type;
@property (assign) NSUInteger computedHash;
@property (assign) id object;

+ (MRTChange *)changeWithType:(NSUInteger)type object:(id)object index:(NSUInteger)index newIndex:(NSUInteger)newIndex progressiveIndex:(NSUInteger)progressiveIndex;

@end

struct MRTFetchedResultsControllerDelegateHasMethods {
    BOOL delegateHasWillChangeContent;
    BOOL delegateHasDidChangeContent;
    BOOL delegateHasDidChangeObject;
    BOOL delegateHasDidChangeObjectWithProgressiveChanges;
    BOOL delegateHasAdditionalObjectsChangesChanges;
};

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
    _delegateHas.delegateHasWillChangeContent = [_delegate respondsToSelector:@selector(controllerWillChangeContent:)];
    _delegateHas.delegateHasDidChangeContent  = [_delegate respondsToSelector:@selector(controllerDidChangeContent:)];
    _delegateHas.delegateHasDidChangeObject   = [_delegate respondsToSelector:@selector(controller:didChangeObject:atIndex:forChangeType:newIndex:)];
    _delegateHas.delegateHasDidChangeObjectWithProgressiveChanges = [_delegate respondsToSelector:@selector(controller:didChangeObject:atIndex:progressiveIndex:forChangeType:forProgressiveChangeType:newIndex:newProgressiveIndex:)];
    _delegateHas.delegateHasAdditionalObjectsChangesChanges = [_delegate respondsToSelector:@selector(additionalObjectsChangesForChanges:)];
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
    NSDictionary *changes = [self changesFromManagedObjectContextObjectsDidChange:notification];
    
    // Array are way faster to enumerate than sets
    NSArray *insertedObjects = [[changes valueForKey:NSInsertedObjectsKey] allObjects];
    NSArray *deletedObjects = [[changes valueForKey:NSDeletedObjectsKey] allObjects];
    NSArray *updatedObjects = [[changes valueForKey:NSUpdatedObjectsKey] allObjects];
    NSSet *refreshedObjectsSet = [changes valueForKey:NSRefreshedObjectsKey];
    
    NSMutableSet *updatedAndRefreshedObject = [NSMutableSet set];
    if (updatedObjects) { [updatedAndRefreshedObject addObjectsFromArray:updatedObjects]; }
    if (refreshedObjectsSet) { [updatedAndRefreshedObject unionSet:refreshedObjectsSet]; }
    [updatedAndRefreshedObject minusSet:[changes valueForKey:NSInsertedObjectsKey]];
    [updatedAndRefreshedObject minusSet:[changes valueForKey:NSDeletedObjectsKey]];
    
    updatedObjects = updatedAndRefreshedObject.allObjects;
    
    BOOL notifyDelegateForFetchedObjects = YES;
    BOOL notifyDelegateDidChangeContent = NO;
    
    // Evaluating for arrangedObjects
    if (_arrangedObjects) {
        notifyDelegateForFetchedObjects = NO;

        NSDictionary *results = [self evaluateDeletedObjects:deletedObjects
                                             insertedObjects:insertedObjects
                                              updatedObjects:updatedObjects
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

            notifyDelegateDidChangeContent = YES;
        }

    }
    
    // Evaluating for fetchedObjects
    NSDictionary *results = [self evaluateDeletedObjects:deletedObjects
                                         insertedObjects:insertedObjects
                                          updatedObjects:updatedObjects
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
            
            notifyDelegateDidChangeContent = YES;
        }
        else {
            _fetchedObjects = newContainer;
        }
        
    }
    
    if(notifyDelegateDidChangeContent) {
        [self delegateDidChangeContent];
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
    
    NSMutableDictionary *containerIndexCache = [NSMutableDictionary new];
    [container enumerateObjectsUsingBlock:^(NSManagedObject *obj, NSUInteger idx, BOOL * _Nonnull stop) {
        containerIndexCache[[obj objectID]] = @(idx);
    }];

    // DELETED objects
    for (NSManagedObject *deletedObj in deletedObjects) {
        // The container doesn't have this object, skipping it
        if(!containerIndexCache[deletedObj.objectID]) {
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
        
        // Already inside the container (updated)
        if(containerIndexCache[insertedObj.objectID]) {
            [containerUpdatedObjects addObject:insertedObj];
        }
        // Not in the container (inserted)
        else {
            [newContainer addObject:insertedObj];
            [containerInsertedObjects addObject:insertedObj];
        }
    }

    // UPDATED objects (after the update they can be inserted/deleted/updated/moved in the container)
    for (NSManagedObject *updatedObj in updatedObjects) {

        // Object is inside the container, but no longer conform to the fetch request (deleted)
        if (![self object:updatedObj isConformToFetchRequest:fetchRequest]) {
            if(containerIndexCache[updatedObj.objectID]) {
                [newContainer removeObject:updatedObj];
                [containerDeletedObjects addObject:updatedObj];
            }            
        }

        // Object conform to the fetch request
        else {
            // Already inside the container (updated)
            if(containerIndexCache[updatedObj.objectID]) {
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

- (NSDictionary <NSString *, NSSet *> *)changesFromManagedObjectContextObjectsDidChange:(NSNotification*)notification {
    NSMutableDictionary *changes = [notification.userInfo mutableCopy];
    if(self.delegateHas.delegateHasAdditionalObjectsChangesChanges) {
        NSDictionary *additionalChanges = [self.delegate additionalObjectsChangesForChanges:@{NSInsertedObjectsKey: [changes valueForKey:NSInsertedObjectsKey] ?: [NSSet set],
                                                                                              NSDeletedObjectsKey: [changes valueForKey:NSDeletedObjectsKey] ?: [NSSet set],
                                                                                              NSUpdatedObjectsKey: [changes valueForKey:NSUpdatedObjectsKey] ?: [NSSet set],
                                                                                              NSRefreshedObjectsKey: [changes valueForKey:NSRefreshedObjectsKey] ?: [NSSet set],
                                                                                            }];

        for(NSString *key in @[NSInsertedObjectsKey, NSDeletedObjectsKey, NSUpdatedObjectsKey, NSRefreshedObjectsKey]) {
            NSMutableSet *mergedObjects = [NSMutableSet set];
            if(additionalChanges[key]) {
                [mergedObjects unionSet:additionalChanges[key]];
            }
            if(changes[key]) {
                [mergedObjects unionSet:changes[key]];
            }
            if(mergedObjects.count) {
                changes[key] = mergedObjects;
            }
        }
    }

    return changes;
}

#pragma mark - Notifications

- (void)delegateWillChangeContent
{
    if (self.delegateHas.delegateHasWillChangeContent) {
        [self.delegate controllerWillChangeContent:self];
    }
}

- (void)delegateDidChangeContent
{
    if (self.delegateHas.delegateHasDidChangeContent) {
        [self.delegate controllerDidChangeContent:self];
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
    
    if (self.delegateHas.delegateHasDidChangeObjectWithProgressiveChanges) {
        [self.delegate controller:self
                  didChangeObject:anObject
                          atIndex:index
                 progressiveIndex:progressiveIndex
                    forChangeType:changeType
         forProgressiveChangeType:progressiveChangeType
                         newIndex:newIndex
              newProgressiveIndex:newProgressiveIndex];
    }
    else if (self.delegateHas.delegateHasDidChangeObject) {
        [self.delegate controller:self didChangeObject:anObject atIndex:index forChangeType:changeType newIndex:newIndex];
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
    
    NSMutableArray *insertedUpdated = [NSMutableArray array];
    NSMutableArray *deleted = [NSMutableArray array];
    
    // Building indexes cache
    NSMutableDictionary *oldContainerIndexCache = [NSMutableDictionary new];
    [oldContainer enumerateObjectsUsingBlock:^(NSManagedObject *obj, NSUInteger idx, BOOL * _Nonnull stop) {
        oldContainerIndexCache[[obj objectID]] = @(idx);
    }];
    
    NSMutableDictionary *newContainerIndexCache = [NSMutableDictionary new];
    [newContainer enumerateObjectsUsingBlock:^(NSManagedObject *obj, NSUInteger idx, BOOL * _Nonnull stop) {
        newContainerIndexCache[[obj objectID]] = @(idx);
    }];

    // Bulding changes objects
    for(NSManagedObject *obj in deletedObjects) {
        NSUInteger index = [oldContainerIndexCache[obj.objectID] unsignedIntValue];
        MRTChange *c = [MRTChange changeWithType:MRTFetchedResultsChangeDelete object:obj index:index newIndex:NSNotFound progressiveIndex:index];
        [deleted addObject:c];
    }

    for(NSManagedObject *obj in insertedObjects) {
        NSUInteger newIndex = [newContainerIndexCache[obj.objectID] unsignedIntValue];
        MRTChange *c = [MRTChange changeWithType:MRTFetchedResultsChangeInsert object:obj index:NSNotFound newIndex:newIndex progressiveIndex:NSNotFound];
        [insertedUpdated addObject:c];
    }
    
    for(NSManagedObject *obj in updatedObjects) {
        NSUInteger index = [oldContainerIndexCache[obj.objectID] unsignedIntValue];
        NSUInteger newIndex = [newContainerIndexCache[obj.objectID] unsignedIntValue];
        if(index != newIndex) {
            MRTChange *c = [MRTChange changeWithType:MRTFetchedResultsChangeMove object:obj index:index newIndex:newIndex progressiveIndex:NSNotFound];
            [insertedUpdated addObject:c];
        }
        else {
            MRTChange *c = [MRTChange changeWithType:MRTFetchedResultsChangeUpdate object:obj index:index newIndex:newIndex progressiveIndex:index];
            [insertedUpdated addObject:c];
        }
    }
    
    // Sorting in a way that prevent indexes to change when applying the change
    [insertedUpdated sortUsingDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"newIndex" ascending:YES]]];
    [deleted sortUsingDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"index" ascending:NO]]];
    
    
    // DELETE
    for(MRTChange *change in deleted) {
        NSUInteger index = change.index;
        id obj = change.object;
        NSUInteger progressiveIndex = change.index;
        
        [progressiveArray removeObjectAtIndex:progressiveIndex];
        
        [self delegateDidChangeObject:obj
                              atIndex:index
                     progressiveIndex:progressiveIndex
                           changeType:MRTFetchedResultsChangeDelete
                progressiveChangeType:MRTFetchedResultsChangeDelete
                             newIndex:NSNotFound
                  newProgressiveIndex:NSNotFound];
    }
    
    // INSERTED / MOVED / UPDATED
    NSInteger previousSegmentLocation = -1;
    NSInteger previousInsert = -1;

    for(MRTChange *change in insertedUpdated) {
        NSUInteger newIndex = change.newIndex;
        NSUInteger index = change.index;
        id obj = change.object;
        
        NSUInteger progressiveIndex = [progressiveArray indexOfObjectIdenticalTo:obj];
        NSUInteger newProgressiveIndex = newIndex;

        // First object and it's moving to the top if the array, no offset needed
        if (newIndex == 0) {
        }
        // This object is adjacent to the previous one inserted, we can just add 1 to the index
        else if (previousSegmentLocation == newIndex -1) {
            newProgressiveIndex = previousInsert +1;
        }
        // Found a gap, finding the previous object in the final array and inserting next to it to pass the gap
        else {
            newProgressiveIndex = [progressiveArray indexOfObjectIdenticalTo:[newContainer objectAtIndex:newIndex-1]] +1;
        }
        
        // Removing element from the top and moving it to the bottom requires adjusting the index by 1
        if (progressiveIndex != NSNotFound && newProgressiveIndex > progressiveIndex) {
            newProgressiveIndex--;
        }

        previousSegmentLocation = newIndex;
        previousInsert = newProgressiveIndex;

        // INSERTED
        if(change.type == MRTFetchedResultsChangeInsert) {
            [progressiveArray insertObject:obj atIndex:newProgressiveIndex];

            [self delegateDidChangeObject:obj
                                  atIndex:NSNotFound
                         progressiveIndex:NSNotFound
                               changeType:MRTFetchedResultsChangeInsert
                    progressiveChangeType:MRTFetchedResultsChangeInsert
                                 newIndex:newIndex
                      newProgressiveIndex:newProgressiveIndex];
        }
        // MOVED
        else {
            MRTFetchedResultsChangeType changeType = (index == newIndex) ? MRTFetchedResultsChangeUpdate : MRTFetchedResultsChangeMove;
            MRTFetchedResultsChangeType progressiveChangeType = (progressiveIndex == newProgressiveIndex) ? MRTFetchedResultsChangeUpdate : MRTFetchedResultsChangeMove;

            if (changeType == MRTFetchedResultsChangeMove || progressiveChangeType == MRTFetchedResultsChangeMove) {
                [progressiveArray removeObjectAtIndex:progressiveIndex];
                [progressiveArray insertObject:obj atIndex:newProgressiveIndex];
            }

            [self delegateDidChangeObject:obj
                                  atIndex:index
                         progressiveIndex:progressiveIndex
                               changeType:changeType
                    progressiveChangeType:progressiveChangeType
                                 newIndex:newIndex
                      newProgressiveIndex:newProgressiveIndex];
        }
    }
}


@end


@implementation MRTChange

+ (MRTChange *)changeWithType:(NSUInteger)type object:(id)object index:(NSUInteger)index newIndex:(NSUInteger)newIndex progressiveIndex:(NSUInteger)progressiveIndex
{
    MRTChange *change = [MRTChange new];
    change.type = type;
    change.index = index;
    change.newIndex = newIndex;
    change.progressiveIndex = progressiveIndex;
    change.object = object;
    
    return change;
}

- (BOOL)isEqual:(id)object
{
    if (object == self) { return YES; };
    if (!object || ![object isKindOfClass:[self class]]) { return NO; };
     
    return self.index == [object index] &&
           self.newIndex == [object newIndex] &&
           self.type == [(MRTChange *)object type];
}

- (NSUInteger)hash
{
    if (_computedHash == 0) {
        _computedHash = [[NSString stringWithFormat:@"%lu-%lu-%lu", self.index, self.newIndex, self.type] hash];
    }
    
    return _computedHash;
}


- (NSString *)description
{
    return [NSString stringWithFormat:@"Type: %lu index: %lu newIndex: %lu", self.type, self.index, self.newIndex];
}


@end
