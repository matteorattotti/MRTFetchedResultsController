//
//  MRTFetchedResultsControllerTests.m
//  MRTFetchedResultsControllerTests
//
//  Created by Matteo Rattotti on 14/05/15.
//
//

#import <Cocoa/Cocoa.h>
#import <XCTest/XCTest.h>
#import "MRTFetchedResultsController.h"
#import "Note.h"

@interface MRTFetchedResultsControllerTests : XCTestCase <MRTFetchedResultsControllerDelegate>

@property (strong) NSManagedObjectContext *managedObjectContext;
@property (strong) NSManagedObjectContext *privateManagedObjectContext;

@property (nonatomic) CGFloat expectationsDefaultTimeout;

@property (nonatomic) NSUInteger numberOfInserts;
@property (nonatomic) NSUInteger numberOfDeletes;
@property (nonatomic) NSUInteger numberOfUpdates;
@property (nonatomic) NSUInteger numberOfMoves;

@property (nonatomic) NSUInteger numberOfWillChangeContext;
@property (nonatomic) NSUInteger numberOfDidChangeContext;

@end

@implementation MRTFetchedResultsControllerTests

#pragma mark - Setup

- (void)setUp {
    [super setUp];
    
    [self setupCoreData];
    
    self.expectationsDefaultTimeout = 0.1;
    
    self.numberOfInserts = 0;
    self.numberOfDeletes = 0;
    self.numberOfUpdates = 0;
    self.numberOfMoves   = 0;
    
    self.numberOfWillChangeContext = 0;
    self.numberOfDidChangeContext = 0;
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

- (void) setupPrivateManagedObjectContext
{
    self.privateManagedObjectContext = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSPrivateQueueConcurrencyType];
    self.privateManagedObjectContext.persistentStoreCoordinator = self.managedObjectContext.persistentStoreCoordinator;
    [[NSNotificationCenter defaultCenter] addObserverForName:NSManagedObjectContextDidSaveNotification object:self.privateManagedObjectContext queue:nil usingBlock:^(NSNotification *note) {
        [self.managedObjectContext performBlock:^{
            [self.managedObjectContext mergeChangesFromContextDidSaveNotification:note];
        }];

    }];
}

#pragma mark - Tear Down

- (void)tearDown {
    [super tearDown];
}


#pragma mark - Insertion

// Inserting one object that match the request expecting one insert
- (void) testInsertion
{
    // Creating the fetchedResultsController
    MRTFetchedResultsController *fetchedResultsController = [self notesFetchedResultsController];
    [fetchedResultsController performFetch:nil];
    
    // Inserting a new object inside the managedObjectContext
    Note *newObject = [NSEntityDescription insertNewObjectForEntityForName:@"Note" inManagedObjectContext:self.managedObjectContext];
    
    // Creating a new expectation
    XCTestExpectation *expectation = [self expectationWithDescription:@"Insertion of new object notified"];
    newObject.insertExpectation = expectation;
    
    // Waiting for all expectations
    [self waitForExpectationsWithTimeout:self.expectationsDefaultTimeout handler:^(NSError *error) {
        if(error) XCTFail(@"Expectation Failed with error: %@", error);

        // Checking number and type of events
        [self checkExpectedNumberOfInserts:1 deletes:0 updates:0 moves:0];
        
        // Checking number of delegate calls
        [self checkNumberOfWillDidChangeCalls:1];

        // Checking total number of object in the controller
        XCTAssertEqual([fetchedResultsController count], 1, @"Number of object in the fetchedResultsController doesn't match");
    }];
}


- (void) testInsertionOrder
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
    newObject3.order = @0;

    // Waiting for the delegate notifications
    CFRunLoopRunInMode( kCFRunLoopDefaultMode, self.expectationsDefaultTimeout, NO );
    
    // Checking number and type of events
    [self checkExpectedNumberOfInserts:3 deletes:0 updates:0 moves:0];
    
    // Checking number of delegate calls
    [self checkNumberOfWillDidChangeCalls:1];
    
    // Checking total number of object in the controller
    XCTAssertEqual([fetchedResultsController count], 3, @"Number of object in the fetchedResultsController doesn't match");

    // Checking correct ordering
    XCTAssertEqual([fetchedResultsController indexOfObject:newObject], 1, @"Wrong order of object after insertion");
    XCTAssertEqual([fetchedResultsController indexOfObject:newObject2], 2, @"Wrong order of object after insertion");
    XCTAssertEqual([fetchedResultsController indexOfObject:newObject3], 0, @"Wrong order of object after insertion");
}


// Inserting one object that match the request+predicate expecting one insert
- (void) testInsertionWithPredicateMatchedObject
{
    // Creating the fetchedResultsController
    MRTFetchedResultsController *fetchedResultsController = [self untrashedNotesFetchedResultsController];
    [fetchedResultsController performFetch:nil];
    
    // Inserting a matching object
    Note *newObject = [NSEntityDescription insertNewObjectForEntityForName:@"Note" inManagedObjectContext:self.managedObjectContext];
    newObject.trashed = @NO;
    
    // Creating a new expectation
    XCTestExpectation *expectation = [self expectationWithDescription:@"Insertion of new object notified"];
    newObject.insertExpectation = expectation;

    // Waiting for all expectations
    [self waitForExpectationsWithTimeout:self.expectationsDefaultTimeout handler:^(NSError *error) {
        if(error) XCTFail(@"Expectation Failed with error: %@", error);
        
        // Checking number and type of events
        [self checkExpectedNumberOfInserts:1 deletes:0 updates:0 moves:0];

        // Checking number of delegate calls
        [self checkNumberOfWillDidChangeCalls:1];
        
        // Checking total number of object in the controller
        XCTAssertEqual([fetchedResultsController count], 1, @"Number of object in the fetchedResultsController doesn't match");
    }];
}

