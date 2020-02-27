//
//  MRTFetchedResultsControllerCallbackOrderTests.m
//  MRTFetchedResultsControllerTests
//
//  Created by Konstantin Victorovich Erokhin on 27/02/2020.
//

#import <XCTest/XCTest.h>
#import <CoreData/CoreData.h>

#import "Note.h"
#import "MRTFetchedResultsController.h"


@interface MRTFetchedResultsControllerCallbackOrderBaseTests : XCTestCase <MRTFetchedResultsControllerDelegate>

@property (strong) NSManagedObjectContext *managedObjectContext;
@property (strong) NSManagedObjectContext *privateManagedObjectContext;

@property (nonatomic) NSUInteger numberOfCallsWillBeginChanging;
@property (nonatomic) NSUInteger numberOfCallsDidChangeWithChanges;
@property (nonatomic) NSUInteger numberOfCallsDidChangeWithProgressiveChanges;
@property (nonatomic) NSUInteger numberOfCallsDidEndChanging;
@property (nonatomic) NSUInteger numberOfCallsDidEndChangingWithChanges;
@property (nonatomic) NSUInteger numberOfCallsDidEndChangingWithProgressiveChanges;

@property (strong) NSMutableArray *targetArray;

@property (nonatomic, strong) XCTestExpectation * expectation;
@property (nonatomic) CGFloat expectationsDefaultTimeout;

- (void)testAnyOperationWithExpectationHandler:(XCWaitCompletionHandler)expectationHandler;

@end

@implementation MRTFetchedResultsControllerCallbackOrderBaseTests


- (void)setUp
{
    [super setUp];

    [self setupCoreData];
    
    self.targetArray = [NSMutableArray array];
    
    self.expectationsDefaultTimeout = 0.1;
    
    // will callbacks
    self.numberOfCallsWillBeginChanging = 0;
    // change callbacks
    self.numberOfCallsDidChangeWithChanges = 0;
    self.numberOfCallsDidChangeWithProgressiveChanges = 0;
    // did callbacks
    self.numberOfCallsDidEndChanging = 0;
    self.numberOfCallsDidEndChangingWithChanges = 0;
    self.numberOfCallsDidEndChangingWithProgressiveChanges = 0;
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

- (void)testAnyOperationWithExpectationHandler:(XCWaitCompletionHandler)expectationHandler
{
    // Creating the fetchedResultsController
    MRTFetchedResultsController *fetchedResultsController = [self notesFetchedResultsController];
    [fetchedResultsController performFetch:nil];
    
    // Inserting a new object inside the managedObjectContext (could be any operation for this test)
    [NSEntityDescription insertNewObjectForEntityForName:@"Note" inManagedObjectContext:self.managedObjectContext];
    
    // Creating a new expectation
    XCTestExpectation *expectation = [self expectationWithDescription:@"Insertion of new object notified"];
    expectation.expectedFulfillmentCount = 1;
    self.expectation = expectation;
    
    // Waiting for all expectations
    [self waitForExpectationsWithTimeout:self.expectationsDefaultTimeout handler:expectationHandler];
}

// MRTFetchedResultsController utils

- (MRTFetchedResultsController *)notesFetchedResultsController
{
    // Creating the fetch request
    NSFetchRequest *request = [[NSFetchRequest alloc] init];
    request.entity = [NSEntityDescription entityForName:@"Note" inManagedObjectContext:self.managedObjectContext];
    request.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"order" ascending:YES]];
    
    // Creating the fetchedResultsController
    MRTFetchedResultsController *fetchedResultsController = [[MRTFetchedResultsController alloc] initWithManagedObjectContext:self.managedObjectContext fetchRequest:request];
    fetchedResultsController.delegate = self;
    
    return fetchedResultsController;
}

@end

#pragma mark - Zero Attributes Callback

@interface MRTFetchedResultsControllerCallbackOrderZeroAttributesCallbacksTests : MRTFetchedResultsControllerCallbackOrderBaseTests

