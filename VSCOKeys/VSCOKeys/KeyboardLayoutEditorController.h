#import <Cocoa/Cocoa.h>

@class KeyControl;
@class MainWindowController;

@interface KeyboardLayoutEditorController : NSObject <NSTextFieldDelegate>

@property (assign) MainWindowController *mainController;
@property (retain) KeyControl *keyControl;
@property (retain) NSView *rootView;

- (id)initWithKeyControl:(KeyControl *)keyControl;
- (void)loadKeyfile:(NSDictionary *)keyfile;
- (void)startNewLayout;
- (void)stopListeningForKeys;
- (void)reloadPhysicalKeyboardLayout;

@end