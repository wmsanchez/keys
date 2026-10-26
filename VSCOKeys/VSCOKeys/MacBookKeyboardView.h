#import <Cocoa/Cocoa.h>

@class MacBookKeyboardView;

@protocol MacBookKeyboardViewDelegate <NSObject>
@optional
- (void)keyboardView:(MacBookKeyboardView *)keyboardView didChangeShortLabel:(NSString *)label forAction:(NSString *)action;
- (void)keyboardView:(MacBookKeyboardView *)keyboardView didChangePresetLabel:(NSString *)label forPreset:(NSString *)presetValue;
- (void)keyboardViewDidFinishEditingShortLabel:(MacBookKeyboardView *)keyboardView;
- (void)keyboardView:(MacBookKeyboardView *)keyboardView didMoveBindingFromKey:(NSString *)sourceKeyCode toKey:(NSString *)targetKeyCode;
- (void)keyboardView:(MacBookKeyboardView *)keyboardView didMoveBindingsFromKeys:(NSArray *)sourceKeyCodes anchorKey:(NSString *)anchorKeyCode toKey:(NSString *)targetKeyCode;
@required
- (void)keyboardViewDidSelectKeyCode:(NSString *)keyCode;
- (void)keyboardView:(MacBookKeyboardView *)keyboardView didSelectKeyCodes:(NSSet *)keyCodes primaryKeyCode:(NSString *)keyCode;
@end

@interface MacBookKeyboardView : NSView
@property (retain) NSArray *keyItems;
@property (retain) NSDictionary *keyMapping;
@property (retain) NSDictionary *assignmentTypes;
@property (retain) NSDictionary *assignmentLabels;
@property (nonatomic, retain) NSDictionary *assignmentDetails;
@property (nonatomic, assign) BOOL usesMotibodoLabels;
@property (nonatomic, assign) BOOL showsIncrementAmounts;
@property (nonatomic, assign) BOOL allowsInlineLabelEditing;
@property (retain) NSString *selectedKeyCode;
@property (nonatomic, retain) NSSet *selectedKeyCodes;
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