#import "ActionPopupBuilder.h"

NSPopUpButton *VSCOCreateActionPopup(NSArray *actionKeys, NSDictionary *actionNames, NSString *selectedAction, NSRect frame)
{
    NSPopUpButton *popup = [[NSPopUpButton alloc] initWithFrame:frame pullsDown:NO];
    [popup removeAllItems];

    for (NSString *actionKey in actionKeys) {
        NSString *title = [actionNames objectForKey:actionKey] ?: actionKey;
        NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:title action:nil keyEquivalent:@""];
        [item setRepresentedObject:actionKey];
        [[popup menu] addItem:item];
        if ([actionKey isEqualToString:selectedAction]) [popup selectItem:item];
    }

    return popup;
}
