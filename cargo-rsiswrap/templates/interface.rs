// Generated with rsiswrap
// model : {{name}}
{%- if has_ndarray %}
use nalgebra::SMatrix;
{%- endif %}
{%- macro write_struct(name, structdef) %}
#[derive(Default, Clone)]
{%- if structdef.is_generic %}
pub struct {{name}} <{{self::generics_join(structdef.generics)}}> {
{%- else %}
pub struct {{name}} {
{%- endif %}
{%- for f in structdef.fields %}
    {%- if f.is_specialized %}
        {%- if f.is_ndarray %}
    pub {{f.name}} : {{self::rust_dimstr(f.typename, f.dimension)}},
        {%- else %}
    pub {{f.name}} : {{f.typename}}<{{self::join_string(f.specialized)}}>,
        {%- endif %}
    {%- else if f.is_ndarray %}
    pub {{f.name}} : {{self::rust_dimstr(f.typename, f.dimension)}},
    {%- else %}
    pub {{f.name}} : {{f.typename}},
    {%- endif %}
{%- endfor %}
}
{%- endmacro %}

{% for s in structs %}
    {%- call write_struct(s, structinfo[s]) %}
{%- endfor %}
