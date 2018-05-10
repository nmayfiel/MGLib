
#include "mg.h"

#import <OpenGL/gl3.h>
#import "MacosPlatformInterface.h"
#import "MacosDebug.h"

#include <stdint.h>
#include <stddef.h>
#include <stdbool.h>
#include <mach/mach_time.h>

#include "default_shaders.h"

#define STB_IMAGE_IMPLEMENTATION
#define STBI_ONLY_BMP
#define STBI_ONLY_PNG
#define STB_IMAGE_STATIC
#include "support/stb_image.h"

typedef bool		mg__bool;
typedef int8_t		mg__s8;
typedef int32_t		mg__s32;
typedef uint8_t		mg__u8;
typedef uint32_t	mg__u32;
typedef uint64_t	mg__u64;
typedef float		mg__r32;

typedef mach_timebase_info_data_t	mg__tbi;

static mg__bool mgiInitialized = false;
static mg__s32 	mgiGlobalViewWidth = 0;
static mg__s32 	mgiGlobalViewHeight = 0;
static mg__r32 	mgiGlobalAppScaleX;
static mg__r32 	mgiGlobalAppScaleY;
static mg__tbi 	mgiGlobalTimebaseInfo;

static NSOpenGLPixelFormat	*mgiGlobalOpenGLPixelFormat;
static NSOpenGLContext		*mgiGlobalOpenGLContext;

static GLuint	mgiGlobalColorProgramId;
static GLuint	mgiGlobalTextureProgramId;
static GLuint	mgiGlobalQuadVBO;
static GLuint	mgiGlobalQuadIndexBuffer;
static GLint	mgiProjectionUniforms[2];
static GLint	mgiTimeUniforms[2];
static mg__r32	mgiGlobalTime = 0.0f;
static mg__u8	mgiGlobalQuadIndices[6] = {0, 1, 2, 0, 2, 3};

#define mgiInitializeRequired() assert(mgiInitialized)
#define mgiInvalidPath() assert(0)

typedef struct	mgiQuadVertex_s
{
    mg__r32 position[3];
    mg__r32 uv[2];
    mg__r32 color[4];
}				mgiQuadVertex;

typedef enum	mgiAttribLocation_e
{
    in_position = 0,
    in_uv,
    in_color,
}				mgiAttribLocation;

// @MOVE_TO_C
static GLuint	mgiCompileShader(const GLchar *vert_source,
                               const GLchar *frag_source,
                               GLuint *vertex_id, GLuint *fragment_id)
{
    GLuint program_id;

    *vertex_id = glCreateShader(GL_VERTEX_SHADER);
    glShaderSource(*vertex_id, 1, &vert_source, 0);
    glCompileShader(*vertex_id);

    *fragment_id = glCreateShader(GL_FRAGMENT_SHADER);
    glShaderSource(*fragment_id, 1, &frag_source, 0);
    glCompileShader(*fragment_id);

    program_id = glCreateProgram();
    glAttachShader(program_id, *vertex_id);
    glAttachShader(program_id, *fragment_id);
    glLinkProgram(program_id);

    return (program_id);
}

// @MOVE_TO_C
static mg__bool		mgiShaderCompiledOkay(GLuint pid, GLuint vid, GLuint fid)
{
    GLint linked = GL_FALSE;

    glValidateProgram(pid);
    glGetProgramiv(pid, GL_LINK_STATUS, &linked);
    if (linked == GL_FALSE)
    {
        mgiDebugPrintShaderError(vid, fid);
        return (false);
    }
    return (true);
}

static void	mgiAbsolutetimeToNanoseconds(uint64_t abstime, uint64_t *result)
{
    if (mgiGlobalTimebaseInfo.denom == 0)
        mach_timebase_info(&mgiGlobalTimebaseInfo);
    *result = abstime * mgiGlobalTimebaseInfo.numer / mgiGlobalTimebaseInfo.denom;
}

static void		mgiUpdateClock(void)
{
    static mg__u64 last = 0;
    mg__u64 now = mach_absolute_time();
    mg__u64 nanoseconds;

    if (last == 0)
        last = now;
    mgiAbsolutetimeToNanoseconds(now - last, &nanoseconds);
    mgiGlobalTime += ((mg__r32)nanoseconds * 1.0E-9);
    last = now;
}

static mg__r32	mgiGetScreenDPI(void)
{
    mg__r32 dpi;
    NSScreen *screen;
    
    screen = [NSScreen mainScreen];
    NSDictionary *description = [screen deviceDescription];
    NSSize displayPixelSize = [[description objectForKey:NSDeviceSize]
                                  sizeValue];
    CGSize displayPhysicalSize = CGDisplayScreenSize(
        [[description objectForKey:@"NSScreenNumber"] unsignedIntValue]);
    CGFloat backingScale = [screen backingScaleFactor];

    mg__r32 pixelWidth = backingScale * displayPixelSize.width;
    mg__r32 physicalWidth = (mg__r32)displayPhysicalSize.width;

    dpi = (pixelWidth / physicalWidth) * 25.4f;
    return (dpi);
}

