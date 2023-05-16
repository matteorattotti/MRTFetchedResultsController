//
//  MRTTestMoveHelper.m
//  MRTFetchedResultsController
//
//  Created by Matteo Rattotti on 30/06/2017.
//
//

#import "MRTTestMoveHelper.h"

@implementation MRTTestMoveHelper

- (instancetype)initWithTest: (XCTestCase *) testCase
                initialItems: (NSArray *) initialItems
                 finalOrders: (NSArray *) finalOrders
{
    self = [super init];
    if (self) {
        [self setupCoreData];
        
        self.movementHistory = [NSMutableString string];
        
        self.finalOrders = finalOrders;
        self.didChangeContentExpectation = [testCase expectationWithDescription:@"Controller Did Change Content"];

        [self prepareItems:initialItems];
    }
    return self;
}

- (void) setupCoreData
{
    // Core Data Stack
    NSURL *modelURL = [[NSBundle bundleForClass:[self class]] URLForResource:@"Model" withExtension:@"momd"];
    NSManagedObjectModel *mom = [[NSManagedObjectModel alloc] initWithContentsOfURL:modelURL];
    
    NSError *error;
    NSPersistentStoreCoordinator *coordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:mom];
    [coordinator addPersistentStoreWithType:NSInMemoryStoreType configuration:nil URL:nil options:nil error:&error];
    
    self.managedObjectContext = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSMainQueueConcurrencyType];
    self.managedObjectContext.persistentStoreCoordinator = coordinator;
}

- (void) prepareItems: (NSArray *) items
{
    self.targetArray = [NSMutableArray array];
    
    // Preparing the initial objects
    [items enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        Note *newObject = [NSEntityDescription insertNewObjectForEntityForName:@"Note" inManagedObjectContext:self.managedObjectContext];
        newObject.text = obj;
        newObject.order = @(idx);
        
        // Preloading our array
        [self.targetArray addObject:newObject];
    }];

    // Processing the inserts
    [self.managedObjectContext processPendingChanges];
    
    // Creating the fetchedResultsController and fetching
    self.fetchedResultsController = [self notesFetchedResultsController];
    [self.fetchedResultsController performFetch:nil];
 
   /* [self.finalOrders enumerateObjectsUsingBlock:^(NSNumber *order, NSUInteger idx, BOOL * _Nonnull stop) {
        Note *note = [self.targetArray objectAtIndex:idx];
        
        if (![note.order isEqualToNumber:order]) {
            note.order = order;
        }
    }];*/

}

- (void) performMoves
{
    // Changing the item to trigger a reorder the items
    [self.finalOrders enumerateObjectsUsingBlock:^(NSNumber *order, NSUInteger idx, BOOL * _Nonnull stop) {
        Note *note = [self.targetArray objectAtIndex:idx];
        
        if (![note.order isEqualToNumber:order]) {
            note.order = order;
        }
    }];
}

- (BOOL) isFinalOrderCorrect
{
    return [self.fetchedResultsController.arrangedObjects isEqualToArray:self.targetArray];
}

#pragma mark - MRTFetchedResultsControllerDelegate

- (void)controllerWillChangeContent:(MRTFetchedResultsController *)controller
{
}

- (void)controllerDidChangeContent:(MRTFetchedResultsController *)controller
{
    [self.didChangeContentExpectation fulfill];
}

- (void)controller:(MRTFetchedResultsController *)controller
   didChangeObject:(id)anObject
           atIndex:(NSUInteger)index
  progressiveIndex:(NSUInteger) progressiveIndex
     forChangeType:(MRTFetchedResultsChangeType)changeType
forProgressiveChangeType:(MRTFetchedResultsChangeType)progressiveChangeType
          newIndex:(NSUInteger)newIndex
newProgressiveIndex:(NSUInteger) newProgressiveIndex;
{
    if (self.logMoves) {
        switch (changeType) {
            case MRTFetchedResultsChangeDelete:
                [self.movementHistory appendFormat:@"deleted %@ at %lu\n", [anObject text], progressiveIndex];
                [self.targetArray removeObjectAtIndex:progressiveIndex];
                break;
            case MRTFetchedResultsChangeInsert:
                [self.movementHistory appendFormat:@"inserted %@ at %lu\n", [anObject text], newProgressiveIndex];
                [self.targetArray insertObject:anObject atIndex:newProgressiveIndex];
                break;
            case MRTFetchedResultsChangeUpdate:
                [self.movementHistory appendFormat:@"update %@ at %lu\n", [anObject text], progressiveIndex];
                break;
            case MRTFetchedResultsChangeMove:
                self.numberOfMoves++;
                [self.movementHistory appendFormat:@"move %@ from %lu in %lu\n", [anObject text], (unsigned long)progressiveIndex, (unsigned long)newProgressiveIndex];
                
                [self.targetArray removeObjectAtIndex:progressiveIndex];
                [self.targetArray insertObject:anObject atIndex:newProgressiveIndex];
                
                [self.movementHistory appendFormat:@"target %@\n", self.targetArray];
                break;
            default:
                break;
        }
    }
    else {
        switch (changeType) {
            case MRTFetchedResultsChangeMove:
                self.numberOfMoves++;
                [self.targetArray removeObjectAtIndex:progressiveIndex];
                [self.targetArray insertObject:anObject atIndex:newProgressiveIndex];
            default:
                break;
        }
    }
}

#pragma mark - MRTFetchedResultsController utils

- (MRTFetchedResultsController *) notesFetchedResultsController
{
    return [self notesFetchedResultsControllerWithPredicate:nil];
}

- (MRTFetchedResultsController *) notesFetchedResultsControllerWithPredicate: (NSPredicate *) predicate
{
    // Creating the fetch request
    NSFetchRequest *request = [[NSFetchRequest alloc] init];
    request.entity = [NSEntityDescription entityForName:@"Note" inManagedObjectContext:self.managedObjectContext];
    request.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"order" ascending:YES]];
    request.predicate = predicate;
    
    // Creating the fetchedResultsController
    MRTFetchedResultsController *fetchedResultsController = [[MRTFetchedResultsController alloc] initWithManagedObjectContext:self.managedObjectContext fetchRequest:request];
    fetchedResultsController.delegate = self;
    
    return fetchedResultsController;
}

- (NSString *)description
{
    return [[super description] stringByAppendingFormat:@" expected %@ result %@", self.fetchedResultsController.arrangedObjects, self.targetArray];
}

@end
