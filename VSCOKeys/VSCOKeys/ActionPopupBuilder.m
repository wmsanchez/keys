#import "ActionPopupBuilder.h"

NSPopUpButton *VSCOCreateActionPopup(NSArray *actionKeys, NSDictionary *actionNames, NSArray *commandCategories, NSString *selectedAction, NSRect frame)
{
    NSPopUpButton *popup = [[NSPopUpButton alloc] initWithFrame:frame pullsDown:NO];
    [popup removeAllItems];
    [[popup menu] setAutoenablesItems:NO];

    NSString *selectedTitle = [actionNames objectForKey:selectedAction] ?: selectedAction ?: @"";
    NSMenuItem *selectedItem = [[NSMenuItem alloc] initWithTitle:selectedTitle action:nil keyEquivalent:@""];
    [selectedItem setRepresentedObject:selectedAction];
    [selectedItem setHidden:YES];
    [[popup menu] addItem:selectedItem];

    NSMutableSet *addedActionKeys = [NSMutableSet set];
    for (NSDictionary *category in commandCategories) {
        NSString *categoryName = [category objectForKey:@"category"];
        NSMenu *submenu = [[NSMenu alloc] initWithTitle:categoryName ?: @""];
        [submenu setAutoenablesItems:NO];

        for (NSDictionary *command in [category objectForKey:@"items"]) {
            NSString *actionKey = [command objectForKey:@"id"];
            if (![actionKeys containsObject:actionKey] || [addedActionKeys containsObject:actionKey]) continue;

            NSString *title = [command objectForKey:@"name"] ?: [actionNames objectForKey:actionKey] ?: actionKey;
            NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:title action:nil keyEquivalent:@""];
            [item setRepresentedObject:actionKey];
            [submenu addItem:item];
            [addedActionKeys addObject:actionKey];
        }

        if (submenu.numberOfItems == 0) continue;
        NSMenuItem *categoryItem = [[NSMenuItem alloc] initWithTitle:categoryName ?: @"Other Commands" action:nil keyEquivalent:@""];
        [categoryItem setSubmenu:submenu];
        [[popup menu] addItem:categoryItem];
    }

    NSMutableArray *uncategorizedActionKeys = [NSMutableArray array];
    for (NSString *actionKey in actionKeys) {
        if (![addedActionKeys containsObject:actionKey]) [uncategorizedActionKeys addObject:actionKey];
    }
    if (uncategorizedActionKeys.count > 0) {
        NSMenu *submenu = [[NSMenu alloc] initWithTitle:@"Other Commands"];
        [submenu setAutoenablesItems:NO];
        for (NSString *actionKey in uncategorizedActionKeys) {
            NSString *title = [actionNames objectForKey:actionKey] ?: actionKey;
            NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:title action:nil keyEquivalent:@""];
            [item setRepresentedObject:actionKey];
            [submenu addItem:item];
        }
        NSMenuItem *categoryItem = [[NSMenuItem alloc] initWithTitle:@"Other Commands" action:nil keyEquivalent:@""];
        [categoryItem setSubmenu:submenu];
        [[popup menu] addItem:categoryItem];
    }

    [popup selectItem:selectedItem];
    [popup setTitle:selectedTitle];
    return popup;
}
