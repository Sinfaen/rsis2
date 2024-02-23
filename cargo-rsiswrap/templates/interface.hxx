// Generated with rsiswrap
// model : {{name}}
#pragma once
#include <cstdint>
#include <string>

{%- macro write_struct(name, structdef) %}
class {{name}} {
public:
{%- for f in structdef.fields %}
    {%- if f.is_ndarray %}
    {{self::cpp_dimstr(f.typename, f.name, f.dimension)}};
    {%- else if f.is_struct %}
    {{f.typename}} {{f.name}};
    {%- else %}
    {{self::rust_to_cpp_type(f.typename)}} {{f.name}};
    {%- endif %}
{%- endfor %}
};
{%- endmacro %}

{% for s in structs %}
    {%- call write_struct(s, structinfo[s]) %}
{%- endfor %}
