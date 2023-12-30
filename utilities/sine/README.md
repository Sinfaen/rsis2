# Sine
Dyamic sine wave generator.

## Parameterz
The `sine` model exposes the following default parameters:

| Name | DataType | Default | Symbol | Description |
| --- | --- | --- | --- | --- |
| Amplitude | Float64 | 1.0 | -- | Maximum amplitude |
| Frequency | Float64 | 1.0 | f | Frequency in Hz |
| Offset | Float64 | 0.0 | $ϕ_0$ | Initial phase offset |

## Implementation
Amplitude, frequency, duty, and bias are inputs to the waveform model. On initialization, the parameters of the same name are copied to their respective inputs. These values are exposed as inputs to allow for run-time modification, allowing for setup of complex behavior.

All implementations use differential logic, so as to prevent issues with floating point precision for long running simulations. All implementations rely on a constant timestep, `Δt`.

## Sine
Internal States:
- `ϕ`
    - phase angle

Init:
- $ϕ = ϕ_0 \medspace mod \medspace 1$

Step:
- $ϕ_{n+1} = ϕ_n + 2πf*Δt$
- $ϕ_{n+1} = ϕ_{n+1} \medspace mod \medspace 1$
- $signal = A sin(ϕ) + b$

## Rectangle
Internal States:
- `ϕ`
    - phase angle

Init:
- $ϕ = ϕ_0$

Step:
- $ϕ_{n+1} = ϕ_n + f*Δt$
- $ϕ_{n+1} = ϕ_{n+1} \medspace mod \medspace 1$
- $signal = A*sgn(D - ϕ) + b$

## Triangle
Internal States:
- `ϕ`
    - phase angle

Init:
- $ϕ = ϕ_0 \medspace mod \medspace 1$

Step:
- $ϕ_{n+1} = ϕ_n + f*Δt$
- $ϕ_{n+1} = ϕ_{n+1} \medspace mod \medspace 1$
- if $ϕ_{n+1} < D$
    - $signal = A\frac{ϕ_{n+1}}{D} + b$
- if $ϕ_{n+1} == D$
    - $signal = A + b$
- if $ϕ_{n+1} > D$
    - $signal = ϕ_{n+1} + b$