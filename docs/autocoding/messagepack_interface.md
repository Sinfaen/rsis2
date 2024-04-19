# MessagePack Model Interface
This document details the internal API that the Julia wrapper uses to interface with models.

## Overview
The MessagePack interface is gated behind a named rust feature called `msgpack`. Enabled by default, `cargo-rsiswrap` will generate `<model>_msgpack.rs`. This file contains:
- `<struct>_from_msgpack` functions
- `<struct>_to_msgpack` functions

These functions can be generic.

To simplify the interface between the Julia wrapper and the generated library, all IO is piped through the wrapper layer with generated calls to pass MessagePack data to the correct location.

## Indexing
A 0-based integer indexing scheme is used to refer to each element of the model interface.

## Example
```rust
pub struct example {
    pub input : example_in,      // Index [0]
    put output : example_out,    // Index [1]
    pub data : example_wk,       // Index [2]
    pub params : example_params, // Index [3]
}
pub struct example_wk {
    pub flag : bool,     // Index [0]
    pub val : Vec<f32?>, // Index [1]
    pub more : [char; 3],// Index [2]
}
```

Starting from the `example` struct, `more` would be indexed as `[2, 3]`.
