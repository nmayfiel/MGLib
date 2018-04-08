

#include <stdio.h>
#include <stdlib.h>
#include "MacosDebug.h"
#include <OpenGL/gl3.h>


void debug_print_shader_error(GLint vertex_id, GLint fragment_id)
{
    GLsizei len;
    glGetShaderiv(vertex_id, GL_INFO_LOG_LENGTH, &len);
    if (len > 0)
    {
        GLchar *verterr = (GLchar *)malloc(sizeof(GLchar) * (len + 1));
        glGetShaderInfoLog(vertex_id, len + 1, 0, verterr);
        mgiDebugPrintLine(verterr);
        free(verterr);
    }

    glGetShaderiv(fragment_id, GL_INFO_LOG_LENGTH, &len);
    if (len > 0)
    {
        GLchar *fragerr = (GLchar *)malloc(sizeof(GLchar) * (len + 1));
        glGetShaderInfoLog(fragment_id, len + 1, 0, fragerr);
        mgiDebugPrintLine(fragerr);
        free(fragerr);
    }
}
