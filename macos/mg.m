
// @TODO Move all of the shared windows/macos functionality into mg.cpp

#include "mg.h"

#import <OpenGL/gl3.h>
#import "MacosPlatformInterface.h"
#import "MacosDebug.h"

#include <stdint.h>
#include <stddef.h>
#include <stdbool.h>
#include <mach/mach_time.h>

#include "default_shaders.h"

static GLuint	mgiFramebuffers[2] = {};
static GLuint	mgiFramebufferTextures[2] = {};
static GLuint	mgiFramebufferSizes[2][2] = {};
static GLenum	mgiDrawBuffers[1] = {GL_COLOR_ATTACHMENT0};
static int 		mgiCurrentFramebufferIndex = 0;

#define STB_IMAGE_IMPLEMENTATION
#define STBI_ONLY_BMP
#define STBI_ONLY_PNG
#define STB_IMAGE_STATIC
#include "support/stb_image.h"

typedef bool		mgi__bool;
typedef int8_t		mgi__s8;
typedef int32_t		mgi__s32;
typedef uint8_t		mgi__u8;
typedef uint32_t	mgi__u32;
typedef uint64_t	mgi__u64;
typedef float		mgi__r32;

typedef mach_timebase_info_data_t	mgi__tbi;

static mgi__bool	mgiInitialized = false;
static mgi__s32 	mgiGlobalViewWidth = 0;
static mgi__s32 	mgiGlobalViewHeight = 0;
static mgi__r32 	mgiGlobalAppScaleX;
static mgi__r32 	mgiGlobalAppScaleY;
static mgi__tbi 	mgiGlobalTimebaseInfo;

static NSOpenGLPixelFormat	*mgiGlobalOpenGLPixelFormat;
static NSOpenGLContext		*mgiGlobalOpenGLContext;

typedef enum	mgiShaderTypes_e
{
    MGI_COLOR_SHADER = 0,
    MGI_TEXTURE_SHADER,
    MGI_BLENDING_SHADER,
    MGI_NUM_SHADERS,
} 				mgiShaderTypes;

static GLuint	mgiGlobalShaderIds[MGI_NUM_SHADERS];
static GLuint	mgiGlobalColorProgramId;
static GLuint	mgiGlobalTextureProgramId;

static GLuint	mgiGlobalQuadVBO;
static GLuint	mgiGlobalQuadIndexBuffer;
static GLint	mgiProjectionUniforms[MGI_NUM_SHADERS];
static GLint	mgiTimeUniforms[MGI_NUM_SHADERS];
static mgi__r32	mgiGlobalTime = 0.0f;
static mgi__u8	mgiGlobalQuadIndices[6] = {0, 1, 2, 0, 2, 3};

typedef struct	mgiKeyInfo_s {
    bool	is_down;
    bool	changed;
}			   	mgiKeyInfo;

static mgiKeyInfo mgiGlobalKeyInfoArray[mg_NUM_KEYS];

