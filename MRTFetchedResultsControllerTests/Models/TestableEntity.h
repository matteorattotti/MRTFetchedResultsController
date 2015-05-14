//
//  TestableEntity.h
//  MRTFetchedResultsController
//
//  Created by Matteo Rattotti on 14/05/15.
//
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>
#import <XCTest/XCTest.h>

@interface TestableEntity : NSManagedObject

@property (nonatomic, strong) XCTestExpectation * insertExpectation;
@property (nonatomic, strong) XCTestExpectation * deleteExpectation;
@property (nonatomic, strong) XCTestExpectation * updateExpectation;
@property (nonatomic, strong) XCTestExpectation * moveExpectation;

@end
