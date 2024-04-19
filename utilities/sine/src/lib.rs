// Sine Wave Generator model
// generic over <T>
// - f32
// - f64
pub mod sine_interface;
use sine_interface::*;

#[cfg(feature = "msgpack")]
pub mod sine_msgpack;

extern crate rmodel;
use rmodel::*;

impl RModel for sine<f32> {
    fn config(&mut self, _: &mut Box<dyn RFrameWork>) -> ConfigStatus {
        ConfigStatus::OK
    }
    fn init(&mut self, _: &mut Box<dyn RFrameWork>) -> ConfigStatus {
        self.input = self.params.clone();
        self.phase = 0.0;
        ConfigStatus::OK
    }
    fn step(&mut self, _: &mut Box<dyn RFrameWork>) -> RunStatus {
        // generate output
        self.output = self.input.amplitude * (self.phase + self.input.offset).sin() + self.input.bias;
        // update phase last
        self.phase += self.input.frequency;
        RunStatus::OK
    }
    fn halt(&mut self, _: &mut Box<dyn RFrameWork>) -> RunStatus {
        RunStatus::OK
    }
}

impl RModel for sine<f64> {
    fn config(&mut self, _: &mut Box<dyn RFrameWork>) -> ConfigStatus {
        ConfigStatus::OK
    }
    fn init(&mut self, _: &mut Box<dyn RFrameWork>) -> ConfigStatus {
        self.input = self.params.clone();
        self.phase = 0.0;
        ConfigStatus::OK
    }
    fn step(&mut self, _: &mut Box<dyn RFrameWork>) -> RunStatus {
        // generate output
        self.output = self.input.amplitude * (self.phase + self.input.offset).sin() + self.input.bias;
        // update phase last
        self.phase += self.input.frequency;
        RunStatus::OK
    }
    fn halt(&mut self, _: &mut Box<dyn RFrameWork>) -> RunStatus {
        RunStatus::OK
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn it_works() {
        assert_eq!(4, 4);
    }
}