// Inserting one object that doesn't match the request+predicate expecting no insert
- (void) testInsertionWithPredicateUnmatchedObject
{
    // Creating the fetchedResultsController
    MRTFetchedResultsController *fetchedResultsController = [self untrashedNotesFetchedResultsController];
    [fetchedResultsController performFetch:nil];
    
    // Inserting a non matching object
    Note *newObject2 = [NSEntityDescription insertNewObjectForEntityForName:@"Note" inManagedObjectContext:self.managedObjectContext];
    newObject2.trashed = @YES;
    
    CFRunLoopRunInMode( kCFRunLoopDefaultMode, self.expectationsDefaultTimeout, NO );

    // Checking number and type of events
    [self checkExpectedNumberOfInserts:0 deletes:0 updates:0 moves:0];
    
    // Checking number of delegate calls
    [self checkNumberOfWillDidChangeCalls:0];
    
    // Checking total number of object in the controller
    XCTAssertEqual([fetchedResultsController count], 0, @"Number of object in the fetchedResultsController doesn't match");
}


#pragma mark - Update

- (void) testUpdate
{
    // Inserting a new object inside the managedObjectContext
    Note *newObject = [NSEntityDescription insertNewObjectForEntityForName:@"Note" inManagedObjectContext:self.managedObjectContext];
    
    // Processing changes so the object is no longer listed in the "inserted objects"
    [self.managedObjectContext processPendingChanges];

    // Creating the fetchedResultsController
    MRTFetchedResultsController *fetchedResultsController = [self notesFetchedResultsController];
    [fetchedResultsController performFetch:nil];
    
    // Updating the object
    newObject.text = @"new text";
    
    // Creating a new expectation
    XCTestExpectation *expectation = [self expectationWithDescription:@"Update of object notified"];
    newObject.updateExpectation = expectation;
    
    // Waiting for all expectations
    [self waitForExpectationsWithTimeout:self.expectationsDefaultTimeout handler:^(NSError *error) {
        if(error) XCTFail(@"Expectation Failed with error: %@", error);
        
        // Checking number and type of events
        [self checkExpectedNumberOfInserts:0 deletes:0 updates:1 moves:0];
        
        // Checking number of delegate calls
        [self checkNumberOfWillDidChangeCalls:1];
        
        // Checking total number of object in the controller
        XCTAssertEqual([fetchedResultsController count], 1, @"Number of object in the fetchedResultsController doesn't match");
    }];
}

// Updating an object that was outside the controller, the update will trigger a match in the predicate and we expect an insert in the controller
- (void) testUpdateWithPredicateMatchedObject
{
    // Inserting a matching object
    Note *newObject = [NSEntityDescription insertNewObjectForEntityForName:@"Note" inManagedObjectContext:self.managedObjectContext];
    newObject.trashed = @YES;
    
    [self.managedObjectContext processPendingChanges];

    // Creating the fetchedResultsController
    MRTFetchedResultsController *fetchedResultsController = [self untrashedNotesFetchedResultsController];
    [fetchedResultsController performFetch:nil];

    // Checking total number of object in the controller
    XCTAssertEqual([fetchedResultsController count], 0, @"Number of object in the fetchedResultsController doesn't match");
    
    // Updating the object so it now matches the predicate
    newObject.trashed = @NO;
    
    // Creating a new expectation
    XCTestExpectation *expectation = [self expectationWithDescription:@"Insert of object notified"];
    newObject.insertExpectation = expectation;

    // Waiting for all expectations
    [self waitForExpectationsWithTimeout:self.expectationsDefaultTimeout handler:^(NSError *error) {
        if(error) XCTFail(@"Expectation Failed with error: %@", error);
        
        // Checking number and type of events
        [self checkExpectedNumberOfInserts:1 deletes:0 updates:0 moves:0];
        
        // Checking number of delegate calls
        [self checkNumberOfWillDidChangeCalls:1];
        
        // Checking total number of object in the controller
        XCTAssertEqual([fetchedResultsController count], 1, @"Number of object in the fetchedResultsController doesn't match");
    }];
}

// Updating an object that was inside the controller, the update will trigger a  mismatch in the predicate and we expect a delete in the controller
- (void) testUpdateWithPredicateUnmatchedObject
{
    // Inserting a matching object
    Note *newObject = [NSEntityDescription insertNewObjectForEntityForName:@"Note" inManagedObjectContext:self.managedObjectContext];
    newObject.trashed = @NO;
    
    [self.managedObjectContext processPendingChanges];
    
    // Creating the fetchedResultsController
    MRTFetchedResultsController *fetchedResultsController = [self untrashedNotesFetchedResultsController];
    [fetchedResultsController performFetch:nil];
    
    // Checking total number of object in the controller
    XCTAssertEqual([fetchedResultsController count], 1, @"Number of object in the fetchedResultsController doesn't match");
    
    // Updating the object so it now matches the predicate
    newObject.trashed = @YES;
    
    // Creating a new expectation
    XCTestExpectation *expectation = [self expectationWithDescription:@"Delete of object notified"];
    newObject.deleteExpectation = expectation;
    
    // Waiting for all expectations
    [self waitForExpectationsWithTimeout:self.expectationsDefaultTimeout handler:^(NSError *error) {
        if(error) XCTFail(@"Expectation Failed with error: %@", error);
        
        // Checking number and type of events
        [self checkExpectedNumberOfInserts:0 deletes:1 updates:0 moves:0];
        
        // Checking number of delegate calls
        [self checkNumberOfWillDidChangeCalls:1];

        // Checking total number of object in the controller
        XCTAssertEqual([fetchedResultsController count], 0, @"Number of object in the fetchedResultsController doesn't match");
    }];
}