@end

@implementation MRTFetchedResultsControllerCallbackOrderZeroAttributesCallbacksTests

- (void)testWillBeginChangingAndDidChangeWithChangesAndDidEndChangingBeingCalled
{
    [self testAnyOperationWithExpectationHandler:^(NSError *error) {
        if(error) XCTFail(@"Expectation Failed with error: %@", error);
        // Checking the number of callbacks
        XCTAssertEqual(self.numberOfCallsWillBeginChanging, 1, @"Number of will callbacks is wrong");
        XCTAssertEqual(self.numberOfCallsDidChangeWithChanges, 1, @"Number of didChange callbacks with only changes is wrong");
        XCTAssertEqual(self.numberOfCallsDidChangeWithProgressiveChanges, 0, @"Number of didChange callbacks with with progressive changes is wrong");
        XCTAssertEqual(self.numberOfCallsDidEndChanging, 1, @"Number of didEndChanging callbacks is wrong");
        XCTAssertEqual(self.numberOfCallsDidEndChangingWithChanges, 0, @"Number of didEndChanging callbacks with only changes is wrong");
        XCTAssertEqual(self.numberOfCallsDidEndChangingWithProgressiveChanges, 0, @"Number of didEndChanging callbacks with progressive changes is wrong");
    }];
}

// MRTFetchedResultsControllerDelegate

- (void)fetchedResultsControllerWillBeginChanging:(MRTFetchedResultsController *)controller
{
    self.numberOfCallsWillBeginChanging++;
}

- (void)fetchedResultsController:(MRTFetchedResultsController *)controller
                       didChange:(MRTFetchedResultsControllerChange *)change
{
    [self.expectation fulfill];
    self.numberOfCallsDidChangeWithChanges++;
}

- (void)fetchedResultsControllerDidEndChanging:(MRTFetchedResultsController *)controller
{
    self.numberOfCallsDidEndChanging++;
}

@end

#pragma mark - One Attribute Callback

@interface MRTFetchedResultsControllerCallbackOrderOneAttributesCallbacksTests : MRTFetchedResultsControllerCallbackOrderBaseTests

@end

@implementation MRTFetchedResultsControllerCallbackOrderOneAttributesCallbacksTests

- (void)testWillBeginChangingAndDidChangeWithProgressiveChangesAndDidEndChangingWithChangesBeingCalled
{
    [self testAnyOperationWithExpectationHandler:^(NSError *error) {
        if(error) XCTFail(@"Expectation Failed with error: %@", error);
        // Checking the number of callbacks
        XCTAssertEqual(self.numberOfCallsWillBeginChanging, 1, @"Number of will callbacks is wrong");
        XCTAssertEqual(self.numberOfCallsDidChangeWithChanges, 0, @"Number of didChange callbacks with only changes is wrong");
        XCTAssertEqual(self.numberOfCallsDidChangeWithProgressiveChanges, 1, @"Number of didChange callbacks with with progressive changes is wrong");
        XCTAssertEqual(self.numberOfCallsDidEndChanging, 0, @"Number of didEndChanging callbacks is wrong");
        XCTAssertEqual(self.numberOfCallsDidEndChangingWithChanges, 1, @"Number of didEndChanging callbacks with only changes is wrong");
        XCTAssertEqual(self.numberOfCallsDidEndChangingWithProgressiveChanges, 0, @"Number of didEndChanging callbacks with progressive changes is wrong");
    }];
}

// MRTFetchedResultsControllerDelegate

- (void)fetchedResultsControllerWillBeginChanging:(MRTFetchedResultsController *)controller
{
    self.numberOfCallsWillBeginChanging++;
}

- (void)fetchedResultsController:(MRTFetchedResultsController *)controller
                       didChange:(MRTFetchedResultsControllerChange *)change
{
    [self.expectation fulfill];
    self.numberOfCallsDidChangeWithChanges++;
}

