extern crate rmodel;

use rmodel::{ConfigStatus, RunStatus};

/// ThreadContext
/// JRunner will autogenerate structs implementing this
/// trait for integration with the engine.
pub trait ThreadContext {
    /// Set the theaad id for this context
    fn set_tid(&mut self, id : usize) -> i32;

    /// Return the thread id for this context
    fn get_tid(&self) -> i32;

    /// Executes RModel::init
    fn init(&mut self) -> ConfigStatus;

    /// Executes a X minor frame of the simulation
    /// - Execute RModel::step X, given timing rules
    /// - Execute model connections
    /// - etc
    fn step(&mut self) -> RunStatus;

    /// Executes RModel::halt
    fn end(&mut self) -> i32;
}