#pragma mark - Deletion

- (void) testDeletion
{
    // Inserting a new object inside the managedObjectContext
    Note *newObject = [NSEntityDescription insertNewObjectForEntityForName:@"Note" inManagedObjectContext:self.managedObjectContext];
    
    // Processing changes so the object is no longer listed in the "inserted objects"
    [self.managedObjectContext processPendingChanges];

    // Creating the fetchedResultsController
    MRTFetchedResultsController *fetchedResultsController = [self notesFetchedResultsController];
    [fetchedResultsController performFetch:nil];
    
    // Deleting the object
    [self.managedObjectContext deleteObject:newObject];
    
    // Creating a new expectation
    XCTestExpectation *expectation = [self expectationWithDescription:@"Delete of object notified"];
    newObject.deleteExpectation = expectation;
    
    // Waiting for all expectations
    [self waitForExpectationsWithTimeout:self.expectationsDefaultTimeout handler:^(NSError *error) {
        if(error) XCTFail(@"Expectation Failed with error: %@", error);

        // Checking number and type of events
        [self checkExpectedNumberOfInserts:0 deletes:1 updates:0 moves:0];
        
        // Checking number of delegate calls
        [self checkNumberOfWillDidChangeCalls:1];

        // Checking total number of object in the controller
        XCTAssertEqual([fetchedResultsController count], 0, @"Number of object in the fetchedResultsController doesn't match");
    }];
}

- (void) testDeletionOrder
{
    // Inserting a new object inside the managedObjectContext
    Note *newObject = [NSEntityDescription insertNewObjectForEntityForName:@"Note" inManagedObjectContext:self.managedObjectContext];
    newObject.order = @0;
    
    // Inserting a new object inside the managedObjectContext
    Note *newObject2 = [NSEntityDescription insertNewObjectForEntityForName:@"Note" inManagedObjectContext:self.managedObjectContext];
    newObject2.order = @1;
    
    // Inserting a new object inside the managedObjectContext
    Note *newObject3 = [NSEntityDescription insertNewObjectForEntityForName:@"Note" inManagedObjectContext:self.managedObjectContext];
    newObject3.order = @2;
    
    // Processing changes so the object is no longer listed in the "inserted objects"
    [self.managedObjectContext processPendingChanges];

    // Creating the fetchedResultsController
    MRTFetchedResultsController *fetchedResultsController = [self notesFetchedResultsController];
    [fetchedResultsController performFetch:nil];
    
    // Deleting the first object
    [self.managedObjectContext deleteObject:newObject];

    // Waiting for the delegate notifications
    CFRunLoopRunInMode( kCFRunLoopDefaultMode, self.expectationsDefaultTimeout, NO );
    
    // Checking number and type of events
    [self checkExpectedNumberOfInserts:0 deletes:1 updates:0 moves:0];
    
    // Checking number of delegate calls
    [self checkNumberOfWillDidChangeCalls:1];

    // Checking total number of object in the controller
    XCTAssertEqual([fetchedResultsController count], 2, @"Number of object in the fetchedResultsController doesn't match");
    
    // Checking correct ordering
    XCTAssertEqual([fetchedResultsController indexOfObject:newObject], NSNotFound, @"Wrong order of object after insertion");
    XCTAssertEqual([fetchedResultsController indexOfObject:newObject2], 0, @"Wrong order of object after insertion");
    XCTAssertEqual([fetchedResultsController indexOfObject:newObject3], 1, @"Wrong order of object after insertion");
}

- (void) testDeletionWithPredicateMatchedObject
{
    // Inserting a matching object
    Note *newObject = [NSEntityDescription insertNewObjectForEntityForName:@"Note" inManagedObjectContext:self.managedObjectContext];
    newObject.trashed = @NO;
    
    [self.managedObjectContext processPendingChanges];
    
    // Creating the fetchedResultsController
    MRTFetchedResultsController *fetchedResultsController = [self untrashedNotesFetchedResultsController];
    [fetchedResultsController performFetch:nil];
    
    // Checking total number of object in the controller
    XCTAssertEqual([fetchedResultsController count], 1, @"Number of object in the fetchedResultsController doesn't match");
    
    // Deleting the object
    [self.managedObjectContext deleteObject:newObject];
    
    // Creating a new expectation
    XCTestExpectation *expectation = [self expectationWithDescription:@"Delete of object notified"];
    newObject.deleteExpectation = expectation;
    
    // Waiting for all expectations
    [self waitForExpectationsWithTimeout:self.expectationsDefaultTimeout handler:^(NSError *error) {
        if(error) XCTFail(@"Expectation Failed with error: %@", error);
        
        // Checking number and type of events
        [self checkExpectedNumberOfInserts:0 deletes:1 updates:0 moves:0];
        
        // Checking number of delegate calls
        [self checkNumberOfWillDidChangeCalls:1];

        // Checking total number of object in the controller
        XCTAssertEqual([fetchedResultsController count], 0, @"Number of object in the fetchedResultsController doesn't match");
    }];
}