static mg__bool	mgiAppRunning(void)
{
    mgiInitializeRequired();

    MGAppDelegate *delegate = [NSApp delegate];
    BOOL running = [delegate isRunning];
    return (running ? true : false);
}

// @MOVE_TO_C
static void	mgiRendering2D(mg__s32 shader_index)
{
    mg__r32 m[4][4];

    memset(m, 0, sizeof(mg__r32) * 4 * 4);
    m[0][0] = 2.0f * mgiGlobalAppScaleX / (mg__r32)mgiGlobalViewWidth;
    m[3][0] = -1.0f * mgiGlobalAppScaleX;
    m[1][1] = 2.0f * mgiGlobalAppScaleY / (mg__r32)mgiGlobalViewHeight;
    m[3][1] = -1.0f * mgiGlobalAppScaleY;
    m[2][2] = 1;
    m[3][3] = 1;

    glUniformMatrix4fv(mgiProjectionUniforms[shader_index], 1, GL_FALSE, &m[0][0]);
    glUniform1f(mgiTimeUniforms[shader_index], mgiGlobalTime);
}

static void		mgiCreateAppMenu(const char *app_name)
{
    @autoreleasepool
    {
        NSString *appNameString = [[[NSString alloc]
                 initWithCString: app_name
                        encoding: NSASCIIStringEncoding] autorelease];
        NSMenu *menu_bar = [[[NSMenu alloc] initWithTitle:@""] autorelease];
        NSMenu *app_menu = [NSMenu new];
        NSMenu *view_menu = [[[NSMenu alloc]
                                 initWithTitle:@"View"] autorelease];

        NSMenuItem *fs_item = [view_menu
                                  addItemWithTitle:@"Enter Full Screen"
                                            action:@selector(toggleFullScreen:)
                                     keyEquivalent:@"f"];
        [fs_item setKeyEquivalentModifierMask: NSEventModifierFlagControl
                 | NSEventModifierFlagCommand];

        NSString *quit_name = [@"Quit " stringByAppendingString: appNameString];
        NSMenuItem *quit_item = [app_menu
                                    addItemWithTitle: quit_name
                                              action:@selector(terminate:)
                                       keyEquivalent:@"q"];
        [quit_item setKeyEquivalentModifierMask: NSEventModifierFlagCommand];

        [NSApp setMainMenu:menu_bar];

        // Add buttons to the menu bar
        NSMenuItem *app_item = [menu_bar addItemWithTitle:appNameString
                                                   action:nil
                                            keyEquivalent:@""];
        NSMenuItem *view_item = [menu_bar addItemWithTitle:@"View"
                                                    action:nil
                                             keyEquivalent:@""];

        // Associate the dropdown menus with items in the menu bar
        [app_item setSubmenu: app_menu];
        [view_item setSubmenu: view_menu];
    }
}


/////////////////////////////////////////////////////////////
// API BEGINS HERE
/////////////////////////////////////////////////////////////


