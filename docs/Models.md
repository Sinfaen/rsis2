# Models
A model represents a unit of logic with defined inputs, outputs, and parameters. The mapping of your model to real-world characteristics

## Interface
Model interfaces are defined with TOML files using datatypes from Julia.

### Data Types
These are the primitive data types supported in all scenarios by RSIS.
| Primitive Julia Data Type | Rust Type |
| --- | --- |
| Bool | bool |
| Char | char |
| String | String |
| Int8 | i8 |
| Int16 | i16 |
| Int32 | i32 |
| Int64 | i64 |
| UInt8 | u8 |
| UInt16 | u16 |
| UInt32 | u32 |
| UInt64 | u64 |
| Float32 | f32 |
| Float64 | f64 |
| ComplexF32 | Complex32 |
| ComplexF64 | Complex64 |

The `Complex32` & `Complex64` types originate from the `num-complex` crate that is included in all models.

Future: `Rational{Int32}` & `Rational{Int64}` with the `num-rational` crate.

| Julia Container Type | Rust Type | Restriction(s) |
| --- | --- | --- |
| Dict{K, V} | HashMap&lt;K, V&gt; | Cannot be used as an input or output. K & V must be primitive types. |
| Vector{T} | Vec&lt;T&gt; | Cannot be used as an input or output. T must be a primitive type .|

### Dimensions
The `nalgebra` crate is used by RSIS for the `Matrix` type, restricting the dimension of matrices to 2.

TODO: conditionally bring in this crate only when a matrix exists within the interface definition.

## 

