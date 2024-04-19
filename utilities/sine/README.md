# Sine
> sine{T}  
> T ∈ (Float32, **Float64**).

Sinusoidal wave generator.

## Parameters
| Name | DataType | Default | Symbol | Description |
| --- | --- | --- | --- | --- |
| Amplitude | T | 1.0 | A | Maximum amplitude |
| Frequency | T | 1.0 | f | Frequency in Hz |
| Offset | T | 0.0 | $ϕ_0$ | Phase offset |
| Bias | T | 0.0 | B | Bias offset |

## Implementation
The parameters are duplicated as inputs to the sine model. On initialization, the parameters are copied to their respective inputs. These values are exposed as inputs to allow for run-time modification via the outputs of other models.

The model uses differential logic to prevent issues with floating point precision for long running simulations. All implementations rely on a constant timestep, `Δt`.

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
- $signal = A*sgn(D - ϕ) + B$
