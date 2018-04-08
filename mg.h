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