- (void)fetchedResultsController:(MRTFetchedResultsController *)controller
                       didChange:(MRTFetchedResultsControllerChange *)change
               progressiveChange:(MRTFetchedResultsControllerChange *)progressiveChange
{
    [self.expectation fulfill];
    self.numberOfCallsDidChangeWithProgressiveChanges++;
}

- (void)fetchedResultsControllerDidEndChanging:(MRTFetchedResultsController *)controller
{
    self.numberOfCallsDidEndChanging++;
}

- (void)fetchedResultsController:(MRTFetchedResultsController *)controller
                  didEndChanging:(NSArray<MRTFetchedResultsControllerChange *> *)changes
{
    self.numberOfCallsDidEndChangingWithChanges++;
}

@end

#pragma mark - Two Attribute Callback

@interface MRTFetchedResultsControllerCallbackOrderTwoAttributesCallbacksTests : MRTFetchedResultsControllerCallbackOrderBaseTests

@end

@implementation MRTFetchedResultsControllerCallbackOrderTwoAttributesCallbacksTests

- (void)testWillBeginChangingAndDidChangeWithProgressiveChangesAndDidEndChangingWithProgressiveChangesBeingCalled
{
    [self testAnyOperationWithExpectationHandler:^(NSError *error) {
        if(error) XCTFail(@"Expectation Failed with error: %@", error);
        // Checking the number of callbacks
        XCTAssertEqual(self.numberOfCallsWillBeginChanging, 1, @"Number of will callbacks is wrong");
        XCTAssertEqual(self.numberOfCallsDidChangeWithChanges, 0, @"Number of didChange callbacks with only changes is wrong");
        XCTAssertEqual(self.numberOfCallsDidChangeWithProgressiveChanges, 1, @"Number of didChange callbacks with with progressive changes is wrong");
        XCTAssertEqual(self.numberOfCallsDidEndChanging, 0, @"Number of didEndChanging callbacks is wrong");
        XCTAssertEqual(self.numberOfCallsDidEndChangingWithChanges, 0, @"Number of didEndChanging callbacks with only changes is wrong");
        XCTAssertEqual(self.numberOfCallsDidEndChangingWithProgressiveChanges, 1, @"Number of didEndChanging callbacks with progressive changes is wrong");
    }];
}

// MRTFetchedResultsControllerDelegate

- (void)fetchedResultsControllerWillBeginChanging:(MRTFetchedResultsController *)controller
{
    self.numberOfCallsWillBeginChanging++;
}

- (void)fetchedResultsController:(MRTFetchedResultsController *)controller
                       didChange:(MRTFetchedResultsControllerChange *)change
{
    [self.expectation fulfill];
    self.numberOfCallsDidChangeWithChanges++;
}

- (void)fetchedResultsController:(MRTFetchedResultsController *)controller
                       didChange:(MRTFetchedResultsControllerChange *)change
               progressiveChange:(MRTFetchedResultsControllerChange *)progressiveChange
{
    [self.expectation fulfill];
    self.numberOfCallsDidChangeWithProgressiveChanges++;
}

- (void)fetchedResultsControllerDidEndChanging:(MRTFetchedResultsController *)controller
{
    self.numberOfCallsDidEndChanging++;
}

- (void)fetchedResultsController:(MRTFetchedResultsController *)controller
                  didEndChanging:(NSArray<MRTFetchedResultsControllerChange *> *)changes
{
    self.numberOfCallsDidEndChangingWithChanges++;
}

- (void)fetchedResultsController:(MRTFetchedResultsController *)controller
                  didEndChanging:(NSArray<MRTFetchedResultsControllerChange *> *)changes
              progressiveChanges:(NSArray<MRTFetchedResultsControllerChange *> *)progressiveChanges
{
    self.numberOfCallsDidEndChangingWithProgressiveChanges++;
}

@end