MGDEF int	mg_initialize(const char *app_name)
{
    assert(!mgiInitialized);

    NSApplication *app = [NSApplication sharedApplication];
    mgiCreateAppMenu(app_name);
    MGAppDelegate *delegate = [[MGAppDelegate alloc] init];
    [app setDelegate: delegate];
    [delegate setRunning: YES];
    [app finishLaunching];
    NSOpenGLPixelFormatAttribute openGLAttribs[] =
        {
            NSOpenGLPFAAccelerated,
            NSOpenGLPFADoubleBuffer,
            NSOpenGLPFAColorSize, 24,
            NSOpenGLPFAAlphaSize, 8,
            NSOpenGLPFADepthSize, 24,
            NSOpenGLPFAOpenGLProfile, NSOpenGLProfileVersion3_2Core,
            0
        };
    mgiGlobalOpenGLPixelFormat = [[NSOpenGLPixelFormat alloc]
                                         initWithAttributes: openGLAttribs];
    mgiGlobalOpenGLContext = [[NSOpenGLContext alloc]
                                     initWithFormat:mgiGlobalOpenGLPixelFormat
                                       shareContext: NULL];
    [mgiGlobalOpenGLContext makeCurrentContext];

    {
        GLuint vertex_id, fragment_id;
        mgiGlobalColorProgramId = mgiCompileShader(shader_source_vertex,
                                             shader_source_fragment,
                                             &vertex_id, &fragment_id);
        assert(mgiShaderCompiledOkay(mgiGlobalColorProgramId,
                                     vertex_id, fragment_id));
        mgiProjectionUniforms[0] = glGetUniformLocation(mgiGlobalColorProgramId,
                                               "in_projection");
        mgiTimeUniforms[0] = glGetUniformLocation(mgiGlobalColorProgramId, "in_time");

        mgiGlobalTextureProgramId = mgiCompileShader(shader_source_vertex,
                                               tex_shader_source_fragment,
                                               &vertex_id, &fragment_id);
        assert(mgiShaderCompiledOkay(mgiGlobalTextureProgramId,
                                     vertex_id, fragment_id));
        mgiProjectionUniforms[1] = glGetUniformLocation(mgiGlobalTextureProgramId,
                                               "in_projection");
        mgiTimeUniforms[1] = glGetUniformLocation(mgiGlobalTextureProgramId, "in_time");
    }

    GLuint opengl_is_dumb_vao;
    glGenVertexArrays(1, &opengl_is_dumb_vao);
    glBindVertexArray(opengl_is_dumb_vao);
    
    mg__r32 dpi = mgiGetScreenDPI();
    mgiGlobalAppScaleX = dpi / 96.0f;
    mgiGlobalAppScaleY = dpi / 96.0f;

    glGenBuffers(1, &mgiGlobalQuadIndexBuffer);
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, mgiGlobalQuadIndexBuffer);
    glBufferData(GL_ELEMENT_ARRAY_BUFFER, sizeof(mg__u8) * 6,
                 &mgiGlobalQuadIndices[0], GL_STREAM_DRAW);

    glGenBuffers(1, &mgiGlobalQuadVBO);
    glBindBuffer(GL_ARRAY_BUFFER, mgiGlobalQuadVBO);
    mgiQuadVertex m[4];
    memset(&m[0], 0, sizeof(mgiQuadVertex) * 4);
    glBufferData(GL_ARRAY_BUFFER, 4 * sizeof(mgiQuadVertex), &m[0], GL_STREAM_DRAW);

    glEnable(GL_BLEND);
    glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
    
    assert((glGetError() == 0));
    
    mgiDebugPrintLine("MiniLibGraphics Initialized...");
    mgiInitialized = true;
    
	return (1);
}


MGDEF int	mg_open_window_with_opts(mg_window_opts_t opts)
{
    mgiInitializeRequired();
    
    mg__u32 style_mask = NSWindowStyleMaskTitled
        | NSWindowStyleMaskClosable
        | NSWindowStyleMaskMiniaturizable;
    if (!(opts.resize_flags & MG_NO_RESIZE))
    {
        //if(opts.resize_flags & MG_RESIZE_FULL)
        //    style_mask |= NSWindowStyleMaskFullScreen;
        if (opts.resize_flags & MG_RESIZE)
            style_mask |= NSWindowStyleMaskResizable;
    }
    
    NSRect screen = [[NSScreen mainScreen] frame];
    size_t width = opts.width > 0 ? opts.width : screen.size.width;
    size_t height = opts.height > 0 ? opts.height : screen.size.height;
    mgiGlobalViewWidth = width;
    mgiGlobalViewHeight = height;
    NSRect frame = NSMakeRect(
        opts.position_x, opts.position_y,
        width, height);
    NSWindow *window = [[NSWindow alloc]
                               initWithContentRect: frame
                                         styleMask: style_mask
                                           backing: NSBackingStoreBuffered
                                             defer: NO];
    [window setBackgroundColor: [NSColor blackColor]];
    MGWindowDelegate *delegate = [[MGWindowDelegate alloc] init];
    [window setDelegate: delegate];
    NSView *content_view = (id)[window contentView];
    [content_view setAutoresizingMask:
                      NSViewWidthSizable | NSViewHeightSizable];
    [content_view setAutoresizesSubviews: YES];

    NSString *window_title = [[NSString alloc]
                                     initWithCString: opts.name
                                            encoding: NSASCIIStringEncoding];
    [window setTitle: window_title];
    [window_title release];

    MGView *view = [[MGView alloc] init];
    view.renderViewSize = NSMakeSize(width, height);
    [view setAutoresizingMask: NSViewWidthSizable | NSViewHeightSizable];
    [view setPixelFormat: mgiGlobalOpenGLPixelFormat];
    [view setOpenGLContext: mgiGlobalOpenGLContext];
    [view setFrame: [content_view bounds]];
    [content_view addSubview: view];

    [window makeKeyAndOrderFront: nil];

    GLint swapInt = 1;
    [mgiGlobalOpenGLContext setValues: &swapInt
                      forParameter: NSOpenGLCPSwapInterval];
    [mgiGlobalOpenGLContext setView: content_view];
    [mgiGlobalOpenGLContext makeCurrentContext];
    
    mgiDebugPrintLine("Opening window with opts, named:");
    mgiDebugPrintLine(opts.name);
    return (1);
}