- (void) testDeletionWithPredicateUnmatchedObject
{
    // Inserting a matching object
    Note *newObject = [NSEntityDescription insertNewObjectForEntityForName:@"Note" inManagedObjectContext:self.managedObjectContext];
    newObject.trashed = @YES;
    
    [self.managedObjectContext processPendingChanges];
    
    // Creating the fetchedResultsController
    MRTFetchedResultsController *fetchedResultsController = [self untrashedNotesFetchedResultsController];
    [fetchedResultsController performFetch:nil];
    
    // Checking total number of object in the controller
    XCTAssertEqual([fetchedResultsController count], 0, @"Number of object in the fetchedResultsController doesn't match");
    
    // Deleting the object
    [self.managedObjectContext deleteObject:newObject];
    
    CFRunLoopRunInMode( kCFRunLoopDefaultMode, self.expectationsDefaultTimeout, NO );
    
    // Checking number and type of events
    [self checkExpectedNumberOfInserts:0 deletes:0 updates:0 moves:0];
    
    // Checking number of delegate calls
    [self checkNumberOfWillDidChangeCalls:0];
    
    // Checking total number of object in the controller
    XCTAssertEqual([fetchedResultsController count], 0, @"Number of object in the fetchedResultsController doesn't match");
}


- (void) testDeletionWithPredicateChangingFromMatchedToUnmatchedObject
{
    // Inserting a matching object
    Note *newObject = [NSEntityDescription insertNewObjectForEntityForName:@"Note" inManagedObjectContext:self.managedObjectContext];
    newObject.trashed = @NO;
    
    [self.managedObjectContext processPendingChanges];
    
    // Creating the fetchedResultsController
    MRTFetchedResultsController *fetchedResultsController = [self untrashedNotesFetchedResultsController];
    [fetchedResultsController performFetch:nil];
    
    XCTAssertEqual([fetchedResultsController count], 1, @"Number of object in the fetchedResultsController doesn't match");

    newObject.trashed = @YES;
    [self.managedObjectContext deleteObject:newObject];
    
    CFRunLoopRunInMode( kCFRunLoopDefaultMode, self.expectationsDefaultTimeout, NO );

    // Checking total number of object in the controller
    XCTAssertEqual([fetchedResultsController count], 0, @"Number of object in the fetchedResultsController doesn't match");
    
    CFRunLoopRunInMode( kCFRunLoopDefaultMode, self.expectationsDefaultTimeout, NO );
    
    // Checking number and type of events
    [self checkExpectedNumberOfInserts:0 deletes:1 updates:0 moves:0];
    
    // Checking number of delegate calls
    [self checkNumberOfWillDidChangeCalls:1];
    
    // Checking total number of object in the controller
    XCTAssertEqual([fetchedResultsController count], 0, @"Number of object in the fetchedResultsController doesn't match");
}


#pragma mark - Move

- (void) testMove
{
    
    // Inserting a new object inside the managedObjectContext
    Note *newObject = [NSEntityDescription insertNewObjectForEntityForName:@"Note" inManagedObjectContext:self.managedObjectContext];
    newObject.order = @1;
    
    Note *newObject2 = [NSEntityDescription insertNewObjectForEntityForName:@"Note" inManagedObjectContext:self.managedObjectContext];
    newObject2.order = @2;
    
    // Processing changes so the object is no longer listed in the "inserted objects"
    [self.managedObjectContext processPendingChanges];

    // Creating the fetchedResultsController
    MRTFetchedResultsController *fetchedResultsController = [self notesFetchedResultsController];
    [fetchedResultsController performFetch:nil];

    // Changing order
    newObject2.order = @0;
    
    // Creating a new expectation
    XCTestExpectation *expectation = [self expectationWithDescription:@"Move of object notified"];
    newObject2.moveExpectation = expectation;
    
    // Waiting for all expectations
    [self waitForExpectationsWithTimeout:self.expectationsDefaultTimeout handler:^(NSError *error) {
        if(error) XCTFail(@"Expectation Failed with error: %@", error);

        // Checking number and type of events
        [self checkExpectedNumberOfInserts:0 deletes:0 updates:0 moves:1];
        
        // Checking number of delegate calls
        [self checkNumberOfWillDidChangeCalls:1];

        // Checking total number of object in the controller
        XCTAssertEqual([fetchedResultsController count], 2, @"Number of object in the fetchedResultsController doesn't match");
    }];
}

// Testing a change in the object sort key that doesn't really move the item, expecting an update and
// not a move event to be called
- (void) testMoveUpdate
{
    
    // Inserting a new object inside the managedObjectContext
    Note *newObject = [NSEntityDescription insertNewObjectForEntityForName:@"Note" inManagedObjectContext:self.managedObjectContext];
    newObject.order = @1;
    
    Note *newObject2 = [NSEntityDescription insertNewObjectForEntityForName:@"Note" inManagedObjectContext:self.managedObjectContext];
    newObject2.order = @2;
    
    // Processing changes so the object is no longer listed in the "inserted objects"
    [self.managedObjectContext processPendingChanges];
    
    // Creating the fetchedResultsController
    MRTFetchedResultsController *fetchedResultsController = [self notesFetchedResultsController];
    [fetchedResultsController performFetch:nil];
    
    // Changing the order value in a way that won't affect the global order in the fetchedResultController
    newObject2.order = @3;
    
    // Creating a new expectation
    XCTestExpectation *expectation = [self expectationWithDescription:@"Update of object notified"];
    newObject2.updateExpectation = expectation;
    
    // Waiting for all expectations
    [self waitForExpectationsWithTimeout:self.expectationsDefaultTimeout handler:^(NSError *error) {
        if(error) XCTFail(@"Expectation Failed with error: %@", error);
        
        // Checking number and type of events
        [self checkExpectedNumberOfInserts:0 deletes:0 updates:1 moves:0];
        
        // Checking number of delegate calls
        [self checkNumberOfWillDidChangeCalls:1];

        // Checking total number of object in the controller
        XCTAssertEqual([fetchedResultsController count], 2, @"Number of object in the fetchedResultsController doesn't match");
    }];
}


