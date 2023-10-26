
#[derive(Copy,Clone,PartialEq)]
pub enum EngineState {
    CONFIG       = 0,
    INITIALIZING = 1,
    INITIALIZED  = 2,
    RUNNING      = 3,
    PAUSED       = 4,
    ENDING       = 5,
    ENDED        = 6,
    ERRORED      = 7,
}
