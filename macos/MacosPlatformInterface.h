#import <Cocoa/Cocoa.h>
#import <AppKit/AppKit.h>
#import <OpenGL/OpenGL.h>
#import <OpenGL/gl3.h>

@interface MGAppDelegate : NSObject<NSApplicationDelegate>
{
    BOOL isRunning;
}
@property (atomic, assign) BOOL isRunning;
- (void)setRunning: (BOOL)running;
@end

@interface MGWindowDelegate: NSObject<NSWindowDelegate>
@end

@interface MGView : NSOpenGLView
{
    NSSize renderViewSize;
}
@property (atomic, assign) NSSize renderViewSize;
- (void)drawRect: (NSRect) bounds;
@end