- (void) testMoveWithPredicateMatchedObject
{
    
    // Inserting a new object inside the managedObjectContext
    Note *newObject = [NSEntityDescription insertNewObjectForEntityForName:@"Note" inManagedObjectContext:self.managedObjectContext];
    newObject.order = @1;
    newObject.trashed = @NO;
    
    Note *newObject2 = [NSEntityDescription insertNewObjectForEntityForName:@"Note" inManagedObjectContext:self.managedObjectContext];
    newObject2.order = @2;
    newObject2.trashed = @NO;
    
    // Processing changes so the object is no longer listed in the "inserted objects"
    [self.managedObjectContext processPendingChanges];
    
    // Creating the fetchedResultsController
    MRTFetchedResultsController *fetchedResultsController = [self untrashedNotesFetchedResultsController];
    [fetchedResultsController performFetch:nil];

    // Changing order
    newObject2.order = @0;
    
    // Creating a new expectation
    XCTestExpectation *expectation = [self expectationWithDescription:@"Move of object notified"];
    newObject2.moveExpectation = expectation;
    
    // Waiting for all expectations
    [self waitForExpectationsWithTimeout:self.expectationsDefaultTimeout handler:^(NSError *error) {
        if(error) XCTFail(@"Expectation Failed with error: %@", error);
        
        // Checking number and type of events
        [self checkExpectedNumberOfInserts:0 deletes:0 updates:0 moves:1];
        
        // Checking number of delegate calls
        [self checkNumberOfWillDidChangeCalls:1];

        // Checking total number of object in the controller
        XCTAssertEqual([fetchedResultsController count], 2, @"Number of object in the fetchedResultsController doesn't match");
    }];
}

- (void) testMoveWithPredicateUnmatchedObject
{
    
    // Inserting a new object inside the managedObjectContext
    Note *newObject = [NSEntityDescription insertNewObjectForEntityForName:@"Note" inManagedObjectContext:self.managedObjectContext];
    newObject.order = @1;
    newObject.trashed = @NO;
    
    Note *newObject2 = [NSEntityDescription insertNewObjectForEntityForName:@"Note" inManagedObjectContext:self.managedObjectContext];
    newObject2.order = @2;
    newObject2.trashed = @YES;
    
    // Processing changes so the object is no longer listed in the "inserted objects"
    [self.managedObjectContext processPendingChanges];
    
    // Creating the fetchedResultsController
    MRTFetchedResultsController *fetchedResultsController = [self untrashedNotesFetchedResultsController];
    [fetchedResultsController performFetch:nil];
    
    // Changing order
    newObject2.order = @0;
    
    CFRunLoopRunInMode( kCFRunLoopDefaultMode, self.expectationsDefaultTimeout, NO );
    
    // Checking number and type of events
    [self checkExpectedNumberOfInserts:0 deletes:0 updates:0 moves:0];
    
    // Checking number of delegate calls
    [self checkNumberOfWillDidChangeCalls:0];

    // Checking total number of object in the controller
    XCTAssertEqual([fetchedResultsController count], 1, @"Number of object in the fetchedResultsController doesn't match");
}

#pragma mark - Refresh

// Objects will be listed in the NSRefreshedObjectsKey when they are updated in another NSManagedObjectContext and merged with the
// mergeChangesFromContextDidSaveNotification in the "main" context
- (void) testRefresh
{
    // Inserting a new object inside the managedObjectContext
    Note *newObject = [NSEntityDescription insertNewObjectForEntityForName:@"Note" inManagedObjectContext:self.managedObjectContext];
    newObject.text = @"initial text";
    
    // Creating a new expectation
    XCTestExpectation *expectation = [self expectationWithDescription:@"update of object notified"];
    newObject.updateExpectation = expectation;

    // Saving the context (in order to get the final objectID)
    [self.managedObjectContext save:nil];

    // Setting up a offthread MOC to update the object
    [self setupPrivateManagedObjectContext];
    
    __block NSManagedObjectID *objectID = [newObject objectID];
    
    // Creating the fetchedResultsController
    MRTFetchedResultsController *fetchedResultsController = [self notesFetchedResultsController];
    [fetchedResultsController performFetch:nil];
    
    // Updating the object on the private MOC
    [self.privateManagedObjectContext performBlockAndWait:^{
        Note *privateNote = (Note *)[self.privateManagedObjectContext existingObjectWithID:objectID error:nil];
        privateNote.text = @"updated text";
        [self.privateManagedObjectContext save:nil];
        
    }];
    
    // Waiting for all expectations
    [self waitForExpectationsWithTimeout:self.expectationsDefaultTimeout handler:^(NSError *error) {
        if(error) XCTFail(@"Expectation Failed with error: %@", error);
       
        // Checking number and type of events
        [self checkExpectedNumberOfInserts:0 deletes:0 updates:1 moves:0];

    }];
}

