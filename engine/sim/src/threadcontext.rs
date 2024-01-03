extern crate rmodel;

use rmodel::{ConfigStatus, RunStatus};

#[derive(Default)]
pub struct ThreadTime {
    pub delta : f64,
    pub tick : i64,
}

/// ThreadContext
/// JRunner will autogenerate structs implementing this
/// trait for integration with the engine.
pub trait ThreadContext {
    /// Set the simulation time of this thread
    fn set_time(&mut self, new_time : ThreadTime) -> ConfigStatus;

    /// Get read-only time of this thread
    fn get_time(&self) -> ThreadTime;

    /// Set the theaad id for this context
    fn set_tid(&mut self, id : usize) -> ConfigStatus;

    /// Return the thread id for this context
    fn get_tid(&self) -> usize;

    /// Executes RModel::init
    fn init(&mut self) -> ConfigStatus;

    /// Executes a X minor frame of the simulation
    /// - Execute RModel::step X, given timing rules
    /// - Execute model connections
    /// - etc
    fn step(&mut self) -> RunStatus;

    /// Executes RModel::halt
    fn end(&mut self) -> RunStatus;
}
