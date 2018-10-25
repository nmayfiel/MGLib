
#import "MacosPlatformInterface.h"
#import "MacosDebug.h"

@implementation MGAppDelegate

@synthesize isRunning;

- (void)setRunning: (BOOL)running
{
    isRunning = running;
}

- (void)applicationWillFinishLaunching: (NSNotification *)notification
{
    mgiDebugPrintLine("**LIBMG Debug**\nLibMG may throw an assert, and will print debug information.\nTo disable assertions and debug printing:\nCompile the MG library with the -DNDEBUG flag set\n######");
	[NSApp setActivationPolicy: NSApplicationActivationPolicyRegular];
}

- (void)applicationDidFinishLaunching: (NSApplication *)sender
{
	mgiDebugPrintLine("Application finished launching...");
	[NSApp activateIgnoringOtherApps:YES];
}

// @TODO Investigate. ? This is never called, maybe because we're not
// using the provided NSApp->run and ->stop methods ? Maybe the window
// needs to be added to a list in NSApp or something ?
- (BOOL)applicationShouldTerminateAfterLastWindowClosed: (NSNotification *)notification
{
    mgiDebugPrintLine("Last window was closed, app should terminate...");
	return YES;
}

- (void)applicationWillTerminate: (NSNotification *)notification
{
	mgiDebugPrintLine("Application will terminate...");
}

- (void)dealloc
{
	[super dealloc];
}

@end

@implementation MGWindowDelegate

- (void)windowWillClose: (NSNotification *)notification
{
    MGAppDelegate *delegate = [NSApp delegate];
    [delegate setRunning: NO];
	mgiDebugPrintLine("Window is going to close.");
}

- (void)dealloc
{
	[super dealloc];
}

@end

@implementation MGView

@synthesize renderViewSize;

- (id)init
{
    self = [super init];
    return self;
}


// @NOTE These two prevent the 'doonk' noise
///////////////////////////////
//////////////////////////////
- (BOOL)acceptsFirstResponder { return YES; }
- (void)keyDown: (NSEvent *)theEvent {}
///////////////////////////////
//////////////////////////////

- (void)prepareOpenGL
{
    [super prepareOpenGL];
    [[self openGLContext] makeCurrentContext];
}

- (void)reshape
{
    [super reshape];

    NSRect bounds = [self bounds];
    NSSize the_size = NSMakeSize(NSWidth(bounds), NSHeight(bounds));
    float client_aspect = the_size.width / the_size.height;
    float render_aspect = renderViewSize.width / renderViewSize.height;
    NSSize diff = NSMakeSize(0.0, 0.0);

    if (client_aspect >= render_aspect)
    {
        diff.width = the_size.width -
            (the_size.height * (renderViewSize.width / renderViewSize.height));
    }
    else if (client_aspect < render_aspect)
    {
        diff.height = the_size.height -
            (the_size.width * (renderViewSize.height / renderViewSize.width));
    }

    glViewport(0 + (int)(diff.width / 2.0f),
               0 + (int)(diff.height / 2.0f),
               (size_t)(the_size.width - diff.width),
               (size_t)(the_size.height - diff.height));
}

- (void)drawRect: (NSRect) bounds
{
    if ([self inLiveResize])
    {
        // @TODO Temporary, possibly figure out how to
        // capture the image and draw it while the
        // view is resizing...
        glClearColor(0.5, 0.0, 0.5, 1.0);
        glClear(GL_COLOR_BUFFER_BIT);
        [[self openGLContext] flushBuffer];
    }
}

@end