- (void) testRefreshOrder
{
    Note *newObject = [NSEntityDescription insertNewObjectForEntityForName:@"Note" inManagedObjectContext:self.managedObjectContext];
    newObject.order = @0;

    Note *newObject2 = [NSEntityDescription insertNewObjectForEntityForName:@"Note" inManagedObjectContext:self.managedObjectContext];
    newObject2.order = @1;

    Note *newObject3 = [NSEntityDescription insertNewObjectForEntityForName:@"Note" inManagedObjectContext:self.managedObjectContext];
    newObject3.order = @2;

    
    // Creating a new expectation
    XCTestExpectation *expectation = [self expectationWithDescription:@"move of object notified"];
    newObject.moveExpectation = expectation;
    
    // Saving the context (in order to get the final objectID)
    [self.managedObjectContext save:nil];
    
    // Setting up a offthread MOC to update the object
    [self setupPrivateManagedObjectContext];
    
    __block NSManagedObjectID *objectID = [newObject objectID];
    
    // Creating the fetchedResultsController
    MRTFetchedResultsController *fetchedResultsController = [self notesFetchedResultsController];
    [fetchedResultsController performFetch:nil];
    
    // Updating the object on the private MOC
    [self.privateManagedObjectContext performBlockAndWait:^{
        Note *privateNote = (Note *)[self.privateManagedObjectContext existingObjectWithID:objectID error:nil];
        privateNote.order = @3;
        [self.privateManagedObjectContext save:nil];
        
    }];
    
    // Waiting for all expectations
    [self waitForExpectationsWithTimeout:self.expectationsDefaultTimeout handler:^(NSError *error) {
        if(error) XCTFail(@"Expectation Failed with error: %@", error);
        
        // Checking number and type of events
        [self checkExpectedNumberOfInserts:0 deletes:0 updates:0 moves:1];
        
    }];

}


#pragma mark - Multiply Changes

- (void) testMultipleTypeOfChanges
{
//     Initial status:
//     "empty"
//     
//     Status after first group of changes:
//     newObject (order 1) -> insert
//     newObject2 (order 2) -> insert
//     
//     Status aftersSecond group of changes:
//     newObject2 (order 0) -> move
//     newObject (order 1, "updated text") -> update
//     newObject3 (order 3) -> insert/deleted (won't fire any change)
//     newObject4 (order 4) -> insert
//     
//     Final Status:
//     newObject2 (order 0)
//     newObject (order 1, "updated text")
//     newObject4 (order 4)
    
    
    // Inserting a new object inside the managedObjectContext
    Note *newObject0 = [NSEntityDescription insertNewObjectForEntityForName:@"Note" inManagedObjectContext:self.managedObjectContext];
    newObject0.order = @0;
    newObject0.text = @"0";
    
    // Inserting a new object inside the managedObjectContext
    Note *newObject1 = [NSEntityDescription insertNewObjectForEntityForName:@"Note" inManagedObjectContext:self.managedObjectContext];
    newObject1.order = @3;
    newObject1.text = @"1";
    
    // Inserting a new object inside the managedObjectContext
    Note *newObject2 = [NSEntityDescription insertNewObjectForEntityForName:@"Note" inManagedObjectContext:self.managedObjectContext];
    newObject2.order = @4;
    newObject2.text = @"2";
    
    // Inserting a new object inside the managedObjectContext
    Note *newObject3 = [NSEntityDescription insertNewObjectForEntityForName:@"Note" inManagedObjectContext:self.managedObjectContext];
    newObject3.order = @5;
    newObject3.text = @"3";
    
    // Inserting a new object inside the managedObjectContext
    Note *newObject4 = [NSEntityDescription insertNewObjectForEntityForName:@"Note" inManagedObjectContext:self.managedObjectContext];
    newObject4.order = @6;
    newObject4.text = @"4";

    // Processing changes so the object is no longer listed in the "inserted objects"
    [self.managedObjectContext processPendingChanges];

    // Creating the fetchedResultsController
    MRTFetchedResultsController *fetchedResultsController = [self notesFetchedResultsController];
    [fetchedResultsController performFetch:nil];
    
    newObject0.text = @"update";
    [self.managedObjectContext deleteObject:newObject2];
    newObject3.order =  @2;
    Note *newObject5 = [NSEntityDescription insertNewObjectForEntityForName:@"Note" inManagedObjectContext:self.managedObjectContext];
    newObject5.order = @1;
    newObject5.text = @"5";
    
    // Waiting for the delegate notifications
    CFRunLoopRunInMode( kCFRunLoopDefaultMode, self.expectationsDefaultTimeout, NO );
    
    // Checking number and type of events
    [self checkExpectedNumberOfInserts:1 deletes:1 updates:1 moves:1];
    
    // Checking total number of object in the controller
    XCTAssertEqual([fetchedResultsController count], 5, @"Number of object in the fetchedResultsController doesn't match");
    
    // Checking correct ordering
    XCTAssertEqual([fetchedResultsController indexOfObject:newObject1], 3, @"Wrong order of object after insertion");
    XCTAssertEqual([fetchedResultsController indexOfObject:newObject0],  0, @"Wrong order of object after insertion");
    XCTAssertEqual([fetchedResultsController indexOfObject:newObject4], 4, @"Wrong order of object after insertion");
    
    NSLog(@"%@", [fetchedResultsController arrangedObjects]);
}