// @NOTE Going with Windows virtual keys.
// MacOS can use this array to map keys to the windows vk codes
// Therefore, Windows doesn't need to use it, key codes line up to our enum
int mgiGlobalKeyMap[] = {
    mg_key_A, mg_key_S, mg_key_D, mg_key_F, mg_key_H, mg_key_G,
    mg_key_Z, mg_key_X, mg_key_C, mg_key_V, mg_key_ISOSection,
    mg_key_B, mg_key_Q, mg_key_W, mg_key_E, mg_key_R, mg_key_Y,
    mg_key_T, mg_key_1, mg_key_2, mg_key_3, mg_key_4, mg_key_6,
    mg_key_5, mg_key_Equals, mg_key_9, mg_key_7, mg_key_Minus,
    mg_key_8, mg_key_0, mg_key_RightBracket, mg_key_O, mg_key_U,
    mg_key_LeftBracket, mg_key_I, mg_key_P, mg_key_Return, mg_key_L,
    mg_key_J, mg_key_Quote, mg_key_K, mg_key_Semicolon, mg_key_Backslash,
    mg_key_Comma, mg_key_Slash, mg_key_N, mg_key_M, mg_key_Period,
    mg_key_Tab, mg_key_Spacebar, mg_key_Grave, mg_key_Backspace,
    mg_key_NULL, mg_key_Escape, mg_key_RightOS, mg_key_LeftOS,
    mg_key_Shift, mg_key_CapsLock, mg_key_Alt, mg_key_Control,
    mg_key_RightShift, mg_key_RightAlt, mg_key_RightControl,
    mg_key_Function, mg_key_F17, mg_key_Decimal, mg_key_NULL,
    mg_key_Multiply, mg_key_NULL, mg_key_Add, mg_key_NULL, mg_key_Clear,
    mg_key_VolumeUp, mg_key_VolumeDown, mg_key_VolumeMute, mg_key_Divide,
    mg_key_Enter, mg_key_NULL, mg_key_Subtract, mg_key_F18, mg_key_F19,
    mg_key_Equals, mg_key_Numpad0, mg_key_Numpad1, mg_key_Numpad2,
    mg_key_Numpad3, mg_key_Numpad4, mg_key_Numpad5, mg_key_Numpad6,
    mg_key_Numpad7, mg_key_F20, mg_key_Numpad8, mg_key_Numpad9,
    mg_key_JISYen, mg_key_JISUnderscore, mg_key_JISNumpadComma,
    mg_key_F5, mg_key_F6, mg_key_F7, mg_key_F4, mg_key_F8, mg_key_F9,
    mg_key_JISEisu, mg_key_F11, mg_key_JISKana, mg_key_F13, mg_key_F16,
    mg_key_F14, mg_key_NULL, mg_key_F10, mg_key_NULL, mg_key_F12,
    mg_key_NULL, mg_key_F15, mg_key_Help, mg_key_Home, mg_key_PageUp,
    mg_key_Delete, mg_key_F4, mg_key_End, mg_key_F2, mg_key_PageDown,
    mg_key_F1, mg_key_LeftArrow, mg_key_RightArrow, mg_key_DownArrow,
    mg_key_UpArrow,
};

// @SHAREABLE
#define mgiInitializeRequired() assert(mgiInitialized)
#define mgiInvalidPath() assert(0)

// @SHAREABLE
typedef struct	mgiQuadVertex_s
{
    mgi__r32 position[3];
    mgi__r32 uv[2];
    mgi__r32 color[4];
}				mgiQuadVertex;

// @SHAREABLE
typedef enum	mgiAttribLocation_e
{
    in_position = 0,
    in_uv,
    in_color,
}				mgiAttribLocation;

// @SHAREABLE
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

// @SHAREABLE
static mgi__bool		mgiShaderCompiledOkay(GLuint pid, GLuint vid, GLuint fid)
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
    static mgi__u64 last = 0;
    mgi__u64 now = mach_absolute_time();
    mgi__u64 nanoseconds;

    if (last == 0)
        last = now;
    mgiAbsolutetimeToNanoseconds(now - last, &nanoseconds);
    mgiGlobalTime += ((mgi__r32)nanoseconds * 1.0E-9);
    last = now;
}

static mgi__r32	mgiGetScreenDPI(void)
{
    mgi__r32 dpi;
    NSScreen *screen;
    
    screen = [NSScreen mainScreen];
    NSDictionary *description = [screen deviceDescription];
    NSSize displayPixelSize = [[description objectForKey:NSDeviceSize]
                                  sizeValue];
    CGSize displayPhysicalSize = CGDisplayScreenSize(
        [[description objectForKey:@"NSScreenNumber"] unsignedIntValue]);
    CGFloat backingScale = [screen backingScaleFactor];

    mgi__r32 pixelWidth = backingScale * displayPixelSize.width;
    mgi__r32 physicalWidth = (mgi__r32)displayPhysicalSize.width;

    dpi = (pixelWidth / physicalWidth) * 25.4f;
    return (dpi);
}

static mgi__bool	mgiAppRunning(void)
{
    mgiInitializeRequired();

    MGAppDelegate *delegate = [NSApp delegate];
    BOOL running = [delegate isRunning];
    return (running ? true : false);
}

