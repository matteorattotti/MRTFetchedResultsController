//
//  Note.h
//  MRTFetchedResultsController
//
//  Created by Matteo Rattotti on 14/05/15.
//
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>
#import "TestableEntity.h"


@interface Note : TestableEntity

@property (nonatomic, retain) NSNumber * pinned;
@property (nonatomic, retain) NSNumber * conflicted;
@property (nonatomic, retain) NSString * text;
@property (nonatomic, retain) NSNumber * order;
@property (nonatomic, retain) NSNumber * trashed;

@end