#pragma mark - Arranged Objects

- (void) testArrangedObjectSortDescriptors
{
    // Inserting a new object inside the managedObjectContext
    Note *newObject = [NSEntityDescription insertNewObjectForEntityForName:@"Note" inManagedObjectContext:self.managedObjectContext];
    newObject.order = @1;
    
    // Inserting a new object inside the managedObjectContext
    Note *newObject2 = [NSEntityDescription insertNewObjectForEntityForName:@"Note" inManagedObjectContext:self.managedObjectContext];
    newObject2.order = @2;

    // Processing changes so the object is no longer listed in the "inserted objects"
    [self.managedObjectContext processPendingChanges];

    // Creating the fetchedResultsController
    MRTFetchedResultsController *fetchedResultsController = [self notesFetchedResultsController];
    [fetchedResultsController performFetch:nil];

    // Setting an inverse order sort descriptors
    NSArray *sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"order" ascending:NO]];
    [fetchedResultsController setSortDescriptors:sortDescriptors];
    
    // Checking correct ordering
    XCTAssertEqual([fetchedResultsController indexOfObject:newObject2], 0, @"Wrong order of object after applying sortDescriptors");
    XCTAssertEqual([fetchedResultsController indexOfObject:newObject],  1, @"Wrong order of object after applying sortDescriptors");

    // Trying to move an object
    newObject2.order = @0;
    
    // Creating a new expectation
    XCTestExpectation *expectation = [self expectationWithDescription:@"Move of object notified"];
    newObject2.moveExpectation = expectation;
    
    // Waiting for all expectations
    [self waitForExpectationsWithTimeout:self.expectationsDefaultTimeout handler:^(NSError *error) {
        if(error) XCTFail(@"Expectation Failed with error: %@", error);
        
        // Checking correct ordering
        XCTAssertEqual([fetchedResultsController indexOfObject:newObject], 0, @"Wrong order of object after applying sortDescriptors");
        XCTAssertEqual([fetchedResultsController indexOfObject:newObject2],  1, @"Wrong order of object after applying sortDescriptors");

        // Checking number and type of events
        [self checkExpectedNumberOfInserts:0 deletes:0 updates:0 moves:1];
        
        // Checking number of delegate calls
        [self checkNumberOfWillDidChangeCalls:1];
        
        // Checking total number of object in the controller
        XCTAssertEqual([fetchedResultsController count], 2, @"Number of object in the fetchedResultsController doesn't match");
    }];

}

- (void) testArrangedObjectSortDescriptorsRemoval
{
    // Inserting a new object inside the managedObjectContext
    Note *newObject = [NSEntityDescription insertNewObjectForEntityForName:@"Note" inManagedObjectContext:self.managedObjectContext];
    newObject.order = @1;
    
    // Inserting a new object inside the managedObjectContext
    Note *newObject2 = [NSEntityDescription insertNewObjectForEntityForName:@"Note" inManagedObjectContext:self.managedObjectContext];
    newObject2.order = @2;
    
    // Creating the fetchedResultsController
    MRTFetchedResultsController *fetchedResultsController = [self notesFetchedResultsController];
    [fetchedResultsController performFetch:nil];
    
    // Setting an inverse order sort descriptors
    NSArray *sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"order" ascending:NO]];
    [fetchedResultsController setSortDescriptors:sortDescriptors];
    
    // Removing sort descriptor
    [fetchedResultsController setSortDescriptors:nil];
    
    // Checking correct ordering
    XCTAssertEqual([fetchedResultsController indexOfObject:newObject], 0, @"Wrong order of object after removing sortDescriptors");
    XCTAssertEqual([fetchedResultsController indexOfObject:newObject2],  1, @"Wrong order of object after removing sortDescriptors");
}


- (void) testArrangedObjectFilterPredicate
{
    // Inserting a new object inside the managedObjectContext
    Note *newObject = [NSEntityDescription insertNewObjectForEntityForName:@"Note" inManagedObjectContext:self.managedObjectContext];
    newObject.order = @1;
    
    // Inserting a new object inside the managedObjectContext
    Note *newObject2 = [NSEntityDescription insertNewObjectForEntityForName:@"Note" inManagedObjectContext:self.managedObjectContext];
    newObject2.order = @2;
 
    // Inserting a new object inside the managedObjectContext
    Note *newObject3 = [NSEntityDescription insertNewObjectForEntityForName:@"Note" inManagedObjectContext:self.managedObjectContext];
    newObject3.order = @3;
    
    // Processing changes so the object is no longer listed in the "inserted objects"
    [self.managedObjectContext processPendingChanges];

    // Creating the fetchedResultsController
    MRTFetchedResultsController *fetchedResultsController = [self notesFetchedResultsController];
    [fetchedResultsController performFetch:nil];

    // Creating and applying a predicate
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"order >= %@", @2];
    [fetchedResultsController setFilterPredicate:predicate];
    
    // Checking total number of object in the controller
    XCTAssertEqual([fetchedResultsController count], 2, @"Number of object in the fetchedResultsController doesn't match");

    // Checking correct ordering
    XCTAssertEqual([fetchedResultsController indexOfObject:newObject2],  0, @"Wrong order of object after applying filter predicate");
    XCTAssertEqual([fetchedResultsController indexOfObject:newObject3],  1, @"Wrong order of object after applying filter predicate");

    // Updating the order so the object is going back into the controller
    newObject.order = @5;
    
    // Creating a new expectation
    XCTestExpectation *expectation = [self expectationWithDescription:@"Insert of object notified"];
    newObject.insertExpectation = expectation;

    // Waiting for all expectations
    [self waitForExpectationsWithTimeout:self.expectationsDefaultTimeout handler:^(NSError *error) {
        if(error) XCTFail(@"Expectation Failed with error: %@", error);
        
        // Checking correct ordering
        XCTAssertEqual([fetchedResultsController indexOfObject:newObject2],  0, @"Wrong order of object after applying filter predicate");
        XCTAssertEqual([fetchedResultsController indexOfObject:newObject3],  1, @"Wrong order of object after applying filter predicate");
        XCTAssertEqual([fetchedResultsController indexOfObject:newObject],  2, @"Wrong order of object after applying filter predicate");
        
        // Checking total number of object in the controller
        XCTAssertEqual([fetchedResultsController count], 3, @"Number of object in the fetchedResultsController doesn't match");
    }];
}