// @SHAREABLE
static void	mgiRendering2D(mgi__s32 shader_index)
{
    mgi__r32 m[4][4];

    memset(m, 0, sizeof(mgi__r32) * 4 * 4);
    m[0][0] = 2.0f * mgiGlobalAppScaleX / (mgi__r32)mgiFramebufferSizes[mgiCurrentFramebufferIndex][0];
    m[3][0] = -1.0f * mgiGlobalAppScaleX;
    m[1][1] = 2.0f * mgiGlobalAppScaleY / (mgi__r32)mgiFramebufferSizes[mgiCurrentFramebufferIndex][1];
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


// @SHAREABLE
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

// @SHAREABLE
void mgiSetKeyDown(mgiKeyInfo *key, bool is_down, bool changed)
{
    key->is_down = is_down;
    key->changed = changed;
}

// @SHAREABLE
void mgiResetKeys(void)
{
    int i = 0;
    while (i < mg_NUM_KEYS)
    {
        mgiGlobalKeyInfoArray[i].changed = false;
        ++i;
    }
}

/////////////////////////////////////////////////////////////
// API BEGINS HERE
/////////////////////////////////////////////////////////////

// @SHAREABLE
MGDEF bool	mg_get_key_state(mg_key_code_t keycode,
                             unsigned int flag)
{
    if (!flag)
        flag = MG_KEY_STATE_DEFAULT;

    bool state = true;
    
    if (flag & MG_KEY_STATE_PRESSED)
        state = mgiGlobalKeyInfoArray[keycode].is_down;
    if ((flag & MG_KEY_STATE_CHANGED) && state)
        state = mgiGlobalKeyInfoArray[keycode].changed;

    return (state);
}
MGDEF void	mg_additive_blending(void)
{
    glBlendFunc(GL_SRC_ALPHA, GL_ONE);
}

MGDEF void	mg_alpha_blending(void)
{
    glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
}


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

        // COLOR SHADER
        mgiGlobalShaderIds[MGI_COLOR_SHADER] = mgiCompileShader(shader_source_vertex,
                                                                        shader_source_fragment,
                                                                        &vertex_id,
                                                                        &fragment_id);
        assert(mgiShaderCompiledOkay(mgiGlobalShaderIds[MGI_COLOR_SHADER], vertex_id, fragment_id));
        mgiProjectionUniforms[MGI_COLOR_SHADER] = glGetUniformLocation(mgiGlobalShaderIds[MGI_COLOR_SHADER], "in_projection");
        mgiTimeUniforms[MGI_COLOR_SHADER] = glGetUniformLocation(mgiGlobalShaderIds[MGI_COLOR_SHADER], "in_time");

        // TEXTURE SHADER
        mgiGlobalShaderIds[MGI_TEXTURE_SHADER] = mgiCompileShader(shader_source_vertex,
                                               tex_shader_source_fragment,
                                               &vertex_id, &fragment_id);
        assert(mgiShaderCompiledOkay(mgiGlobalShaderIds[MGI_TEXTURE_SHADER], vertex_id, fragment_id));
        mgiProjectionUniforms[MGI_TEXTURE_SHADER] = glGetUniformLocation(mgiGlobalShaderIds[MGI_TEXTURE_SHADER], "in_projection");
        mgiTimeUniforms[MGI_TEXTURE_SHADER] = glGetUniformLocation(mgiGlobalShaderIds[MGI_TEXTURE_SHADER], "in_time");

        // BLENDING SHADER
        mgiGlobalShaderIds[MGI_BLENDING_SHADER] = mgiCompileShader(shader_source_vertex,
                                                                           blending_tex_shader_source_fragment,
                                                                           &vertex_id, &fragment_id);
        assert(mgiShaderCompiledOkay(mgiGlobalShaderIds[MGI_BLENDING_SHADER], vertex_id, fragment_id));
        mgiProjectionUniforms[MGI_BLENDING_SHADER] = glGetUniformLocation(mgiGlobalShaderIds[MGI_BLENDING_SHADER], "in_projection");
        mgiTimeUniforms[MGI_BLENDING_SHADER] = glGetUniformLocation(mgiGlobalShaderIds[MGI_BLENDING_SHADER], "in_time");
    }

    GLuint opengl_is_dumb_vao;
    glGenVertexArrays(1, &opengl_is_dumb_vao);
    glBindVertexArray(opengl_is_dumb_vao);
    
    mgi__r32 dpi = mgiGetScreenDPI();
    mgiGlobalAppScaleX = dpi / 96.0f;
    mgiGlobalAppScaleY = dpi / 96.0f;

    glGenBuffers(1, &mgiGlobalQuadIndexBuffer);
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, mgiGlobalQuadIndexBuffer);
    glBufferData(GL_ELEMENT_ARRAY_BUFFER, sizeof(mgi__u8) * 6,
                 &mgiGlobalQuadIndices[0], GL_STREAM_DRAW);

    glGenBuffers(1, &mgiGlobalQuadVBO);
    glBindBuffer(GL_ARRAY_BUFFER, mgiGlobalQuadVBO);
    mgiQuadVertex m[4];
    memset(&m[0], 0, sizeof(mgiQuadVertex) * 4);
    glBufferData(GL_ARRAY_BUFFER, 4 * sizeof(mgiQuadVertex), &m[0], GL_STREAM_DRAW);

    glEnable(GL_BLEND);
    mg_alpha_blending();

    assert((glGetError() == 0));
    
    mgiDebugPrintLine("MiniLibGraphics Initialized...");
    mgiInitialized = true;
    
	return (1);
}


