#import <Cocoa/Cocoa.h>
#import "MacBookKeyboardView.h"

@class KeyControl;
@class MainWindowController;

@interface KeyboardLayoutEditorController : NSObject <NSTextFieldDelegate, MacBookKeyboardViewDelegate>

@property (assign) MainWindowController *mainController;
@property (retain) KeyControl *keyControl;
@property (retain) NSView *rootView;
@property (assign) BOOL hasUnsavedChanges;

- (id)initWithKeyControl:(KeyControl *)keyControl;
- (void)loadKeyfile:(NSDictionary *)keyfile;
- (void)startNewLayout;
- (void)stopListeningForKeys;
- (void)reloadPhysicalKeyboardLayout;
- (void)reloadActionCatalog;
- (CGFloat)keyboardPreviewUnitScale;
- (CGFloat)keyboardPreviewUnitScaleForRootViewSize:(NSSize)size;
- (void)saveClicked:(id)sender;
- (BOOL)swapBindingsFromKeys:(NSArray *)sourceKeyCodes toTargetKey:(NSString *)targetKeyCode;

@end