## MRTFetchedResultsController

`MRTFetchedResultsController` provideds automatic Core Data change tracking and it's a port of `NSFetchedResultsController` for OS X. It performs many of the same tasks in relation to managing results from a Core Data fetch and notifying a delegate when objects are inserted, deleted, updated, or moved in order to update the UI.

### Installation
`MRTFetchedResultsController` is a single class with no dependencies, just download and drag the `MRTFetchedResultsController.{h,m}` files in your Xcode project. All the classes require ARC or you will have to compile it with the `-fobjc-arc` flag.

## Table of Contents

* [**MRTFetchedResultsController**](#mrtfetchedresultscontroller)
  * [Usage](#usage)
  * [Respond to Core Data changes](#respond-to-core-data-changes)
  * [In-memory sorting and filtering](#in-memory-sorting-and-filtering)
  * [fetchedObjects vs arrangedObjects](#fetchedobjects-vs-arrangedobjects)
* [**Unit Tests**](#unit-tests)
* [**Credits**](#credits)
* [**License**](#license)

## Usage

``` obj-c
// Creating a NSFetchRequest with entity/sort descriptor/predicate
NSFetchRequest *request = [[NSFetchRequest alloc] init];
request.entity = [NSEntityDescription entityForName:@"Notes" inManagedObjectContext:context];
request.sortDescriptors = [NSArray arrayWithObjects:[NSSortDescriptor sortDescriptorWithKey:@"date" ascending:YES], nil];
request.predicate = [NSPredicate predicateWithFormat:@"deleted = NO"];

// Creating the MRTFetchedResultsController
MRTFetchedResultsController *fetchedResultsController = [[MRTFetchedResultsController alloc] initWithManagedObjectContext:context fetchRequest:request];

// Retrieving the objects
NSError *error = nil;
[fetchedResultsController performFetch:&error];
if (error) {
    NSLog(@"Unresolved error: %@ %@", error, [error userInfo]);
}
else {
  NSLog(@"fetched objects %@", fetchedResultsController.fetchedObjects)
}
```

### Respond to Core Data changes
If you want to monitor changes to objects in the associated managed object context you can assign a delegate that respond to the `MRTFetchedResultsControllerDelegate`. The controller notifies the delegate when result objects change.

```obj-c
#pragma mark - MRTFetchedResultsControllerDelegate

// Called one time for each batch of changes, BEFORE the changes are applied to the controller
- (void)controllerWillChangeContent:(MRTFetchedResultsController *)controller
{
}

// Called one time for each batch of changes, AFTER the changes are applied to the controller
- (void)controllerDidChangeContent:(MRTFetchedResultsController *)controller
{
}

// Called once per object that's being changed
- (void)controller:(MRTFetchedResultsController *)controller didChangeObject:(id)anObject atIndex:(NSUInteger)index forChangeType:(MRTFetchedResultsChangeType)type newIndex:(NSUInteger)newIndex
{
    switch (type) {
        case MRTFetchedResultsChangeDelete:
            // The object was removed from the controller
            break;
        case MRTFetchedResultsChangeInsert:
            // The object is newly inserted in the controller
            break;
        case MRTFetchedResultsChangeUpdate:
            // One or more of the object property has been updated
            break;
        case MRTFetchedResultsChangeMove:
            // One or more of the object property has been updated
            // and that has changed the order in the controller
            break;
        default:
            break;
    }
}

```

### In-memory sorting and filtering
`MRTFetchedResultsController` supports in memory sorting and filtering without changing the NSFetchRequest (so you will continue to receive the correct Core Data changes notification).  
You can sort your content by adding one or more NSSortDescriptor:
``` obj-c
fetchedResultsController.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"order" ascending:YES], nil];
NSLog(@"sorted objects %@", fetchedResultsController.arrangedObjects);
```
And you can filter your objects by adding an NSPredicate:
``` obj-c
fetchedResultsController.filterPredicate = [NSPredicate predicateWithFormat:@"text LIKE %@", someText];
NSLog(@"filtered objects %@", fetchedResultsController.arrangedObjects);
```
### fetchedObjects vs arrangedObjects
Objects fetched by `MRTFetchedResultsController` can be accessed in two different way:

1. the **fetchedObjects** property
2. the **arrangedObjects** property

For having the results of a in-memory sort or filter you must use the **arrangedObjects** property, while **fetchedObjects** will always return your original contents. If you have not set any _sortDescriptors_ or _filterPredicate_ on the fetchedResultsController, calling the **arrangedObjects** property will just return the **fetchedObjects**.

## Unit Tests
Unit tests were performed on all the library for quality assurance. To run the tests, open the Xcode workspace, choose the 
MRTFetchedResultsControllerTests target in the toolbar at the top, and select the menu item `Product > Test`.

If you ever find a test case that is incomplete, please open an issue so we can get it fixed.

## Credits

Thanks to [Indragie Karunaratne](http://indragie.com/) for his initial work on [SNRFetchedResultsController](https://github.com/indragiek/SNRFetchedResultsController). It laid the foundation for MRTFetchedResultsController.

## License
This project is distributed under the standard MIT License. Please use this in whatever fashion you wish - feel free to recommend any changes to help the code.