- (void) testArrangedObjectFilterPredicateRemoval
{
    // Inserting a new object inside the managedObjectContext
    Note *newObject = [NSEntityDescription insertNewObjectForEntityForName:@"Note" inManagedObjectContext:self.managedObjectContext];
    newObject.order = @1;
    
    // Inserting a new object inside the managedObjectContext
    Note *newObject2 = [NSEntityDescription insertNewObjectForEntityForName:@"Note" inManagedObjectContext:self.managedObjectContext];
    newObject2.order = @2;
    
    // Inserting a new object inside the managedObjectContext
    Note *newObject3 = [NSEntityDescription insertNewObjectForEntityForName:@"Note" inManagedObjectContext:self.managedObjectContext];
    newObject3.order = @3;
    
    // Creating the fetchedResultsController
    MRTFetchedResultsController *fetchedResultsController = [self notesFetchedResultsController];
    [fetchedResultsController performFetch:nil];
    
    // Creating and applying a predicate
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"order >= %@", @2];
    [fetchedResultsController setFilterPredicate:predicate];

    // Removing predicate
    [fetchedResultsController setFilterPredicate:nil];

    // Checking total number of object in the controller
    XCTAssertEqual([fetchedResultsController count], 3, @"Number of object in the fetchedResultsController doesn't match");

    // Checking correct ordering
    XCTAssertEqual([fetchedResultsController indexOfObject:newObject],  0, @"Wrong order of object after removing filter predicate");
    XCTAssertEqual([fetchedResultsController indexOfObject:newObject2],  1, @"Wrong order of object after removing filter predicate");
    XCTAssertEqual([fetchedResultsController indexOfObject:newObject3],  2, @"Wrong order of object after removing filter predicate");
}

#pragma mark - MRTFetchedResultsController utils

- (MRTFetchedResultsController *) notesFetchedResultsController
{
    return [self notesFetchedResultsControllerWithPredicate:nil];
}

- (MRTFetchedResultsController *) untrashedNotesFetchedResultsController
{
    return [self notesFetchedResultsControllerWithPredicate:[NSPredicate predicateWithFormat:@"trashed == NO"]];
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


#pragma mark - Utils

- (void) checkExpectedNumberOfInserts: (NSUInteger) inserts deletes: (NSUInteger) deletes updates: (NSUInteger) updates moves: (NSUInteger) moves
{
    XCTAssertEqual(self.numberOfInserts, inserts, @"Number of inserts doesn't match");
    XCTAssertEqual(self.numberOfDeletes, deletes, @"Number of deletes doesn't match");
    XCTAssertEqual(self.numberOfUpdates, updates, @"Number of updates doesn't match");
    XCTAssertEqual(self.numberOfMoves,   moves  , @"Number of moves doesn't match");
}

- (void) checkNumberOfWillDidChangeCalls: (NSUInteger) numberOfCalls
{
    XCTAssertEqual(self.numberOfWillChangeContext, numberOfCalls, @"Number of willChangeContext doesn't match");
    XCTAssertEqual(self.numberOfDidChangeContext, numberOfCalls, @"Number of didChangeContext doesn't match");
}

#pragma mark - MRTFetchedResultsControllerDelegate

- (void)controllerWillChangeContent:(MRTFetchedResultsController *)controller
{
    self.numberOfWillChangeContext++;
}

- (void)controllerDidChangeContent:(MRTFetchedResultsController *)controller
{
    self.numberOfDidChangeContext++;
}


- (void)controller:(MRTFetchedResultsController *)controller didChangeObject:(id)anObject atIndex:(NSUInteger)index forChangeType:(MRTFetchedResultsChangeType)type newIndex:(NSUInteger)newIndex
{
    //NSLog(@"did change object %@ type %lu", anObject, type);
    NSLog(@"did change index %lu new index %lu", (unsigned long)index, (unsigned long)newIndex);

    switch (type) {
        case MRTFetchedResultsChangeDelete:
            self.numberOfDeletes++;
            [[anObject deleteExpectation] fulfill];
            break;
        case MRTFetchedResultsChangeInsert:
            self.numberOfInserts++;
            [[anObject insertExpectation] fulfill];
            break;
        case MRTFetchedResultsChangeUpdate:
            self.numberOfUpdates++;
            [[anObject updateExpectation] fulfill];
            break;
        case MRTFetchedResultsChangeMove:
            self.numberOfMoves++;
            [[anObject moveExpectation] fulfill];
            break;
        default:
            break;
    }
}

@end