// @MOVE_TO_C
MGDEF unsigned int	mg_load_texture(const char *filename, int *width,
                            int *height, unsigned char **data)
{
    int bytes_per_pixel;
    int desired_bytes_per_pixel = 4;
    *data = stbi_load(filename, width, height, &bytes_per_pixel,
                     desired_bytes_per_pixel);
    if (!*data)
    {
        const char *reason = stbi_failure_reason();
        mgiDebugPrintLine(reason);
    }
    assert(bytes_per_pixel == desired_bytes_per_pixel);
    assert(*data != NULL);
    assert(*width > 0);
    assert(*height > 0);

    GLuint txo;
    glGenTextures(1, &txo);
    glBindTexture(GL_TEXTURE_2D, txo);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
    glTexImage2D(GL_TEXTURE_2D,
                 0,
                 GL_RGBA8,
                 *width,
                 *height,
                 0,
                 GL_RGBA,
                 GL_UNSIGNED_BYTE,
                 *data);
    return (txo);
}

MGDEF void			mg_free_texture_data(unsigned char *data)
{
    free(data);
}

enum mgKeys {
    mg_key_NULL 			= 0x00,
    mg_key_LeftMouseButton	= 0x01,
    mg_key_RightMouseButton = 0x02,
    mg_key_Cancel			= 0x03,
    mg_key_MiddleMouseButton	= 0x04,
    mg_key_X1MouseButton 		= 0x05,
    mg_key_X2MouseButton 		= 0x06,
    mg_key_Backspace 			= 0x08,
    mg_key_Tab 					= 0x09,
    mg_key_Clear 				= 0x0C,
    mg_key_Return 				= 0x0D,
    mg_key_Shift 				= 0x10,
    mg_key_Control 				= 0x11,
    mg_key_Alt 					= 0x12,
    mg_key_Pause 				= 0x13,
    mg_key_CapsLock 			= 0x14,
    mg_key_IMEKana 				= 0x15,
    mg_key_IMEJunja 			= 0x17,
    mg_key_IMEFinal 			= 0x18,
    mg_key_IMEHanja 			= 0x19,
    mg_key_Escape 				= 0x1B,
    mg_key_IMEConvert 			= 0x1C,
    mg_key_IMENonConvert 		= 0x1D,
    mg_key_IMEAccept		 	= 0x1E,
    mg_key_IMEModeChangeRequest = 0x1F,
    
    mg_key_Spacebar	= 0x20,
    
    mg_key_PageUp 	= 0x21,
    mg_key_PageDown = 0x22,
    mg_key_End 		= 0x23,
    mg_key_Home 	= 0x24,
    
    mg_key_LeftArrow 	= 0x25,
    mg_key_UpArrow 		= 0x26,
    mg_key_RightArrow 	= 0x27,
    mg_key_DownArrow 	= 0x28,
    
    mg_key_Select 	= 0x29,
    mg_key_Print 	= 0x2A,
    mg_key_Execute 	= 0x2B,
    mg_key_PrintScreen 	= 0x2C,
    mg_key_Insert 	= 0x2D,
    mg_key_Delete 	= 0x2E,
    mg_key_Help 	= 0x2F,
    
    mg_key_0 = 0x30,
    mg_key_1 = 0x31,
    mg_key_2 = 0x32,
    mg_key_3 = 0x33,
    mg_key_4 = 0x34,
    mg_key_5 = 0x35,
    mg_key_6 = 0x36,
    mg_key_7 = 0x37,
    mg_key_8 = 0x38,
    mg_key_9 = 0x39,
        
    mg_key_A = 0x41,
    mg_key_B = 0x42,
    mg_key_C = 0x43,
    mg_key_D = 0x44,
    mg_key_E = 0x45,
    mg_key_F = 0x46,
    mg_key_G = 0x47,
    mg_key_H = 0x48,
    mg_key_I = 0x49,
    mg_key_J = 0x4A,
    mg_key_K = 0x4B,
    mg_key_L = 0x4C,
    mg_key_M = 0x4D,
    mg_key_N = 0x4E,
    mg_key_O = 0x4F,
    mg_key_P = 0x50,
    mg_key_Q = 0x51,
    mg_key_R = 0x52,
    mg_key_S = 0x53,
    mg_key_T = 0x54,
    mg_key_U = 0x55,
    mg_key_V = 0x56,
    mg_key_W = 0x57,
    mg_key_X = 0x58,
    mg_key_Y = 0x59,
    mg_key_Z = 0x5A,

