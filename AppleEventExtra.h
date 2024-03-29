#import <Cocoa/Cocoa.h>

@interface NSAppleEventDescriptor (AppleEventExtra)
+ (NSAppleEventDescriptor *)descriptorWithFloat:(float)a_value;
+ (NSAppleEventDescriptor *)descriptorWithDouble:(double)a_value;
@end

@interface NSString (AppleEventExtra)
- (NSAppleEventDescriptor *) appleEventDescriptor;
@end

@interface NSNumber (AppleEventExtra)
- (NSAppleEventDescriptor *) appleEventDescriptor;
@end