#[repr(u32)]
pub enum ConfigStatus {
    OK,
    ERR,
    CONTINUE,
}

#[repr(u32)]
pub enum RunStatus {
    OK,
    ERR,
    STOP,
}

/// RFramework
/// Exposes the RSIS framework for every RModel.
/// Each thread should have its own RFramework object
pub trait RFrameWork {
    fn get_time(&self) -> f64;
    fn get_tick(&self) -> i64;
    fn get_tdelta(&self) -> f64;
}

/// RModel
/// All models should implement this trait for integration
/// into the RSIS framework.
pub trait RModel {
    /// Hook is called when a model configuration update is called
    fn config(&mut self, _: &mut Box<dyn RFrameWork>) -> ConfigStatus;

    /// Hook is called minimum of once during RSIS scenario initialization
    fn init(&mut self, _: &mut Box<dyn RFrameWork>) -> ConfigStatus;

    /// Hook is called to update the outputs of the model
    fn step(&mut self, _: &mut Box<dyn RFrameWork>) -> RunStatus;

    /// Hook is called upon termination of the model
    fn halt(&mut self, _: &mut Box<dyn RFrameWork>) -> RunStatus;
}
