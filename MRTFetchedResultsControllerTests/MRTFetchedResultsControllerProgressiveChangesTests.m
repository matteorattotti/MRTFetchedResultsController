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
#import "MRTTestMoveHelper.h"
#import "NSArray+Permutation.h"
#import "NSSet+Combinatorics.h"

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

- (void) testMovesSwap
{
    /*
     abc -> acb
     */
    
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
    
    // Creating the fetchedResultsController
    MRTFetchedResultsController *fetchedResultsController = [self notesFetchedResultsController];
    [fetchedResultsController performFetch:nil];
    
    newObject2.order = @2;
    newObject3.order = @1;
    
    // Waiting for the did change expectation
    [self waitForExpectationsWithTimeout:self.expectationsDefaultTimeout handler:^(NSError *error) {
        if(error) XCTFail(@"Expectation Failed with error: %@", error);
        
        XCTAssertTrue([fetchedResultsController.arrangedObjects isEqualToArray:self.targetArray]);
    }];
}


- (void) testMovesSimmetricSwap
{
    /*
     abc -> cba
     */
    
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

- (void) testMovesAfter
{
    /*
     abc -> bca
     */

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
    /*
     abc -> cab
     */

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
    /*
     abc -> bac
     */

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

- (void) testMovesDoubleHop
{
    /*
     abc -> cba
     */
    
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

- (void) testMovesDoubleHop2
{
    /*
     abc -> cba
     */
    
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
    
    // Creating the fetchedResultsController
    MRTFetchedResultsController *fetchedResultsController = [self notesFetchedResultsController];
    [fetchedResultsController performFetch:nil];

    newObject.order = @2;
    newObject2.order = @3;
    newObject3.order = @1;
    
    // Waiting for the did change expectation
    [self waitForExpectationsWithTimeout:self.expectationsDefaultTimeout handler:^(NSError *error) {
        if(error) XCTFail(@"Expectation Failed with error: %@", error);
        
        XCTAssertTrue([fetchedResultsController.arrangedObjects isEqualToArray:self.targetArray]);
    }];
}

- (void) testMovesDoubleHopReverse
{
    /*
     abc -> bca
     */
    
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
    
    // Creating the fetchedResultsController
    MRTFetchedResultsController *fetchedResultsController = [self notesFetchedResultsController];
    [fetchedResultsController performFetch:nil];
    
    newObject2.order = @1;
    newObject3.order = @2;
    
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


- (void) testManyMoves2
{
    /*
     abcdef -> cebdaf
     */
    
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

- (void) testManyMoves3
{
    /*
     abcdef -> cbafed
     */
    
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
    
    // Creating the fetchedResultsController
    MRTFetchedResultsController *fetchedResultsController = [self notesFetchedResultsController];
    [fetchedResultsController performFetch:nil];
    
    newObject.order = @3;
    newObject2.order = @2;
    newObject3.order = @1;
    newObject4.order = @6;
    newObject5.order = @5;
    newObject6.order = @4;
    
    // Waiting for the did change expectation
    [self waitForExpectationsWithTimeout:self.expectationsDefaultTimeout handler:^(NSError *error) {
        if(error) XCTFail(@"Expectation Failed with error: %@", error);
        
        XCTAssertTrue([fetchedResultsController.arrangedObjects isEqualToArray:self.targetArray]);
    }];
}


- (void) testManyMoves4
{
    /*
     abcdef -> bcdfae
     */
    
    // Inserting a new object inside the managedObjectContext
    Note *newObject = [NSEntityDescription insertNewObjectForEntityForName:@"Note" inManagedObjectContext:self.managedObjectContext];
    newObject.order = @1;
    newObject.text = @"a";
    
//    // Inserting a new object inside the managedObjectContext
//    Note *newObject2 = [NSEntityDescription insertNewObjectForEntityForName:@"Note" inManagedObjectContext:self.managedObjectContext];
//    newObject2.order = @10;
//    newObject2.text = @"b";
//    
//    // Inserting a new object inside the managedObjectContext
//    Note *newObject3 = [NSEntityDescription insertNewObjectForEntityForName:@"Note" inManagedObjectContext:self.managedObjectContext];
//    newObject3.order = @100;
//    newObject3.text = @"c";
    
    // Inserting a new object inside the managedObjectContext
    Note *newObject4 = [NSEntityDescription insertNewObjectForEntityForName:@"Note" inManagedObjectContext:self.managedObjectContext];
    newObject4.order = @1000;
    newObject4.text = @"b";
    
    // Inserting a new object inside the managedObjectContext
    Note *newObject5 = [NSEntityDescription insertNewObjectForEntityForName:@"Note" inManagedObjectContext:self.managedObjectContext];
    newObject5.order = @10000;
    newObject5.text = @"c";
    
    
    // Inserting a new object inside the managedObjectContext
    Note *newObject6 = [NSEntityDescription insertNewObjectForEntityForName:@"Note" inManagedObjectContext:self.managedObjectContext];
    newObject6.order = @100000;
    newObject6.text = @"d";
    
    [self.targetArray addObjectsFromArray:@[newObject, /*newObject2, newObject3, */newObject4, newObject5, newObject6]];
    
    [self.managedObjectContext processPendingChanges];
    
    // Creating the fetchedResultsController
    MRTFetchedResultsController *fetchedResultsController = [self notesFetchedResultsController];
    [fetchedResultsController performFetch:nil];
    
    newObject.order = @9999;
    newObject6.order = @1001;
    
    // Waiting for the did change expectation
    [self waitForExpectationsWithTimeout:self.expectationsDefaultTimeout handler:^(NSError *error) {
        if(error) XCTFail(@"Expectation Failed with error: %@", error);
        
        XCTAssertTrue([fetchedResultsController.arrangedObjects isEqualToArray:self.targetArray]);
    }];
}


- (void) testManyMoves5
{
    /*
     abcd -> bcad
     */
    
    // Inserting a new object inside the managedObjectContext
    Note *newObject = [NSEntityDescription insertNewObjectForEntityForName:@"Note" inManagedObjectContext:self.managedObjectContext];
    newObject.order = @1;
    newObject.text = @"a";
    
    // Inserting a new object inside the managedObjectContext
    Note *newObject2 = [NSEntityDescription insertNewObjectForEntityForName:@"Note" inManagedObjectContext:self.managedObjectContext];
    newObject2.order = @10;
    newObject2.text = @"b";
    
    // Inserting a new object inside the managedObjectContext
    Note *newObject3 = [NSEntityDescription insertNewObjectForEntityForName:@"Note" inManagedObjectContext:self.managedObjectContext];
    newObject3.order = @100;
    newObject3.text = @"c";
    
    // Inserting a new object inside the managedObjectContext
    Note *newObject4 = [NSEntityDescription insertNewObjectForEntityForName:@"Note" inManagedObjectContext:self.managedObjectContext];
    newObject4.order = @1000;
    newObject4.text = @"d";
    
    [self.targetArray addObjectsFromArray:@[newObject, newObject2, newObject3, newObject4]];
    
    [self.managedObjectContext processPendingChanges];
    
    // Creating the fetchedResultsController
    MRTFetchedResultsController *fetchedResultsController = [self notesFetchedResultsController];
    [fetchedResultsController performFetch:nil];
    
    newObject.order = @999;
    
    // Waiting for the did change expectation
    [self waitForExpectationsWithTimeout:self.expectationsDefaultTimeout handler:^(NSError *error) {
        if(error) XCTFail(@"Expectation Failed with error: %@", error);
        
        XCTAssertTrue([fetchedResultsController.arrangedObjects isEqualToArray:self.targetArray]);
    }];
}

- (void) testManyMoves6
{
    /*
     abc -> cba
     */

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
    newObject3.order = @3;
    
    [self.targetArray addObjectsFromArray:@[newObject, newObject2, newObject3]];    
    
    // Creating the fetchedResultsController
    MRTFetchedResultsController *fetchedResultsController = [self notesFetchedResultsController];
    [fetchedResultsController performFetch:nil];
    
    newObject2.order = @(-1);
    newObject3.order = @(-2);
    
    // Waiting for the did change expectation
    [self waitForExpectationsWithTimeout:self.expectationsDefaultTimeout handler:^(NSError *error) {
        if(error) XCTFail(@"Expectation Failed with error: %@", error);
        
        XCTAssertTrue([fetchedResultsController.arrangedObjects isEqualToArray:self.targetArray]);
    }];
}

/*- (void) testAllMoves
{
    [self.didChangeContentExpectation fulfill];

    NSArray *items = @[@"a", @"b", @"c"];
    NSArray *order = @[@(0), @(1), @(2), @(3), @(-1), @(-2), @(-3)];

    //NSArray *items = @[@"a", @"b", @"c", @"d"];
    //NSArray *order = @[@(0), @(1), @(2), @(3), @(-1), @(-2), @(-3), @(-4)];

    //NSArray *items = @[@"a", @"b", @"c", @"d", @"e"];
    //NSArray *order = @[@(0), @(1), @(2), @(3), @(4), @(-1), @(-2), @(-3), @(-4), @(-5)];

    //NSArray *items = @[@"a", @"b", @"c", @"d", @"e", @"f"];
    //NSArray *order = @[@1, @2, @3, @4, @5, @6];

    //NSArray *items = @[@"a", @"b", @"c", @"d", @"e", @"f", @"g"];
    //NSArray *order = @[@0, @1, @2, @3, @4, @5, @6];

    //NSArray *items = @[@"a", @"b", @"c", @"d", @"e", @"f", @"g", @"h"];
    //NSArray *order = @[@1, @2, @3, @4, @5, @6, @7, @8];

    // Preparing order permutations
    NSSet *allOrderSet = [NSSet setWithArray:order];
    allOrderSet = [allOrderSet variationsOfSize:items.count];
    
    // Preparing in memory db
    NSMutableArray *helpers = [NSMutableArray array];
    for (NSArray *finalOrder in allOrderSet) {
        if ([[finalOrder subarrayWithRange:NSMakeRange(0, items.count)] isEqualToArray:[order subarrayWithRange:NSMakeRange(0, items.count)]]) {
            continue;
        }
        MRTTestMoveHelper *helper = [[MRTTestMoveHelper alloc] initWithTest:self initialItems:items finalOrders:finalOrder];
        [helpers addObject:helper];
    }
    
    // Performing moves
    [helpers makeObjectsPerformSelector:@selector(performMoves)];
    
    NSUInteger successes = 0;
    NSUInteger failures = 0;
    
    for (MRTTestMoveHelper *helper in helpers) {
        if (![helper isFinalOrderCorrect]) {
            NSLog(@"Failed %@ \n---------\n%@\n---------\n",helper, helper.movementHistory);
            failures++;
        }
        else {
            successes++;
        }
    }
    
    [self waitForExpectationsWithTimeout:1 handler:^(NSError *error) {
        XCTAssertTrue(failures == 0);
        NSLog(@"Successes %lu Failures %lu",(unsigned long) successes, (unsigned long)failures);
    }];
}*/

- (void) testPerformance
{
    NSMutableArray *items = [NSMutableArray array];
    NSMutableArray *orders = [NSMutableArray array];
    
    NSUInteger numberOfMoves = 10000;
    for (int i = 0; i<= numberOfMoves;i++) {
        [items addObject:@(i).stringValue];
        [orders addObject:@(numberOfMoves-i)];
    }
    
    MRTTestMoveHelper *helper = [[MRTTestMoveHelper alloc] initWithTest:self initialItems:items finalOrders:orders];
    [helper performMoves];

    [self.didChangeContentExpectation fulfill];

    [self waitForExpectationsWithTimeout:1 handler:^(NSError *error) {
        XCTAssertTrue([helper isFinalOrderCorrect] == YES);
        XCTAssertTrue([helper numberOfMoves] == numberOfMoves);
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


- (void) testInsertMoveDeleteUpdate
{
    Note *newObject = [NSEntityDescription insertNewObjectForEntityForName:@"Note" inManagedObjectContext:self.managedObjectContext];
    newObject.order = @1;
    
    Note *newObject2 = [NSEntityDescription insertNewObjectForEntityForName:@"Note" inManagedObjectContext:self.managedObjectContext];
    newObject2.order = @2;
    
    Note *newObject3 = [NSEntityDescription insertNewObjectForEntityForName:@"Note" inManagedObjectContext:self.managedObjectContext];
    newObject3.order = @3;
    
    Note *newObject4 = [NSEntityDescription insertNewObjectForEntityForName:@"Note" inManagedObjectContext:self.managedObjectContext];
    newObject4.order = @4;
    

    
    [self.targetArray addObjectsFromArray:@[newObject, newObject2, newObject3, newObject4]];
    
    // Creating the fetchedResultsController
    MRTFetchedResultsController *fetchedResultsController = [self notesFetchedResultsController];
    [fetchedResultsController performFetch:nil];
    
    
    // Inserting at the top
    Note *newObject5 = [NSEntityDescription insertNewObjectForEntityForName:@"Note" inManagedObjectContext:self.managedObjectContext];
    newObject5.order = @0;

    // Moving something at the end
    newObject2.order = @5;
    
    // Deleting something
    [self.managedObjectContext deleteObject:newObject];
    
    // Updating
    newObject3.text = @"Updated text";
    
    // Waiting for the did change expectation
    [self waitForExpectationsWithTimeout:self.expectationsDefaultTimeout handler:^(NSError *error) {
        if(error) XCTFail(@"Expectation Failed with error: %@", error);
        
        XCTAssertTrue([fetchedResultsController.arrangedObjects isEqualToArray:self.targetArray]);
    }];
}


- (void) testMoveRefresh
{
    Note *newObject = [NSEntityDescription insertNewObjectForEntityForName:@"Note" inManagedObjectContext:self.managedObjectContext];
    newObject.order = @1;
    newObject.text = @"A";
    
    Note *newObject2 = [NSEntityDescription insertNewObjectForEntityForName:@"Note" inManagedObjectContext:self.managedObjectContext];
    newObject2.order = @2;
    newObject2.text = @"B";
    
    Note *newObject3 = [NSEntityDescription insertNewObjectForEntityForName:@"Note" inManagedObjectContext:self.managedObjectContext];
    newObject3.order = @3;
    newObject3.text = @"C";

    Note *newObject4 = [NSEntityDescription insertNewObjectForEntityForName:@"Note" inManagedObjectContext:self.managedObjectContext];
    newObject4.order = @4;
    newObject4.text = @"D";
    
    [self.targetArray addObjectsFromArray:@[newObject, newObject2, newObject3, newObject4]];
    
    // Creating the fetchedResultsController
    MRTFetchedResultsController *fetchedResultsController = [self notesFetchedResultsController];
    [fetchedResultsController performFetch:nil];

    newObject4.order = @0;
    [self.managedObjectContext refreshObject:newObject4 mergeChanges:YES];
    
    // Waiting for the did change expectation
    [self waitForExpectationsWithTimeout:self.expectationsDefaultTimeout handler:^(NSError *error) {
        if(error) XCTFail(@"Expectation Failed with error: %@", error);
        
        XCTAssertTrue([fetchedResultsController.arrangedObjects isEqualToArray:self.targetArray]);
    }];

}

- (void)testInsertRefresh
{
    // Creating the fetchedResultsController
    MRTFetchedResultsController *fetchedResultsController = [self notesFetchedResultsController];
    [fetchedResultsController performFetch:nil];

    Note *newObject = [NSEntityDescription insertNewObjectForEntityForName:@"Note" inManagedObjectContext:self.managedObjectContext];
    newObject.order = @1;
    newObject.text = @"A";
    
    [self.managedObjectContext refreshObject:newObject mergeChanges:YES];
        
    // Waiting for the did change expectation
    [self waitForExpectationsWithTimeout:self.expectationsDefaultTimeout handler:^(NSError *error) {
        if(error) XCTFail(@"Expectation Failed with error: %@", error);
        
        XCTAssertTrue([fetchedResultsController.arrangedObjects isEqualToArray:self.targetArray]);
    }];
    
}

- (void)testUpdateThatActuallyIsAMove
{
    // Inserting a new object inside the managedObjectContext
    Note *newObject = [NSEntityDescription insertNewObjectForEntityForName:@"Note" inManagedObjectContext:self.managedObjectContext];
    newObject.order = @0;
    newObject.pinned = @1;
    newObject.text = @"Pinned";
    
    // Inserting a new object inside the managedObjectContext
    Note *newObject2 = [NSEntityDescription insertNewObjectForEntityForName:@"Note" inManagedObjectContext:self.managedObjectContext];
    newObject2.order = @1;
    newObject2.conflicted = @1;
    newObject2.text = @"Conflict 1";
    
    // Inserting a new object inside the managedObjectContext
    Note *newObject3 = [NSEntityDescription insertNewObjectForEntityForName:@"Note" inManagedObjectContext:self.managedObjectContext];
    newObject3.order = @2;
    newObject3.conflicted = @1;
    newObject3.text = @"Conflict 2";
    
    [self.targetArray addObjectsFromArray:@[newObject2, newObject3, newObject]];

    // Creating the fetchedResultsController
    NSSortDescriptor *conflictedSortDescriptor = [NSSortDescriptor sortDescriptorWithKey:@"conflicted" ascending:NO];
    NSSortDescriptor *pinnedSort = [[NSSortDescriptor alloc] initWithKey:@"pinned" ascending:NO];
    NSSortDescriptor *order = [[NSSortDescriptor alloc] initWithKey:@"order" ascending:YES];
    
    MRTFetchedResultsController *fetchedResultsController = [self notesFetchedResultsController];
    
    [fetchedResultsController setSortDescriptors: @[conflictedSortDescriptor, pinnedSort, order]];
    [fetchedResultsController performFetch:nil];

    // Deleting the first object
    [self.managedObjectContext deleteObject:newObject2];
    newObject3.conflicted = nil;

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


- (void)controller:(MRTFetchedResultsController *)controller
   didChangeObject:(id)anObject
           atIndex:(NSUInteger)index
  progressiveIndex:(NSUInteger) progressiveIndex
     forChangeType:(MRTFetchedResultsChangeType)changeType
forProgressiveChangeType:(MRTFetchedResultsChangeType)progressiveChangeType
          newIndex:(NSUInteger)newIndex
newProgressiveIndex:(NSUInteger) newProgressiveIndex;
{
    switch (progressiveChangeType) {
        case MRTFetchedResultsChangeDelete:
            NSLog(@"deleted %@ at %lu", [anObject text], progressiveIndex);
            [self.targetArray removeObjectAtIndex:progressiveIndex];
            break;
        case MRTFetchedResultsChangeInsert:
            NSLog(@"inserted %@ at %lu", [anObject text], newProgressiveIndex);
            [self.targetArray insertObject:anObject atIndex:newProgressiveIndex];
            break;
        case MRTFetchedResultsChangeUpdate:
            NSLog(@"update %@ at %lu", [anObject text], progressiveIndex);
            break;
        case MRTFetchedResultsChangeMove:
            NSLog(@"move %@ from %lu in %lu", [anObject text], (unsigned long)progressiveIndex, (unsigned long)newProgressiveIndex);
            [self.targetArray removeObjectAtIndex:progressiveIndex];
            [self.targetArray insertObject:anObject atIndex:newProgressiveIndex];
            NSLog(@"target %@", self.targetArray);
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