    // Windows key on Windows,
    // Command on MacOS
    mg_key_LeftOS 		= 0x5B,
    mg_key_RightOS	 	= 0x5C,

    mg_key_Applications = 0x5D,
    mg_key_Sleep 		= 0x5F,
    
    mg_key_Numpad0 = 0x60,
    mg_key_Numpad1 = 0x61,
    mg_key_Numpad2 = 0x62,
    mg_key_Numpad3 = 0x63,
    mg_key_Numpad4 = 0x64,
    mg_key_Numpad5 = 0x65,
    mg_key_Numpad6 = 0x66,
    mg_key_Numpad7 = 0x67,
    mg_key_Numpad8 = 0x68,
    mg_key_Numpad9 = 0x69,
    
    mg_key_Multiply 	= 0x6A,
    mg_key_Add 			= 0x6B,
    mg_key_Enter		= 0x6C,
    mg_key_Subtract 	= 0x6D,
    mg_key_Decimal 		= 0x6E,
    mg_key_Divide 		= 0x6F,
    
    mg_key_F1 = 0x70,
    mg_key_F2 = 0x71,
    mg_key_F3 = 0x72,
    mg_key_F4 = 0x73,
    mg_key_F5 = 0x74,
    mg_key_F6 = 0x75,
    mg_key_F7 = 0x76,
    mg_key_F8 = 0x77,
    mg_key_F9 = 0x78,
    mg_key_F10 = 0x79,
    mg_key_F11 = 0x7A,
    mg_key_F12 = 0x7B,
    mg_key_F13 = 0x7C,
    mg_key_F14 = 0x7D,
    mg_key_F15 = 0x7E,
    mg_key_F16 = 0x7F,
    mg_key_F17 = 0x80,
    mg_key_F18 = 0x81,
    mg_key_F19 = 0x82,
    mg_key_F20 = 0x83,
    mg_key_F21 = 0x84,
    mg_key_F22 = 0x85,
    mg_key_F23 = 0x86,
    mg_key_F24 = 0x87,
    
    mg_key_NumLock 		= 0x90,
    mg_key_Scroll 		= 0x91,
    mg_key_OEMSpecific1 = 0x92,
    mg_key_OEMSpecific2 = 0x93,
    mg_key_OEMSpecific3 = 0x94,
    mg_key_OEMSpecific4 = 0x95,
    mg_key_OEMSpecific5 = 0x96,
    mg_key_LeftShift	=	0xA0,	
    mg_key_RightShift	=	0xA1,
    mg_key_LeftControl	=	0xA2,
    mg_key_RightControl	=	0xA3,
    mg_key_LeftAlt		=	0xA4, 	
    mg_key_RightAlt		=	0xA5,	
    mg_key_BrowserBack	=	0xA6,
    mg_key_BrowserForward =	0xA7,
    mg_key_BrowserRefresh =	0xA8,
    mg_key_BrowserStop	  =	0xA9,
    mg_key_BrowserSearch  =	0xAA,
    mg_key_BrowserFavorites =	0xAB,
    mg_key_BrowserHome	=	0xAC,
    mg_key_VolumeMute	=	0xAD,
    mg_key_VolumeDown	=	0xAE,
    mg_key_VolumeUp		=	0xAF,
    mg_key_MediaNextTrack	=	0xB0,
    mg_key_MediaPreviousTrack =	0xB1,
    mg_key_MediaStop		=	0xB2,
    mg_key_MediaPlayPause	=	0xB3,
    mg_key_LaunchMail		=	0xB4,
    mg_key_LaunchMediaSelect =	0xB5,
    mg_key_LaunchApp1		=	0xB6,
    mg_key_LaunchApp2		=	0xB7,
    
    mg_key_Semicolon   		=	0xBA,	// ';:' - US
    mg_key_Equals			=	0xBB,	// '+'  - Any Region
    mg_key_Comma			=	0xBC,	// ','  - Any Region
    mg_key_Minus			=	0xBD,	// '-'  - Any Region
    mg_key_Period			=	0xBE,	// '.'  - Any Region	
    mg_key_Slash	   		=	0xBF,	// '/?' - US
    mg_key_Grave   			=	0xC0, 	// '`~' - US
    mg_key_LeftBracket		=	0xDB,  	// '[{' - US
    mg_key_Backslash   		=	0xDC,  	// '\|' - US
    mg_key_RightBracket		=	0xDD,  	// ']}' - US
    mg_key_Quote			=	0xDE,  	// ''"' - US
    mg_key_OEM8				=	0xDF,	// MISC

