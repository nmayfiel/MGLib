#ifndef DEBUG_H
# define DEBUG_H

#ifdef NDEBUG

#define mgiDebugPrintLine(x)
#define mgiDebugPrintf(fmt, ...)
#define mgiDebugPrintShaderError(x, y)

#else

#define mgiDebugPrintLine(x) printf("%s\n", x)
#define mgiDebugPrintf(fmt, ...) printf(fmt, __VA_ARGS__)
#define mgiDebugPrintShaderError(x, y) debug_print_shader_error(x, y)

void debug_print_shader_error(int vertex_id, int fragment_id);

#endif

#endif