MGDEF int	mg_open_window_with_opts(mg_window_opts_t opts)
{
    mgiInitializeRequired();
    
    mgi__u32 style_mask = NSWindowStyleMaskTitled
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
    mgiFramebufferSizes[0][0] = width;
    mgiFramebufferSizes[0][1] = height;
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

// @SHAREABLE
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
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
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

// @SHAREABLE
MGDEF void			mg_free_texture_data(unsigned char *data)
{
    free(data);
}

// @NOTE Returns the index of the framebuffer created.
// @TODO Add a mgi_max_num_framebuffers & mgi_last_framebuffer_index
MGDEF int mg_create_framebuffer(int width, int height)
{
    glGenFramebuffers(1, &mgiFramebuffers[1]);
    glBindFramebuffer(GL_FRAMEBUFFER, mgiFramebuffers[1]);
    
    mgiFramebufferSizes[1][0] = width;
    mgiFramebufferSizes[1][1] = height;
    
    glGenTextures(1, &mgiFramebufferTextures[1]);
    glBindTexture(GL_TEXTURE_2D, mgiFramebufferTextures[1]);

    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glTexImage2D(GL_TEXTURE_2D,
                 0,
                 GL_RGBA8,
                 width,
                 height,
                 0,
                 GL_RGBA,
                 GL_UNSIGNED_BYTE,
                 NULL);
    glFramebufferTexture2D(GL_FRAMEBUFFER,
                           GL_COLOR_ATTACHMENT0,
                           GL_TEXTURE_2D,
                           mgiFramebufferTextures[1], 0);

    // Set the list of draw buffers.
    glDrawBuffers(1, mgiDrawBuffers); // "1" is the size of DrawBuffers

    assert(glCheckFramebufferStatus(GL_FRAMEBUFFER)
           == GL_FRAMEBUFFER_COMPLETE);

    glBindFramebuffer(GL_FRAMEBUFFER, 0);

    return (1);
}

MGDEF void mg_set_framebuffer(int framebuffer_index)
{
    static int game_viewport[4] = {};
    if (mgiCurrentFramebufferIndex == 0)
    {
        glGetIntegerv(GL_VIEWPORT, game_viewport);
    }
    glBindFramebuffer(GL_FRAMEBUFFER,
                      mgiFramebuffers[framebuffer_index]);
    if (framebuffer_index != 0)
    {
        glViewport(0, 0, mgiFramebufferSizes[framebuffer_index][0],
                   mgiFramebufferSizes[framebuffer_index][1]);
    }
    else
    {
        glViewport(game_viewport[0],
                   game_viewport[1],
                   game_viewport[2],
                   game_viewport[3]);
    }
    mgiCurrentFramebufferIndex = framebuffer_index;
}

MGDEF unsigned int mg_get_framebuffer_texture_id(int framebuffer_index)
{
    return (mgiFramebufferTextures[framebuffer_index]);
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
                    mgiSetKeyDown(&mgiGlobalKeyInfoArray[key_index],
                                  is_down, changed);
                } break;

                case NSEventTypeKeyUp:
                {
                    is_down = false;
                    bool changed = true;
                    int key_index = mgiGetKeyIndex(the_event.keyCode);
                    mgiSetKeyDown(&mgiGlobalKeyInfoArray[key_index],
                                  is_down, changed);
                } break;

                default: break;
            }
            
            if (!processed)
            	[NSApp sendEvent: the_event];
        } while (the_event != nil);
    }
    return (mgiAppRunning());
}

// @SHAREABLE
MGDEF float mg_global_time(void)
{
    return (mgiGlobalTime);
}

// @SHAREABLE
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

