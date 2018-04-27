
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

MGDEF bool	mg_update(void)
{
    mgiInitializeRequired();

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


