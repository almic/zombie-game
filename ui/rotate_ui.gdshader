shader_type canvas_item;
render_mode skip_vertex_transform;

uniform float rotation;
uniform vec2 pivot;
uniform vec2 size;

void vertex()
{
    VERTEX -= size * pivot;

    VERTEX = mat2(vec2(cos(-rotation), -sin(-rotation)),
                  vec2(sin(-rotation),  cos(-rotation))
             ) * VERTEX;

    VERTEX = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;

    VERTEX += size * pivot;
}