// @SHAREABLE
MGDEF void	mg_draw_quad(float x, float y, float width, float height,
                         float r, float g, float b, float a)
{
    mgiInitializeRequired();

    mgiQuadVertex m[4];
    memset(&m[0], 0, sizeof(mgiQuadVertex) * 4);

    mgi__r32 half_width = width / 2.0f;
    mgi__r32 half_height = height / 2.0f;

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

    glUseProgram(mgiGlobalShaderIds[MGI_COLOR_SHADER]);
    glEnableVertexAttribArray(in_position);
    glEnableVertexAttribArray(in_uv);
    glEnableVertexAttribArray(in_color);
    mgiRendering2D(MGI_COLOR_SHADER);

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

MGDEF void mg_draw_textured_quad_with_uv(GLuint texture_id, float x, float y,
                                         float width, float height, float uv0[2], float uv1[2], float uv2[2], float uv3[2])
{
    mgiInitializeRequired();

    mgiQuadVertex m[4];
    memset(&m[0], 0, sizeof(mgiQuadVertex) * 4);

    mgi__r32 half_width = width / 2.0f;
    mgi__r32 half_height = height / 2.0f;

    m[0].position[0] = x - half_width;
    m[0].position[1] = y + half_height;

    m[1].position[0] = x - half_width;
    m[1].position[1] = y - half_height;

    m[2].position[0] = x + half_width;
    m[2].position[1] = y - half_height;

    m[3].position[0] = x + half_width;
    m[3].position[1] = y + half_height;

    m[0].uv[0] = uv0[0];
    m[0].uv[1] = uv0[1];

    m[1].uv[0] = uv1[0];
    m[1].uv[1] = uv1[1];

    m[2].uv[0] = uv2[0];
    m[2].uv[1] = uv2[1];

    m[3].uv[0] = uv3[0];
    m[3].uv[1] = uv3[1];

    // @NOTE Color is left a 0.0, 0.0, 0.0, 0.0

    glUseProgram(mgiGlobalShaderIds[MGI_TEXTURE_SHADER]);
    glEnableVertexAttribArray(in_position);
    glEnableVertexAttribArray(in_uv);
    glEnableVertexAttribArray(in_color);
    mgiRendering2D(MGI_TEXTURE_SHADER);
    
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

// @SHAREABLE
MGDEF void mg_draw_textured_quad(GLuint texture_id, float x, float y,
                           float width, float height)
{    
    float uv0[] = {0, 0};
    float uv1[] = {0, 1};
    float uv2[] = {1, 1};
    float uv3[] = {1, 0};
    mg_draw_textured_quad_with_uv(texture_id, x, y, width, height,
                                  uv0, uv1, uv2, uv3);
}

MGDEF void mg_draw_textured_quad_with_color(GLuint texture_id,
                                            float x, float y,
                                            float width, float height,
                                            float r, float g,
                                            float b, float a)
{
    mgiInitializeRequired();

// @TODO This can totally be factored out...
// These draw functions are nearly identical
    mgiQuadVertex m[4];
    memset(&m[0], 0, sizeof(mgiQuadVertex) * 4);

    mgi__r32 half_width = width / 2.0f;
    mgi__r32 half_height = height / 2.0f;

    m[0].position[0] = x - half_width;
    m[0].position[1] = y + half_height;

    m[1].position[0] = x - half_width;
    m[1].position[1] = y - half_height;

    m[2].position[0] = x + half_width;
    m[2].position[1] = y - half_height;

    m[3].position[0] = x + half_width;
    m[3].position[1] = y + half_height;

    m[1].uv[1] = m[2].uv[0] = m[2].uv[1] = m[3].uv[0] = 1.0;
    
    for (int i = 0; i < 4; ++i)
    {
        m[i].color[0] = r;
        m[i].color[1] = g;
        m[i].color[2] = b;
        m[i].color[3] = a;
    }
    
    glUseProgram(mgiGlobalShaderIds[MGI_BLENDING_SHADER]);
    glEnableVertexAttribArray(in_position);
    glEnableVertexAttribArray(in_uv);
    glEnableVertexAttribArray(in_color);
    mgiRendering2D(MGI_BLENDING_SHADER);
    
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

MGDEF void *mg_memory_arena_push_size(mg_memory_arena_t *arena, size_t size)
{
    void *res;

    assert(arena->used + size < arena->size);
    res = arena->base + arena->used;
    arena->used += size;
    return (res);
}

MGDEF void	mg_destroy_memory_arena(mg_memory_arena_t *arena)
{
    arena->used = 0;
    munmap(arena->base, arena->size);
    arena->size = 0;
}

MGDEF void	mg_get_memory_arena(mg_memory_arena_t *arena, size_t size)
{
    void *base_address = (void *)(0);
    unsigned long long total_size = size;
    arena->used = 0;
    arena->size = total_size;
    arena->base = mmap(base_address, total_size,
                       PROT_READ | PROT_WRITE,
                       MAP_ANON | MAP_PRIVATE,
                       -1, 0);
    assert(arena->base);
}
