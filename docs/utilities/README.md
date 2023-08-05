# Utility Models
The base set of models provided by RSIS for users.


## AffineTransform
TODO: Provides functionality for `y = ax + b`. Supports unit conversion, but is exposed for general usage.


| Parameter | Data | Default | Usage |
| --- | --- | --- | --- |
| Scale | `f64` | 1 | Scaling of the input |
| Bias | `f64` | 0 | Bias of the input |

## Clock
TODO: Implements a simplistic clock .

| Parameter | Data | Default | Usage |
| --- | --- | --- | --- |
| Start | `f64` | 0 | The value of the clock at sim start |
| Delta | `f64` | Thread delta | Output = internal tick * delta |
| Rollover | `f64` | -1 | If positive, the output is a modulo of the internal clock time and the rollover |

## Delay
TODO: Delays a signal by a static number of ticks or simulation time. This model is generic to support arbitrary input and output.

## Ethernet
TODO: Implements UDP, TCP.

## ODE
TODO: expose the `ode_solvers` crate.

## Signal
TODO: Implements a variety of simple signal types.


| Parameter | Data | Default | Usage |
| --- | --- | --- | --- |
| SignalType | `String` | `Sine` | Signal type to output |

| Supported Signals | Notes | Additional Parameters |
| --- | --- | --- |
| Sine | Sine wave | amplitude, frequency, phase |
| Cosine | Cosine wave | amplitude, frequency, phase |
| PWM | Pulse Width Modulation | amplitude, duty, phase |
| Sawtooth | Sawtooth wave | amplitude, peak |

## Switch
TODO: Multiple input, single output. Accepts an index to select which input is passed through to the output.

Generic to support arbitrary input port definitions.

| Parameter | Data | Default | Usage |
| --- | --- | --- | --- |
| NumPorts | `i32` | 2 | Number of input ports to select between |
| Saturate | `bool` | true | If true, clip the input index to a valid range. Otherwise, rollover the input. |