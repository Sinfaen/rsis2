
use crate::state::EngineState;
use crate::threadcontext::ThreadContext;

/// Engines present an API 
pub trait Engine {
    //fn set_thread(&mut self, tc : Box<dyn ThreadContext + Send>, ind : usize) -> i32;
    fn get_state(&self) -> EngineState;

    fn init(&mut self) -> i32;
    fn step(&mut self, steps: usize) -> i32;
    fn pause(&mut self) -> i32;
    fn end(&mut self) -> i32;
}
