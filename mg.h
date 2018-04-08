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

  The main difference between MLX and MG is that the main control of
  your loop is put into the hands of MLX, and the API gives you
  specific "access points" or "hooks" into the running loop.
  While this works, and is easy to wrap your head around, it becomes a
  burden the moment you try to do something non-trivial.
  I believe the control should be in the hands of the person designing
  the app, not the graphics API. MG still maintains control of the
  OS message loop, but the user has control of the drawing loop.

  MG tries to mirror APIs which you will see when you code in the
  real world. It is a step in the direction of a library like SDL,
  but it remains simplified enough for beginners in graphics to get going
  quickly with minimal issues. It is cross platform, runs on
  OpenGL 3.2 Core for MacOS and Direct3D 11 on Windows. And it allows
  those who are adventurous to explore further into some of the more
  in-depth graphics features, like shaders.

  The three main focus points in developing MG are the following
  1) Allow users to make graphics projects without the library
  		getting in the way
  2) Provide a style of API that will be familiar when the user moves
  		to a more fully featured library
  3) Provide source that is easily reverse-engineered, so that
  		students can learn from it.

  MG does not attempt to teach how to interface with the operating system
  in any sort of 'proper' or 'recommended' way, it is merely designed
  for readability and usability above all else. It is also not meant to
  be a shippable api, i.e. it's for small to mid sized personal projects
  and learning, you should use something more robust when you become
  serious about a project.

  MLX mostly uses the concept of 'images' being sort of a solid construct,
  you can get and manipulate the image data, which is much faster than the
  'mlx_pixel_put' api, but there is a major problem with this method,
  that OpenGL doesn't really have the notion of an image, it has texture
  data, which is then mapped to some vertices which are set by the user,
  just like you would set vertices for a non-textured triangle.

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

#define MG_RESIZE_FULL   1
#define MG_RESIZE  (1 << 1)
#define MG_NO_RESIZE (1 << 2)
#define MG_RESIZE_DEFAULT (MG_RESIZE_FULL | MG_RESIZE)

#ifdef MG_STATIC
#define MGDEF static
#else
#define MGDEF extern
#endif

MGDEF int			mg_initialize(char *app_name);

MGDEF int			mg_open_window_with_name(char *name);
MGDEF int			mg_open_window_with_opts(mg_window_opts_t window);

MGDEF unsigned int	mg_load_texture(char *filename,
                                    int *width, int *height,
                                    unsigned char **data);
MGDEF void			mg_free_texture_data(unsigned char *data);
    
MGDEF bool			mg_get_dimensions(mg_dim_type_t type,
                                      size_t *width, size_t *height);

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

MGDEF void			mg_cleanup(void);

#ifdef __cplusplus
}
#endif
    
#endif