    mg_key_OEMSpecific6	=	0xE1,
    mg_key_OEM102		=	0xE2,
    mg_key_OEMSpecific7	=	0xE3,
    mg_key_OEMSpecific8	=	0xE4,
    mg_key_IMEProcess	=	0xE5,
    mg_key_OEMSpecific9	=	0xE6,
    mg_key_Packet		=	0xE7, // @TODO check if this might be useful!!
    mg_key_OEMSpecific10 =	0xE9,
    mg_key_OEMSpecific11 =	0xEA,
    mg_key_OEMSpecific12 =	0xEB,
    mg_key_OEMSpecific13 =	0xEC,
    mg_key_OEMSpecific14 =	0xED,
    mg_key_OEMSpecific15 =	0xEE,
    mg_key_OEMSpecific16 =	0xEF,
    mg_key_OEMSpecific17 =	0xF0,
    mg_key_OEMSpecific18 =	0xF1,
    mg_key_OEMSpecific19 =	0xF2,
    mg_key_OEMSpecific20 =	0xF3,
    mg_key_OEMSpecific21 =	0xF4,
    mg_key_OEMSpecific22 =	0xF5,
    mg_key_Attn			=	0xF6,
    mg_key_CrSel		=	0xF7,
    mg_key_ExSel		=	0xF8,
    mg_key_EraseEOF		=	0xF9,
    mg_key_Play			=	0xFA,
    mg_key_Zoom			=	0xFB,
    mg_key_NoName		=	0xFC,
    mg_key_PA1			=	0xFD,
    mg_key_OEMClear		=	0xFE,

    mg_key_ISOSection = 0xFF,
    mg_key_Function = 0x100,
    mg_key_JISYen = 0x101,
    mg_key_JISUnderscore = 0x102,
    mg_key_JISNumpadComma = 0x103,
    mg_key_JISEisu = 0x104,
    mg_key_JISKana = 0x105,
    
    mg_NUM_KEYS
};

// MacOS can use this array to map keys...
// Windows doesn't need to use it at all, keys line up to mg_key enum

int mgiGlobalKeyMap[] = {
    mg_key_A,
    mg_key_S,
    mg_key_D,
    mg_key_F,
    mg_key_H,
    mg_key_G,
    mg_key_Z,
    mg_key_X,
    mg_key_C,
    mg_key_V,
    mg_key_ISOSection,
    mg_key_B,
    mg_key_Q,
    mg_key_W,
    mg_key_E,
    mg_key_R,
    mg_key_Y,
    mg_key_T,
    mg_key_1,
    mg_key_2,
    mg_key_3,
    mg_key_4,
    mg_key_6,
    mg_key_5,
    mg_key_Equals,
    mg_key_9,
    mg_key_7,
    mg_key_Minus,
    mg_key_8,
    mg_key_0,
    mg_key_RightBracket,
    mg_key_O,
    mg_key_U,
    mg_key_LeftBracket,
    mg_key_I,
    mg_key_P,
    mg_key_Return,
    mg_key_L,
    mg_key_J,
    mg_key_Quote,
    mg_key_K,
    mg_key_Semicolon,
    mg_key_Backslash,
    mg_key_Comma,
    mg_key_Slash,
    mg_key_N,
    mg_key_M,
    mg_key_Period,
    mg_key_Tab,
    mg_key_Spacebar,
    mg_key_Grave,
    mg_key_Backspace,
    mg_key_NULL,
    mg_key_Escape,
    mg_key_RightOS,
    mg_key_LeftOS,
    mg_key_Shift,
    mg_key_CapsLock,
    mg_key_Alt,
    mg_key_Control,
    mg_key_RightShift,
    mg_key_RightAlt,
    mg_key_RightControl,
    mg_key_Function,
    mg_key_F17,
    mg_key_Decimal,
    mg_key_NULL,
    mg_key_Multiply,
    mg_key_NULL,
    mg_key_Add,
    mg_key_NULL,
    mg_key_Clear,
    mg_key_VolumeUp,
    mg_key_VolumeDown,
    mg_key_VolumeMute,
    mg_key_Divide,
    mg_key_Enter,
    mg_key_NULL,
    mg_key_Subtract,
    mg_key_F18,
    mg_key_F19,
    mg_key_Equals,
    mg_key_Numpad0,
    mg_key_Numpad1,
    mg_key_Numpad2,
    mg_key_Numpad3,
    mg_key_Numpad4,
    mg_key_Numpad5,
    mg_key_Numpad6,
    mg_key_Numpad7,
    mg_key_F20,
    mg_key_Numpad8,
    mg_key_Numpad9,
    mg_key_JISYen,
    mg_key_JISUnderscore,
    mg_key_JISNumpadComma,
    mg_key_F5,
    mg_key_F6,
    mg_key_F7,
    mg_key_F4,
    mg_key_F8,
    mg_key_F9,
    mg_key_JISEisu,
    mg_key_F11,
    mg_key_JISKana,
    mg_key_F13,
    mg_key_F16,
    mg_key_F14,
    mg_key_NULL,
    mg_key_F10,
    mg_key_NULL,
    mg_key_F12,
    mg_key_NULL,
    mg_key_F15,
    mg_key_Help,
    mg_key_Home,
    mg_key_PageUp,
    mg_key_Delete,
    mg_key_F4,
    mg_key_End,
    mg_key_F2,
    mg_key_PageDown,
    mg_key_F1,
    mg_key_LeftArrow,
    mg_key_RightArrow,
    mg_key_DownArrow,
    mg_key_UpArrow,
};

