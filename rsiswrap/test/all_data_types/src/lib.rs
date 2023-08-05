pub mod all_data_types_interface;
use all_data_types_interface::*;

#[cfg(feature = "msgpack")]
pub mod all_data_types_msgpack;

extern crate rmodel;
use rmodel::*;

impl RModel for all_data_types {
    fn config(&mut self, _: &mut Box<dyn RFrameWork>) -> ConfigStatus {
        ConfigStatus::OK
    }
    fn init(&mut self, _: &mut Box<dyn RFrameWork>) -> ConfigStatus {
        println!("{} initialized", self.params.name);
        ConfigStatus::OK
    }
    fn step(&mut self, _: &mut Box<dyn RFrameWork>) -> RunStatus {
        self.output.measurement = self.input.signal as f32;
        RunStatus::OK
    }
    fn halt(&mut self, _: &mut Box<dyn RFrameWork>) -> RunStatus {
        RunStatus::OK
    }
}
