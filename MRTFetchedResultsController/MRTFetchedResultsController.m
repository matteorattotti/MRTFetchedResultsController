//
//  MRTFetchedResultsController.m
//  MRTFetchedResultsController
//
//  Created by Matteo Rattotti on 14/05/15.
//
//

#import "MRTFetchedResultsController.h"

const NSString *SFNewContainerKey = @"SFNewContainerKey";

@interface MRTFetchedResultsController ()
{
    NSMutableArray *_fetchedObjects;
    NSMutableArray *_arrangedObjects;
    
    struct {
        BOOL delegateHasWillChangeContent;
        BOOL delegateHasDidChangeContent;
        BOOL delegateHasDidChangeObject;
    } delegateHas;
}

@property (nonatomic, strong) NSFetchRequest *arrangedObjectInMemoryFetchRequest;

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
    
    // Array are way faster to enumerate than sets
    NSArray *insertedObjects = [[notification.userInfo valueForKey:NSInsertedObjectsKey] allObjects];
    NSArray *deletedObjects = [[notification.userInfo valueForKey:NSDeletedObjectsKey] allObjects];
    NSArray *updatedObjects = [[notification.userInfo valueForKey:NSUpdatedObjectsKey] allObjects];
    NSArray *refreshedObjects = [[notification.userInfo valueForKey:NSRefreshedObjectsKey] allObjects];
    
    NSMutableArray *updatedAndRefreshedObject = [NSMutableArray array];
    [updatedAndRefreshedObject addObjectsFromArray:updatedObjects];
    [updatedAndRefreshedObject addObjectsFromArray:refreshedObjects];

    
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
    
    // Resorting the newContainer if needed
    NSArray *sortDescriptors = [fetchRequest sortDescriptors];
    if ([sortDescriptors count]) {
        [newContainer sortUsingDescriptors:sortDescriptors];
        
        // This make me cry, but MacOSX is a bitch (it have sequential and progressive table update, iOS instead have batched updates)
        
        // Insert should be sorted and sequential
        [containerInsertedObjects sortUsingDescriptors:sortDescriptors];

        // Delete should be reverse sorted (using as reference the original object position)
        [containerDeletedObjects sortUsingComparator:^NSComparisonResult(id obj1, id obj2) {
            NSInteger index1 = [container indexOfObject:obj1];
            NSInteger index2 = [container indexOfObject:obj2];

            return index1 < index2;
        }];
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
    if (delegateHas.delegateHasDidChangeObject) {
        [self.delegate controller:self didChangeObject:anObject atIndex:index forChangeType:type newIndex:newIndex];
    }
}

- (void) notifyChangesForOldContainer: (NSArray *) oldContainer
                         newContainer: (NSArray *) newContainer
                       deletedObjects: (NSArray *) deletedObjects
                      insertedObjects: (NSArray *) insertedObjects
                       updatedObjects: (NSArray *) updatedObjects
{
    // DELETED
    for (id obj in deletedObjects) {
        NSUInteger index = [oldContainer indexOfObject:obj];
        [self delegateDidChangeObject:obj atIndex:index forChangeType:MRTFetchedResultsChangeDelete newIndex:NSNotFound];
    }
    
    // INSERTED
    for (id obj in insertedObjects) {
        NSUInteger newIndex = [newContainer indexOfObject:obj];
        [self delegateDidChangeObject:obj atIndex:NSNotFound forChangeType:MRTFetchedResultsChangeInsert newIndex:newIndex];
    }
    
    // UPDATED AND MOVED
    for (id obj in updatedObjects) {
        NSUInteger index = [oldContainer indexOfObject:obj];
        NSUInteger newIndex = [newContainer indexOfObject:obj];
        
        // Same index, the object was just updated
        if (index == newIndex) {
            [self delegateDidChangeObject:obj atIndex:index forChangeType:MRTFetchedResultsChangeUpdate newIndex:index];
        }
        
        // Different index, mean that the object was also moved
        else {
            [self delegateDidChangeObject:obj atIndex:index forChangeType:MRTFetchedResultsChangeMove newIndex:newIndex];
        }
    }
}

@end
