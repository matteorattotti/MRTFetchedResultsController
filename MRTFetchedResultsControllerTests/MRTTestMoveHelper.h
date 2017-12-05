//
//  MRTTestMoveHelper.h
//  MRTFetchedResultsController
//
//  Created by Matteo Rattotti on 30/06/2017.
//
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>
#import "MRTFetchedResultsController.h"
#import "Note.h"

@interface MRTTestMoveHelper : NSObject <MRTFetchedResultsControllerDelegate>

- (instancetype)initWithTest: (XCTestCase *) testCase
                initialItems: (NSArray *) initialItems
                 finalOrders: (NSArray *) finalOrders;


@property (strong) NSManagedObjectContext *managedObjectContext;

@property (strong) NSMutableArray *targetArray;

@property (strong) NSArray *finalOrders;

@property (strong) XCTestExpectation *didChangeContentExpectation;

@property (strong) MRTFetchedResultsController *fetchedResultsController;

@property (strong) NSMutableString *movementHistory;

@property (nonatomic) NSUInteger numberOfMoves;

@property (nonatomic) BOOL logMoves;


- (void) performMoves;

- (BOOL) isFinalOrderCorrect;

@end
