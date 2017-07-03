//
//  NSArray+Permutation.m
//  MRTFetchedResultsController
//
//  Created by Matteo Rattotti on 30/06/2017.
//
//

#import "NSArray+Permutation.h"

#define MAX_PERMUTATION_COUNT   20000

NSInteger *pc_next_permutation(NSInteger *perm, const NSInteger size);
NSInteger *pc_next_permutation(NSInteger *perm, const NSInteger size)
{
    // slide down the array looking for where we're smaller than the next guy
    NSInteger pos1;
    for (pos1 = size - 1; perm[pos1] >= perm[pos1 + 1] && pos1 > -1; --pos1);
    
    // if this doesn't occur, we've finished our permutations
    // the array is reversed: (1, 2, 3, 4) => (4, 3, 2, 1)
    if (pos1 == -1)
        return NULL;
    
    assert(pos1 >= 0 && pos1 <= size);
    
    NSInteger pos2;
    // slide down the array looking for a bigger number than what we found before
    for (pos2 = size; perm[pos2] <= perm[pos1] && pos2 > 0; --pos2);
    
    assert(pos2 >= 0 && pos2 <= size);
    
    // swap them
    NSInteger tmp = perm[pos1]; perm[pos1] = perm[pos2]; perm[pos2] = tmp;
    
    // now reverse the elements in between by swapping the ends
    for (++pos1, pos2 = size; pos1 < pos2; ++pos1, --pos2) {
        assert(pos1 >= 0 && pos1 <= size);
        assert(pos2 >= 0 && pos2 <= size);
        
        tmp = perm[pos1]; perm[pos1] = perm[pos2]; perm[pos2] = tmp;
    }
    
    return perm;
}

@implementation NSArray (Permutation)

- (NSArray *)allPermutations
{
    NSInteger size = [self count];
    NSInteger *perm = malloc(size * sizeof(NSInteger));
    
    for (NSInteger idx = 0; idx < size; ++idx)
        perm[idx] = idx;
    
    NSInteger permutationCount = 0;
    
    --size;
    
    NSMutableArray *perms = [NSMutableArray array];
    
    do {
        NSMutableArray *newPerm = [NSMutableArray array];
        
        for (NSInteger i = 0; i <= size; ++i)
            [newPerm addObject:[self objectAtIndex:perm[i]]];
        
        [perms addObject:newPerm];
    } while ((perm = pc_next_permutation(perm, size)) && ++permutationCount < MAX_PERMUTATION_COUNT);
    free(perm);
    
    return perms;
}

@end
