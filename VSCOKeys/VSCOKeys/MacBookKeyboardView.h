#import <Cocoa/Cocoa.h>

@protocol MacBookKeyboardViewDelegate <NSObject>
- (void)keyboardViewDidSelectKeyCode:(NSString *)keyCode;
@end

@interface MacBookKeyboardView : NSView
@property (retain) NSArray *keyItems;
@property (retain) NSDictionary *keyMapping;
@property (retain) NSDictionary *assignmentTypes;
@property (retain) NSDictionary *assignmentLabels;
@property (retain) NSString *selectedKeyCode;
@property (retain) NSString *capturedKeyCode;
@property (assign) BOOL capturedKeyHasBinding;
@property (assign) id<MacBookKeyboardViewDelegate> delegate;
@property (nonatomic, assign) BOOL listeningForKeys;
@property (assign) CGFloat glowPhase;
@property (assign) CGFloat glowRemaining;
@property (retain) NSTimer *glowTimer;
@property (assign) CGFloat keyboardUnitCount;
@property (assign) CGFloat keyboardTopY;
- (void)setKeyboardLayoutDefinition:(NSDictionary *)layout;
- (void)showCapturedKeyCode:(NSString *)keyCode hasBinding:(BOOL)hasBinding;
- (void)showCapturedKeyCode:(NSString *)keyCode hasBinding:(BOOL)hasBinding actionTitle:(NSString *)actionTitle;
- (void)advanceGlowAnimation:(NSTimer *)timer;
@end