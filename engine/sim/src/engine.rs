
use crate::state::EngineState;

/// Engines present an API 
pub trait Engine {
    fn get_state(&self) -> EngineState;

    fn init(&mut self) -> i32;
    fn step(&mut self, steps: u64) -> i32;
    fn pause(&mut self) -> i32;
    fn end(&mut self) -> i32;
}
