# Memory Tables TODO
Memory Tables are a built-in feature supporting model parameterization in a form that is independent from any specific model. Memory Tables are statically defined sets of parameters, exposed in a struct-like format for models to access.

They are defined with the same IDL format that is used to define models, but with a restricted syntax.

```toml
# Example table IDL
name = "DroneTable"
desc = "Stores drone configuration that can be uploaded during flight"

[types.drone_data]
_meta = {tag = "root" } # this struct is the root level
ipAddr = {type="String", value="192.168.0.1", desc="IP address"}
uniqueId = {type="Int32", value=1, desc="Unique ID of this drone"}
targetWaypoint = {type="Float64", value=[0,0], dims=[2], desc="Latitude & Longitude of destination"}
targetAltitude = {type="Float64", value=100, unit="m", desc="Designated altitude for cruise"}
```

## Features
### Multiple Buffer
Multiple buffers for the same memory table can be loaded at the same time. Only one version is active at any time, designated the **active** table. **Inactive** tables can also be read/written to, allowing for background updates.

Switching the **active** table is designed to be a O(1) operation. This feature is designed to support simulation of table uploads that occur over many cycles, with an immediate switch between table versions when the upload is finished.

### Serialization
Memory Tables can be serialized/deserialized from file. There are multiple supported formats. Allowing for user-defined formats is a future goal.

### Thread-Safety
TODO

## Underlying Formats
There are multiple underlying formats supported by RSIS, independent of the IDL definition of the table.

| Form | Details  |
| --- | --- |
| Binary | The data is represented in the form of a `struct` that can be memory-mapped from file. |
| MessagePack | The data is stored in MessagePack. |
| JSON | The data is stored as a compactified JSON string. |
