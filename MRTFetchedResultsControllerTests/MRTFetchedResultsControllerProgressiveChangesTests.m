//
//  MRTFetchedResultsControllerProgressiveChangesTests.m
//  MRTFetchedResultsController
//
//  Created by Matteo Rattotti on 06/10/16.
//
//

#import <XCTest/XCTest.h>
#import <CoreData/CoreData.h>
#import "MRTFetchedResultsController.h"
#import "Note.h"

@interface MRTFetchedResultsControllerProgressiveChangesTests : XCTestCase <MRTFetchedResultsControllerDelegate>

@property (strong) NSManagedObjectContext *managedObjectContext;
@property (strong) NSManagedObjectContext *privateManagedObjectContext;

@property (strong) NSMutableArray *targetArray;

@property (nonatomic) CGFloat expectationsDefaultTimeout;

@property (strong) XCTestExpectation *didChangeContentExpectation;

@end

@implementation MRTFetchedResultsControllerProgressiveChangesTests


- (void)setUp
{
    [super setUp];

    [self setupCoreData];
    
    self.targetArray = [NSMutableArray array];
    
    self.expectationsDefaultTimeout = 0.1;
    
    self.didChangeContentExpectation = [self expectationWithDescription:@"Controller Did Change Content"];
}

- (void)tearDown
{
    [super tearDown];
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

#pragma mark - Inserts

- (void) testProgressiveInserts
{
    // Creating the fetchedResultsController
    MRTFetchedResultsController *fetchedResultsController = [self notesFetchedResultsController];
    [fetchedResultsController performFetch:nil];

    // Inserting a new object inside the managedObjectContext
    Note *newObject = [NSEntityDescription insertNewObjectForEntityForName:@"Note" inManagedObjectContext:self.managedObjectContext];
    newObject.order = @1;
    
    // Inserting a new object inside the managedObjectContext
    Note *newObject2 = [NSEntityDescription insertNewObjectForEntityForName:@"Note" inManagedObjectContext:self.managedObjectContext];
    newObject2.order = @2;
    
    // Inserting a new object inside the managedObjectContext
    Note *newObject3 = [NSEntityDescription insertNewObjectForEntityForName:@"Note" inManagedObjectContext:self.managedObjectContext];
    newObject3.order = @3;
    
    // Waiting for the did change expectation
    [self waitForExpectationsWithTimeout:self.expectationsDefaultTimeout handler:^(NSError *error) {
        if(error) XCTFail(@"Expectation Failed with error: %@", error);

        XCTAssertTrue([fetchedResultsController.arrangedObjects isEqualToArray:self.targetArray]);
    }];
}

- (void) testSparseInserts
{
    // Creating the fetchedResultsController
    MRTFetchedResultsController *fetchedResultsController = [self notesFetchedResultsController];
    [fetchedResultsController performFetch:nil];
    
    // Inserting a new object inside the managedObjectContext
    Note *newObject = [NSEntityDescription insertNewObjectForEntityForName:@"Note" inManagedObjectContext:self.managedObjectContext];
    newObject.order = @3;
    
    // Inserting a new object inside the managedObjectContext
    Note *newObject2 = [NSEntityDescription insertNewObjectForEntityForName:@"Note" inManagedObjectContext:self.managedObjectContext];
    newObject2.order = @1;
    
    // Inserting a new object inside the managedObjectContext
    Note *newObject3 = [NSEntityDescription insertNewObjectForEntityForName:@"Note" inManagedObjectContext:self.managedObjectContext];
    newObject3.order = @2;
    
    // Waiting for the did change expectation
    [self waitForExpectationsWithTimeout:self.expectationsDefaultTimeout handler:^(NSError *error) {
        if(error) XCTFail(@"Expectation Failed with error: %@", error);
        
        XCTAssertTrue([fetchedResultsController.arrangedObjects isEqualToArray:self.targetArray]);
    }];
}

#pragma mark - Deletes


- (void) testProgressiveDeletes
{
    // Inserting a new object inside the managedObjectContext
    Note *newObject = [NSEntityDescription insertNewObjectForEntityForName:@"Note" inManagedObjectContext:self.managedObjectContext];
    newObject.order = @1;
    newObject.text = @"a";
    
    // Inserting a new object inside the managedObjectContext
    Note *newObject2 = [NSEntityDescription insertNewObjectForEntityForName:@"Note" inManagedObjectContext:self.managedObjectContext];
    newObject2.order = @2;
    newObject2.text = @"b";
    
    // Inserting a new object inside the managedObjectContext
    Note *newObject3 = [NSEntityDescription insertNewObjectForEntityForName:@"Note" inManagedObjectContext:self.managedObjectContext];
    newObject3.order = @3;
    newObject3.text = @"c";
    
    [self.targetArray addObjectsFromArray:@[newObject, newObject2, newObject3]];

    [self.managedObjectContext processPendingChanges];
    
    // Creating the fetchedResultsController
    MRTFetchedResultsController *fetchedResultsController = [self notesFetchedResultsController];
    [fetchedResultsController performFetch:nil];

    [self.managedObjectContext deleteObject:newObject];
    [self.managedObjectContext deleteObject:newObject2];
    [self.managedObjectContext deleteObject:newObject3];
    
    // Waiting for the did change expectation
    [self waitForExpectationsWithTimeout:self.expectationsDefaultTimeout handler:^(NSError *error) {
        if(error) XCTFail(@"Expectation Failed with error: %@", error);
        
        XCTAssertTrue([fetchedResultsController.arrangedObjects isEqualToArray:self.targetArray]);
    }];
}


- (void) testSparseDeletes
{
    // Inserting a new object inside the managedObjectContext
    Note *newObject = [NSEntityDescription insertNewObjectForEntityForName:@"Note" inManagedObjectContext:self.managedObjectContext];
    newObject.order = @1;
    newObject.text = @"a";
    
    // Inserting a new object inside the managedObjectContext
    Note *newObject2 = [NSEntityDescription insertNewObjectForEntityForName:@"Note" inManagedObjectContext:self.managedObjectContext];
    newObject2.order = @2;
    newObject2.text = @"b";
    
    // Inserting a new object inside the managedObjectContext
    Note *newObject3 = [NSEntityDescription insertNewObjectForEntityForName:@"Note" inManagedObjectContext:self.managedObjectContext];
    newObject3.order = @3;
    newObject3.text = @"c";

    // Inserting a new object inside the managedObjectContext
    Note *newObject4 = [NSEntityDescription insertNewObjectForEntityForName:@"Note" inManagedObjectContext:self.managedObjectContext];
    newObject4.order = @4;
    newObject4.text = @"d";

    
    [self.targetArray addObjectsFromArray:@[newObject, newObject2, newObject3, newObject4]];
    
    [self.managedObjectContext processPendingChanges];
    
    // Creating the fetchedResultsController
    MRTFetchedResultsController *fetchedResultsController = [self notesFetchedResultsController];
    [fetchedResultsController performFetch:nil];
    
    [self.managedObjectContext deleteObject:newObject];
    [self.managedObjectContext deleteObject:newObject3];
    
    // Waiting for the did change expectation
    [self waitForExpectationsWithTimeout:self.expectationsDefaultTimeout handler:^(NSError *error) {
        if(error) XCTFail(@"Expectation Failed with error: %@", error);
        
        XCTAssertTrue([fetchedResultsController.arrangedObjects isEqualToArray:self.targetArray]);
    }];
}


#pragma mark - Moves

- (void) testMoves
{
    // Inserting a new object inside the managedObjectContext
    Note *newObject = [NSEntityDescription insertNewObjectForEntityForName:@"Note" inManagedObjectContext:self.managedObjectContext];
    newObject.text = @"a";
    newObject.order = @1;
    
    // Inserting a new object inside the managedObjectContext
    Note *newObject2 = [NSEntityDescription insertNewObjectForEntityForName:@"Note" inManagedObjectContext:self.managedObjectContext];
    newObject2.text = @"b";
    newObject2.order = @2;
    
    // Inserting a new object inside the managedObjectContext
    Note *newObject3 = [NSEntityDescription insertNewObjectForEntityForName:@"Note" inManagedObjectContext:self.managedObjectContext];
    newObject3.text = @"c";
    newObject3.order = @4;

    // Inserting a new object inside the managedObjectContext
    Note *newObject4 = [NSEntityDescription insertNewObjectForEntityForName:@"Note" inManagedObjectContext:self.managedObjectContext];
    newObject4.text = @"d";
    newObject4.order = @5;
    
    [self.targetArray addObjectsFromArray:@[newObject, newObject2, newObject3, newObject4]];
    
    [self.managedObjectContext processPendingChanges];
    
    // Creating the fetchedResultsController
    MRTFetchedResultsController *fetchedResultsController = [self notesFetchedResultsController];
    [fetchedResultsController performFetch:nil];
    
    newObject.order = @3;
    newObject4.order = @1;
    
    // Waiting for the did change expectation
    [self waitForExpectationsWithTimeout:self.expectationsDefaultTimeout handler:^(NSError *error) {
        if(error) XCTFail(@"Expectation Failed with error: %@", error);
        
        XCTAssertTrue([fetchedResultsController.arrangedObjects isEqualToArray:self.targetArray]);
    }];
}


- (void) testMovesAfter
{
    // Inserting a new object inside the managedObjectContext
    Note *newObject = [NSEntityDescription insertNewObjectForEntityForName:@"Note" inManagedObjectContext:self.managedObjectContext];
    newObject.order = @1;
    newObject.text = @"a";
    
    // Inserting a new object inside the managedObjectContext
    Note *newObject2 = [NSEntityDescription insertNewObjectForEntityForName:@"Note" inManagedObjectContext:self.managedObjectContext];
    newObject2.order = @2;
    newObject2.text = @"b";
    
    // Inserting a new object inside the managedObjectContext
    Note *newObject3 = [NSEntityDescription insertNewObjectForEntityForName:@"Note" inManagedObjectContext:self.managedObjectContext];
    newObject3.order = @3;
    newObject3.text = @"c";
    
    [self.targetArray addObjectsFromArray:@[newObject, newObject2, newObject3]];
    
    [self.managedObjectContext processPendingChanges];
    
    // Creating the fetchedResultsController
    MRTFetchedResultsController *fetchedResultsController = [self notesFetchedResultsController];
    [fetchedResultsController performFetch:nil];
    
    newObject.order = @4;
    
    // Waiting for the did change expectation
    [self waitForExpectationsWithTimeout:self.expectationsDefaultTimeout handler:^(NSError *error) {
        if(error) XCTFail(@"Expectation Failed with error: %@", error);
        
        XCTAssertTrue([fetchedResultsController.arrangedObjects isEqualToArray:self.targetArray]);
    }];
}


- (void) testMovesBefore
{
    // Inserting a new object inside the managedObjectContext
    Note *newObject = [NSEntityDescription insertNewObjectForEntityForName:@"Note" inManagedObjectContext:self.managedObjectContext];
    newObject.order = @1;
    newObject.text = @"a";
    
    // Inserting a new object inside the managedObjectContext
    Note *newObject2 = [NSEntityDescription insertNewObjectForEntityForName:@"Note" inManagedObjectContext:self.managedObjectContext];
    newObject2.order = @2;
    newObject2.text = @"b";
    
    // Inserting a new object inside the managedObjectContext
    Note *newObject3 = [NSEntityDescription insertNewObjectForEntityForName:@"Note" inManagedObjectContext:self.managedObjectContext];
    newObject3.order = @3;
    newObject3.text = @"c";
    
    [self.targetArray addObjectsFromArray:@[newObject, newObject2, newObject3]];
    
    [self.managedObjectContext processPendingChanges];
    
    // Creating the fetchedResultsController
    MRTFetchedResultsController *fetchedResultsController = [self notesFetchedResultsController];
    [fetchedResultsController performFetch:nil];
    
    newObject3.order = @0;
    
    // Waiting for the did change expectation
    [self waitForExpectationsWithTimeout:self.expectationsDefaultTimeout handler:^(NSError *error) {
        if(error) XCTFail(@"Expectation Failed with error: %@", error);
        
        XCTAssertTrue([fetchedResultsController.arrangedObjects isEqualToArray:self.targetArray]);
    }];
}

- (void) testMovesMiddle
{
    // Inserting a new object inside the managedObjectContext
    Note *newObject = [NSEntityDescription insertNewObjectForEntityForName:@"Note" inManagedObjectContext:self.managedObjectContext];
    newObject.order = @0;
    newObject.text = @"a";
    
    // Inserting a new object inside the managedObjectContext
    Note *newObject2 = [NSEntityDescription insertNewObjectForEntityForName:@"Note" inManagedObjectContext:self.managedObjectContext];
    newObject2.order = @1;
    newObject2.text = @"b";
    
    // Inserting a new object inside the managedObjectContext
    Note *newObject3 = [NSEntityDescription insertNewObjectForEntityForName:@"Note" inManagedObjectContext:self.managedObjectContext];
    newObject3.order = @3;
    newObject3.text = @"c";
    
    [self.targetArray addObjectsFromArray:@[newObject, newObject2, newObject3]];
    
    [self.managedObjectContext processPendingChanges];
    
    // Creating the fetchedResultsController
    MRTFetchedResultsController *fetchedResultsController = [self notesFetchedResultsController];
    [fetchedResultsController performFetch:nil];
    
    newObject.order = @2;
    
    // Waiting for the did change expectation
    [self waitForExpectationsWithTimeout:self.expectationsDefaultTimeout handler:^(NSError *error) {
        if(error) XCTFail(@"Expectation Failed with error: %@", error);
        
        XCTAssertTrue([fetchedResultsController.arrangedObjects isEqualToArray:self.targetArray]);
    }];
}

- (void) testMovesSwap
{
    // Inserting a new object inside the managedObjectContext
    Note *newObject = [NSEntityDescription insertNewObjectForEntityForName:@"Note" inManagedObjectContext:self.managedObjectContext];
    newObject.order = @0;
    newObject.text = @"a";
    
    // Inserting a new object inside the managedObjectContext
    Note *newObject2 = [NSEntityDescription insertNewObjectForEntityForName:@"Note" inManagedObjectContext:self.managedObjectContext];
    newObject2.order = @1;
    newObject2.text = @"b";
    
    // Inserting a new object inside the managedObjectContext
    Note *newObject3 = [NSEntityDescription insertNewObjectForEntityForName:@"Note" inManagedObjectContext:self.managedObjectContext];
    newObject3.order = @2;
    newObject3.text = @"c";
    
    [self.targetArray addObjectsFromArray:@[newObject, newObject2, newObject3]];
    
    [self.managedObjectContext processPendingChanges];
    
    // Creating the fetchedResultsController
    MRTFetchedResultsController *fetchedResultsController = [self notesFetchedResultsController];
    [fetchedResultsController performFetch:nil];
    
    newObject.order = @2;
    newObject3.order = @0;

    // Waiting for the did change expectation
    [self waitForExpectationsWithTimeout:self.expectationsDefaultTimeout handler:^(NSError *error) {
        if(error) XCTFail(@"Expectation Failed with error: %@", error);
        
        XCTAssertTrue([fetchedResultsController.arrangedObjects isEqualToArray:self.targetArray]);
    }];
}


- (void) testMovesDoubleHop
{
    // Inserting a new object inside the managedObjectContext
    Note *newObject = [NSEntityDescription insertNewObjectForEntityForName:@"Note" inManagedObjectContext:self.managedObjectContext];
    newObject.order = @1;
    newObject.text = @"a";
    
    // Inserting a new object inside the managedObjectContext
    Note *newObject2 = [NSEntityDescription insertNewObjectForEntityForName:@"Note" inManagedObjectContext:self.managedObjectContext];
    newObject2.order = @2;
    newObject2.text = @"b";
    
    // Inserting a new object inside the managedObjectContext
    Note *newObject3 = [NSEntityDescription insertNewObjectForEntityForName:@"Note" inManagedObjectContext:self.managedObjectContext];
    newObject3.order = @3;
    newObject3.text = @"c";
    
    [self.targetArray addObjectsFromArray:@[newObject, newObject2, newObject3]];
    
    [self.managedObjectContext processPendingChanges];
    
    // Creating the fetchedResultsController
    MRTFetchedResultsController *fetchedResultsController = [self notesFetchedResultsController];
    [fetchedResultsController performFetch:nil];
    
    newObject2.order = @4;
    newObject.order = @5;
    
    // Waiting for the did change expectation
    [self waitForExpectationsWithTimeout:self.expectationsDefaultTimeout handler:^(NSError *error) {
        if(error) XCTFail(@"Expectation Failed with error: %@", error);
        
        XCTAssertTrue([fetchedResultsController.arrangedObjects isEqualToArray:self.targetArray]);
    }];
}

- (void) testManyMoves
{
    // Inserting a new object inside the managedObjectContext
    Note *newObject = [NSEntityDescription insertNewObjectForEntityForName:@"Note" inManagedObjectContext:self.managedObjectContext];
    newObject.order = @1;
    newObject.text = @"a";
    
    // Inserting a new object inside the managedObjectContext
    Note *newObject2 = [NSEntityDescription insertNewObjectForEntityForName:@"Note" inManagedObjectContext:self.managedObjectContext];
    newObject2.order = @2;
    newObject2.text = @"b";
    
    // Inserting a new object inside the managedObjectContext
    Note *newObject3 = [NSEntityDescription insertNewObjectForEntityForName:@"Note" inManagedObjectContext:self.managedObjectContext];
    newObject3.order = @3;
    newObject3.text = @"c";
    
    // Inserting a new object inside the managedObjectContext
    Note *newObject4 = [NSEntityDescription insertNewObjectForEntityForName:@"Note" inManagedObjectContext:self.managedObjectContext];
    newObject4.order = @4;
    newObject4.text = @"d";

    // Inserting a new object inside the managedObjectContext
    Note *newObject5 = [NSEntityDescription insertNewObjectForEntityForName:@"Note" inManagedObjectContext:self.managedObjectContext];
    newObject5.order = @5;
    newObject5.text = @"e";

    
    // Inserting a new object inside the managedObjectContext
    Note *newObject6 = [NSEntityDescription insertNewObjectForEntityForName:@"Note" inManagedObjectContext:self.managedObjectContext];
    newObject6.order = @6;
    newObject6.text = @"f";

    [self.targetArray addObjectsFromArray:@[newObject, newObject2, newObject3, newObject4, newObject5, newObject6]];
    
    [self.managedObjectContext processPendingChanges];
    
    // Creating the fetchedResultsController
    MRTFetchedResultsController *fetchedResultsController = [self notesFetchedResultsController];
    [fetchedResultsController performFetch:nil];

    newObject.order = @5;
    newObject2.order = @3;
    newObject3.order = @1;
    newObject4.order = @4;
    newObject5.order = @2;
    newObject6.order = @6;

    // Waiting for the did change expectation
    [self waitForExpectationsWithTimeout:self.expectationsDefaultTimeout handler:^(NSError *error) {
        if(error) XCTFail(@"Expectation Failed with error: %@", error);
        
        XCTAssertTrue([fetchedResultsController.arrangedObjects isEqualToArray:self.targetArray]);
    }];
}

#pragma mark - Multiple changes

- (void) testInsertDelete
{
    
    // Inserting a new object inside the managedObjectContext
    Note *newObject = [NSEntityDescription insertNewObjectForEntityForName:@"Note" inManagedObjectContext:self.managedObjectContext];
    newObject.order = @1;
    
    Note *newObject2 = [NSEntityDescription insertNewObjectForEntityForName:@"Note" inManagedObjectContext:self.managedObjectContext];
    newObject2.order = @3;
    
    [self.targetArray addObjectsFromArray:@[newObject, newObject2]];
    
    // Processing changes so the object is no longer listed in the "inserted objects"
    [self.managedObjectContext processPendingChanges];
    
    // Creating the fetchedResultsController
    MRTFetchedResultsController *fetchedResultsController = [self notesFetchedResultsController];
    [fetchedResultsController performFetch:nil];
    
    // Insert a new object between the two
    Note *newObject3 = [NSEntityDescription insertNewObjectForEntityForName:@"Note" inManagedObjectContext:self.managedObjectContext];
    newObject3.order = @2;
    
    // At the same time deleting the first object
    [self.managedObjectContext deleteObject:newObject];
    
    // Waiting for the did change expectation
    [self waitForExpectationsWithTimeout:self.expectationsDefaultTimeout handler:^(NSError *error) {
        if(error) XCTFail(@"Expectation Failed with error: %@", error);
        
        XCTAssertTrue([fetchedResultsController.arrangedObjects isEqualToArray:self.targetArray]);
    }];
}


- (void) testMoveInsert
{
    
    // Inserting a new object inside the managedObjectContext
    Note *newObject = [NSEntityDescription insertNewObjectForEntityForName:@"Note" inManagedObjectContext:self.managedObjectContext];
    newObject.order = @1;
    
    Note *newObject2 = [NSEntityDescription insertNewObjectForEntityForName:@"Note" inManagedObjectContext:self.managedObjectContext];
    newObject2.order = @3;
    
    [self.targetArray addObjectsFromArray:@[newObject, newObject2]];
    
    // Processing changes so the object is no longer listed in the "inserted objects"
    [self.managedObjectContext processPendingChanges];
    
    // Creating the fetchedResultsController
    MRTFetchedResultsController *fetchedResultsController = [self notesFetchedResultsController];
    [fetchedResultsController performFetch:nil];
    
    // Insert a new object between the two
    Note *newObject3 = [NSEntityDescription insertNewObjectForEntityForName:@"Note" inManagedObjectContext:self.managedObjectContext];
    newObject3.order = @2;
    
    // At the same time changing the order of the first note
    newObject.order = @4;


    // Waiting for the did change expectation
    [self waitForExpectationsWithTimeout:self.expectationsDefaultTimeout handler:^(NSError *error) {
        if(error) XCTFail(@"Expectation Failed with error: %@", error);
        
        XCTAssertTrue([fetchedResultsController.arrangedObjects isEqualToArray:self.targetArray]);
    }];
}


- (void) testMoveDelete
{
    // Inserting a new object inside the managedObjectContext
    Note *newObject = [NSEntityDescription insertNewObjectForEntityForName:@"Note" inManagedObjectContext:self.managedObjectContext];
    newObject.order = @1;
    
    // Inserting a new object inside the managedObjectContext
    Note *newObject2 = [NSEntityDescription insertNewObjectForEntityForName:@"Note" inManagedObjectContext:self.managedObjectContext];
    newObject2.order = @2;
    
    // Inserting a new object inside the managedObjectContext
    Note *newObject3 = [NSEntityDescription insertNewObjectForEntityForName:@"Note" inManagedObjectContext:self.managedObjectContext];
    newObject3.order = @4;
    
    // Inserting a new object inside the managedObjectContext
    Note *newObject4 = [NSEntityDescription insertNewObjectForEntityForName:@"Note" inManagedObjectContext:self.managedObjectContext];
    newObject4.order = @5;
    
    [self.targetArray addObjectsFromArray:@[newObject, newObject2, newObject3, newObject4]];
    
    [self.managedObjectContext processPendingChanges];
    
    // Creating the fetchedResultsController
    MRTFetchedResultsController *fetchedResultsController = [self notesFetchedResultsController];
    [fetchedResultsController performFetch:nil];
    
    newObject4.order = @3;
    [self.managedObjectContext deleteObject:newObject];
    
    // Waiting for the did change expectation
    [self waitForExpectationsWithTimeout:self.expectationsDefaultTimeout handler:^(NSError *error) {
        if(error) XCTFail(@"Expectation Failed with error: %@", error);
        
        XCTAssertTrue([fetchedResultsController.arrangedObjects isEqualToArray:self.targetArray]);
    }];
}



#pragma mark - MRTFetchedResultsControllerDelegate

- (void)controllerWillChangeContent:(MRTFetchedResultsController *)controller
{
}

- (void)controllerDidChangeContent:(MRTFetchedResultsController *)controller
{
    [self.didChangeContentExpectation fulfill];
}


- (void)controller:(MRTFetchedResultsController *)controller didChangeObject:(id)anObject atIndex:(NSUInteger)index progressiveChangeIndex:(NSUInteger) progressiveChangeIndex forChangeType:(MRTFetchedResultsChangeType)type newIndex:(NSUInteger)newIndex;
{
    switch (type) {
        case MRTFetchedResultsChangeDelete:
            NSLog(@"deleted %@ at %lu", [anObject text], progressiveChangeIndex);
            [self.targetArray removeObjectAtIndex:progressiveChangeIndex];
            break;
        case MRTFetchedResultsChangeInsert:
            [self.targetArray insertObject:anObject atIndex:newIndex];
            break;
        case MRTFetchedResultsChangeUpdate:
            NSLog(@"update %@ at %lu", [anObject text], progressiveChangeIndex);
            break;
        case MRTFetchedResultsChangeMove:
            NSLog(@"move %@ from %lu in %lu", [anObject text], (unsigned long)progressiveChangeIndex, (unsigned long)newIndex);
            [self.targetArray removeObjectAtIndex:progressiveChangeIndex];
            [self.targetArray insertObject:anObject atIndex:newIndex];
            break;
        default:
            break;
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


@end
