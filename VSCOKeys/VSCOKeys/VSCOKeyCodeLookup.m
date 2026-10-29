#import "VSCOKeyCodeLookup.h"
#import <Carbon/Carbon.h>

static NSMutableDictionary *gVSCOKeyCodeCache;
static id gVSCOLayoutObserver;

static void VSCOEnsureKeyCodeCache(void)
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        gVSCOKeyCodeCache = [[NSMutableDictionary alloc] init];
        gVSCOLayoutObserver = [[NSDistributedNotificationCenter defaultCenter]
                               addObserverForName:(__bridge NSString *)kTISNotifySelectedKeyboardInputSourceChanged
                               object:nil
                               queue:[NSOperationQueue mainQueue]
                               usingBlock:^(__unused NSNotification *notification) {
                                   [gVSCOKeyCodeCache removeAllObjects];
                               }];
    });
}

static NSString *VSCOCurrentLayoutCachePrefix(void)
{
    TISInputSourceRef source = TISCopyCurrentKeyboardInputSource();
    NSString *layoutID = @"";
    if (source) {
        CFStringRef identifier = TISGetInputSourceProperty(source, kTISPropertyInputSourceID);
        if (identifier) layoutID = [(__bridge NSString *)identifier copy];
        CFRelease(source);
    }
    return layoutID ?: @"";
}

static BOOL VSCOKeyCodeForCharacterOnMainThread(NSString *character, CGKeyCode *keyCode, CGEventFlags *eventFlags)
{
    VSCOEnsureKeyCodeCache();
    NSString *cacheKey = [NSString stringWithFormat:@"%@|%@", VSCOCurrentLayoutCachePrefix(), character];
    id cached = gVSCOKeyCodeCache[cacheKey];
    if ([cached isKindOfClass:[NSDictionary class]]) {
        *keyCode = (CGKeyCode)[cached[@"keyCode"] unsignedShortValue];
        *eventFlags = (CGEventFlags)[cached[@"eventFlags"] unsignedLongLongValue];
        return YES;
    }
    if (cached == [NSNull null]) return NO;

    TISInputSourceRef source = TISCopyCurrentKeyboardInputSource();
    CFDataRef layoutData = source ? TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData) : NULL;
    if (!layoutData) {
        if (source) CFRelease(source);
        source = TISCopyCurrentKeyboardLayoutInputSource();
        layoutData = source ? TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData) : NULL;
    }
    if (!layoutData || !source) {
        if (source) CFRelease(source);
        gVSCOKeyCodeCache[cacheKey] = [NSNull null];
        return NO;
    }

    const UCKeyboardLayout *layout = (const UCKeyboardLayout *)CFDataGetBytePtr(layoutData);
    UniChar target = [character characterAtIndex:0];
    const UInt32 modifierStates[] = {0, 2, 8, 10};
    BOOL found = NO;
    if (layout) {
        for (UInt16 code = 0; code <= 0xFF && !found; code++) {
            for (NSUInteger index = 0; index < sizeof(modifierStates) / sizeof(modifierStates[0]); index++) {
                UInt32 deadKeyState = 0;
                UniChar translatedCharacter = 0;
                UniCharCount characterCount = 0;
                OSStatus result = UCKeyTranslate(layout, code, kUCKeyActionDown, modifierStates[index],
                                                 LMGetKbdLast(), kUCKeyTranslateNoDeadKeysBit,
                                                 &deadKeyState, 1, &characterCount, &translatedCharacter);
                if (result == noErr && characterCount == 1 && translatedCharacter == target) {
                    *keyCode = code;
                    *eventFlags = 0;
                    if (modifierStates[index] & 2) *eventFlags |= kCGEventFlagMaskShift;
                    if (modifierStates[index] & 8) *eventFlags |= kCGEventFlagMaskAlternate;
                    found = YES;
                    break;
                }
            }
        }
    }
    CFRelease(source);
    if (found) {
        gVSCOKeyCodeCache[cacheKey] = @{
            @"keyCode": @(*keyCode),
            @"eventFlags": @(*eventFlags)
        };
    } else {
        gVSCOKeyCodeCache[cacheKey] = [NSNull null];
    }
    return found;
}

BOOL VSCOResolveKeyCodeForCharacter(NSString *character, CGKeyCode *keyCode, CGEventFlags *eventFlags)
{
    if (character.length != 1 || !keyCode || !eventFlags) return NO;

    if ([NSThread isMainThread]) {
        return VSCOKeyCodeForCharacterOnMainThread(character, keyCode, eventFlags);
    }

    __block BOOL found = NO;
    __block CGKeyCode resolvedCode = 0;
    __block CGEventFlags resolvedFlags = 0;
    dispatch_sync(dispatch_get_main_queue(), ^{
        found = VSCOKeyCodeForCharacterOnMainThread(character, &resolvedCode, &resolvedFlags);
    });
    if (found) {
        *keyCode = resolvedCode;
        *eventFlags = resolvedFlags;
    }
    return found;
}
