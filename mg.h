/*
  MGLib

  NAME
  MGLib - A Miniature Graphics Library

  SYNOPSIS
  #include <mg.h>

  int mg_initialize(char *app_name);
  
  DESCRIPTION
  At it's core, MGLib is a platform layer.
 */


/*
** MiniGraphics Library
** By: Nick Mayfield
*/

#ifndef MG_H
 #define MG_H

#include <stddef.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct	mg_memory_arena_s
{
    size_t			size;
    size_t			used;
    unsigned char	*base;
}				mg_memory_arena_t;
    
typedef struct	mg_window_opts_s
{
	char			*name;
	size_t			width;
	size_t			height;
	unsigned int	position_x;
	unsigned int	position_y;
	unsigned int	resize_flags;
}				mg_window_opts_t;

typedef enum 	mg_dim_type_e
{
    MG_DIM_TYPE_VIEW,
    MG_DIM_TYPE_SCREEN,
    MG_DIM_TYPE_WINDOW,
}				mg_dim_type_t;

typedef enum	mg_key_code_e {
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
    mg_key_Packet		=	0xE7, // @TODO check if this might be useful!
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
}				mg_key_code_t;

#define MG_KEY_STATE_PRESSED    1
#define MG_KEY_STATE_CHANGED	(1 << 1)
#define MG_KEY_STATE_DEFAULT	(MG_KEY_STATE_PRESSED | MG_KEY_STATE_CHANGED)
    
#define MG_RESIZE_FULL   	1
#define MG_RESIZE			(1 << 1)
#define MG_NO_RESIZE		(1 << 2)
#define MG_RESIZE_DEFAULT	(MG_RESIZE_FULL | MG_RESIZE)
    
#ifdef MG_STATIC
#define MGDEF static
#else
#define MGDEF extern
#endif
    
MGDEF int			mg_initialize(const char *app_name);

MGDEF int			mg_open_window_with_name(const char *name);
MGDEF int			mg_open_window_with_opts(mg_window_opts_t window);

MGDEF int			mg_create_framebuffer(int width, int height);
MGDEF void			mg_set_framebuffer(int fb_index);
MGDEF unsigned int	mg_get_framebuffer_texture_id(int fb_index);

MGDEF unsigned int	mg_load_texture(const char *filename,
                                    int *width, int *height,
                                    unsigned char **data);
MGDEF void			mg_free_texture_data(unsigned char *data);
    
MGDEF bool			mg_get_dimensions(mg_dim_type_t type,
                                      size_t *width, size_t *height);
MGDEF bool			mg_get_key_state(mg_key_code_t keycode,
                                    unsigned int flag);

MGDEF bool			mg_update(void);
MGDEF float			mg_global_time(void);
MGDEF void			mg_clear(float r, float g, float b, float a);
MGDEF void			mg_swap_buffers(void);

MGDEF void			mg_draw_quad(float x, float y,
                                 float width, float height,
                                 float r, float g, float b, float a);
MGDEF void 			mg_draw_textured_quad(unsigned int texture_id,
                                          float x, float y,
                                          float width, float height);

MGDEF void 			mg_draw_textured_quad_with_uv(unsigned int texture_id,
    											  float x, float y,
    											  float width, float height,
                                                  float uv0[2],
                                                  float uv1[2],
                                                  float uv2[2],
                                                  float uv3[2]);
    
MGDEF void			mg_draw_textured_quad_with_color(unsigned int texture_id,
                                                     float x, float y,
                                                     float width,
                                                     float height,
                                                     float r, float g,
                                                     float b, float a);
MGDEF void mg_additive_blending(void);
MGDEF void mg_alpha_blending(void);

MGDEF void mg_get_memory_arena(mg_memory_arena_t *arena, size_t size);
MGDEF void mg_destroy_memory_arena(mg_memory_arena_t *arena);

#define mg_memory_arena_push_size(arena, size) mg__push_size(arena, size)
#define mg_memory_arena_push_array(arena, count, type) (type *)mg__push_size(arena, ((count) * sizeof(type)))
#define mg_memory_arena_push_struct(arena, type) (type *)mg__push_size(arena, sizeof(type))
MGDEF void *mg__push_size(mg_memory_arena_t *arena, size_t size);
    
MGDEF void			mg_cleanup(void);

#ifdef __cplusplus
}
#endif
    
#endif