typedef struct {
    bool is_down;
    bool changed;
} mg_key;

mg_key all_the_keys[mg_NUM_KEYS];

///////////////////////////////////////////////////
///////////////////////////////////////////////////
#ifdef __APPLE__
///////////////////////////////////////////////////

int mgiGetKeyIndex(unsigned short keycode)
{
    return (mgiGlobalKeyMap[keycode]);
}

///////////////////////////////////////////////////
///////////////////////////////////////////////////
#elif defined _WIN32 || defined _WIN64
///////////////////////////////////////////////////
///////////////////////////////////////////////////

#define mgiGetKeyIndex(x) (x);

///////////////////////////////////////////////////
#endif
///////////////////////////////////////////////////
///////////////////////////////////////////////////

void mgiSetKeyDown(mg_key *key, bool is_down, bool changed)
{
    key->is_down = is_down;
    key->changed = changed;
}

void mgiResetKeys(void)
{
    int i = 0;
    while (i < mg_NUM_KEYS)
    {
        all_the_keys[i].changed = false;
        ++i;
    }
}

MGDEF bool	mg_update(void)
{
    mgiInitializeRequired();

    mgiResetKeys();
    mgiUpdateClock();
    @autoreleasepool
    {
        NSEvent *the_event;
        do
        {
            the_event = [NSApp nextEventMatchingMask: NSEventMaskAny
                                           untilDate: nil
                                              inMode: NSDefaultRunLoopMode
                                             dequeue: YES];
			// @NOTE Don't use processed for key events...
            bool processed = false;
            bool is_down = false;
            bool changed = false;
            switch ([the_event type])
            {
                case NSEventTypeKeyDown:
                {
                    is_down = true;
                    bool was_down = the_event.isARepeat;
                    changed = (is_down != was_down);
                    int key_index = mgiGetKeyIndex(the_event.keyCode);
                    mgiSetKeyDown(&all_the_keys[key_index], is_down, changed);
                } break;

                case NSEventTypeKeyUp:
                {
                    is_down = false;
                    bool changed = true;
                    int key_index = mgiGetKeyIndex(the_event.keyCode);
                    mgiSetKeyDown(&all_the_keys[key_index], is_down, changed);
                } break;

                default: break;
            }
            
            if (!processed)
            	[NSApp sendEvent: the_event];
        } while (the_event != nil);
    }
    return (mgiAppRunning());
}

MGDEF float mg_global_time(void)
{
    return (mgiGlobalTime);
}

// @MOVE_TO_C
MGDEF void	mg_clear(float r, float g, float b, float a)
{
    mgiInitializeRequired();

    glClearColor(r, g, b, a);
    glClear(GL_COLOR_BUFFER_BIT);
}

MGDEF void	mg_swap_buffers(void)
{
    mgiInitializeRequired();

    [mgiGlobalOpenGLContext flushBuffer];
}


MGDEF void	mg_cleanup(void)
{
    mgiInitializeRequired();
    // @TODO Implement this
    return ;
}

