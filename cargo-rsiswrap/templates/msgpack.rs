// Generated with rsiswrap
// model : {{name}}
{%- for imp in imports %}
use {{imp}};
{%- endfor %}
{%- if has_ndarray %}
use nalgebra::SMatrix;
{%- endif %}

use rmp_serde::encode::Error;
use serde::{Deserialize, Serialize};
use crate::{{name}}_interface::*;

{%- macro write_from_mp(name, structdef) %}
{%- if structdef.is_generic %}
pub fn {{name}}_from_msgpack<{{self::generics_deserialize(structdef.generics)}}>(obj: &mut {{name}}<{{self::generics_join(structdef.generics)}}>, mp: &[u8], ind: &[i32]) -> i32 {
{%- else %}
pub fn {{name}}_from_msgpack(obj: &mut {{name}}, mp: &[u8], ind: &[i32]) -> i32 {
{%- endif %}
    if ind.len() == 0 { return 1; }
    match ind[0] {
    {%- for f in structdef.fields %}
        {%- if f.is_struct %}
        {{loop.index0}} => return {{f.typename}}_from_msgpack(&mut obj.{{f.name}}, mp, &ind[1..]),
        {%- else %}
        {{loop.index0}} => { obj.{{f.name}} = rmp_serde::from_slice(mp).unwrap(); },
        {%- endif %}
    {%- endfor %}
        _ => return 2,
    }
    0
}
{%- endmacro %}

{%- macro write_to_mp(name, structdef) %}
{%- if structdef.is_generic %}
pub fn {{name}}_to_msgpack<T: Serialize>(obj: &mut {{name}}<{{self::generics_join(structdef.generics)}}>, ind: &[i32]) -> Result<Vec<u8>, Error> {
{%- else %}
pub fn {{name}}_to_msgpack(obj: &mut {{name}}, ind: &[i32]) -> Result<Vec<u8>, Error> {
{%- endif %}
    match ind[0] {
    {%- for f in structdef.fields %}
        {%- if f.is_struct %}
        {{loop.index0}} => {{f.typename}}_to_msgpack(&mut obj.{{f.name}}, &ind[1..]),
        {%- else %}
        {{loop.index0}} => rmp_serde::to_vec(&obj.{{f.name}}),
        {%- endif %}
    {%- endfor %}
        _ => return Err(Error::Syntax("RSIS > index exceeded length".to_string())),
    }
}
{%- endmacro %}

{% for s in structs %}
    {%- call write_from_mp(s, structinfo[s]) %}
    {%- call write_to_mp(s, structinfo[s]) %}
{%- endfor %}