// @MOVE_TO_C
MGDEF void	mg_draw_quad(float x, float y, float width, float height,
                         float r, float g, float b, float a)
{
    mgiInitializeRequired();

    mgiQuadVertex m[4];
    memset(&m[0], 0, sizeof(mgiQuadVertex) * 4);

    mg__r32 half_width = width / 2.0f;
    mg__r32 half_height = height / 2.0f;

    m[0].position[0] = x - half_width;
    m[0].position[1] = y + half_height;

    m[1].position[0] = x - half_width;
    m[1].position[1] = y - half_height;

    m[2].position[0] = x + half_width;
    m[2].position[1] = y - half_height;

    m[3].position[0] = x + half_width;
    m[3].position[1] = y + half_height;

    m[1].uv[1] = m[2].uv[0] = m[2].uv[1] = m[3].uv[0] = 1.0f;

    for (int i = 0; i < 4; ++i)
    {
        m[i].color[0] = r;
        m[i].color[1] = g;
        m[i].color[2] = b;
        m[i].color[3] = a;
    }

    glUseProgram(mgiGlobalColorProgramId);
    glEnableVertexAttribArray(in_position);
    glEnableVertexAttribArray(in_uv);
    glEnableVertexAttribArray(in_color);
    mgiRendering2D(0);

    glBindBuffer(GL_ARRAY_BUFFER, mgiGlobalQuadVBO);
    glVertexAttribPointer(in_position, 3, GL_FLOAT, GL_FALSE,
                          sizeof(mgiQuadVertex),
                          (void *)offsetof(mgiQuadVertex, position));
    glVertexAttribPointer(in_uv, 2, GL_FLOAT, GL_FALSE,
                          sizeof(mgiQuadVertex),
                          (void *)offsetof(mgiQuadVertex, uv));
    glVertexAttribPointer(in_color, 4, GL_FLOAT, GL_FALSE,
                          sizeof(mgiQuadVertex),
                          (void *)offsetof(mgiQuadVertex, color));
    
    glBufferSubData(GL_ARRAY_BUFFER, 0, sizeof(mgiQuadVertex) * 4,
                    &m[0]);
    glDrawElements(GL_TRIANGLE_FAN, sizeof(mgiGlobalQuadIndices),
                   GL_UNSIGNED_BYTE, (void *)0);
    GLenum err;
    while ((err = glGetError()) != GL_NO_ERROR)
    {
        mgiDebugPrintf("GLError %d\n", err);
    }
    assert((err == GL_NO_ERROR));
}

// @MOVE_TO_C
MGDEF void mg_draw_textured_quad(GLuint texture_id, float x, float y,
                           float width, float height)
{
    mgiInitializeRequired();

    mgiQuadVertex m[4];
    memset(&m[0], 0, sizeof(mgiQuadVertex) * 4);

    mg__r32 half_width = width / 2.0f;
    mg__r32 half_height = height / 2.0f;

    m[0].position[0] = x - half_width;
    m[0].position[1] = y + half_height;

    m[1].position[0] = x - half_width;
    m[1].position[1] = y - half_height;

    m[2].position[0] = x + half_width;
    m[2].position[1] = y - half_height;

    m[3].position[0] = x + half_width;
    m[3].position[1] = y + half_height;

    m[1].uv[1] = m[2].uv[0] = m[2].uv[1] = m[3].uv[0] = 1.0f;

    // @NOTE Color is left a 0.0, 0.0, 0.0, 0.0

    glUseProgram(mgiGlobalTextureProgramId);
    glEnableVertexAttribArray(in_position);
    glEnableVertexAttribArray(in_uv);
    glEnableVertexAttribArray(in_color);
    mgiRendering2D(1);
    
    glBindTexture(GL_TEXTURE_2D, texture_id);

    glBindBuffer(GL_ARRAY_BUFFER, mgiGlobalQuadVBO);
    glVertexAttribPointer(in_position, 3, GL_FLOAT, GL_FALSE,
                          sizeof(mgiQuadVertex),
                          (void *)offsetof(mgiQuadVertex, position));
    glVertexAttribPointer(in_uv, 2, GL_FLOAT, GL_FALSE,
                          sizeof(mgiQuadVertex),
                          (void *)offsetof(mgiQuadVertex, uv));
    glVertexAttribPointer(in_color, 4, GL_FLOAT, GL_FALSE,
                          sizeof(mgiQuadVertex),
                          (void *)offsetof(mgiQuadVertex, color));
    
    glBufferSubData(GL_ARRAY_BUFFER, 0, sizeof(mgiQuadVertex) * 4,
                    &m[0]);
    glDrawElements(GL_TRIANGLE_FAN, sizeof(mgiGlobalQuadIndices),
                   GL_UNSIGNED_BYTE, (void *)0);

    GLenum err;
    while ((err = glGetError()) != GL_NO_ERROR)
    {
        mgiDebugPrintf("GLError %d\n", err);
    }
    assert((err == GL_NO_ERROR));
}

MGDEF bool	mg_get_dimensions(mg_dim_type_t type,
                                  size_t *width, size_t *height)
{
    mgiInitializeRequired();
    
    switch(type)
    {
        case MG_DIM_TYPE_VIEW:
        {
            *width = mgiGlobalViewWidth;
            *height = mgiGlobalViewHeight;
        } break;
        case MG_DIM_TYPE_SCREEN:
        {
            NSRect screen = [[NSScreen mainScreen] frame];
            *width = screen.size.width;
            *height = screen.size.height;
        } break;
        case MG_DIM_TYPE_WINDOW:
        {
            // @TODO Implement this
            *width = 0;
            *height = 0;
        } break;
        default:
        {
            mgiInvalidPath();
        };
    }
    return (true);
}


