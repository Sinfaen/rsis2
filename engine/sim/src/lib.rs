
extern crate libc;

mod state;
mod engine;
mod threadcontext;

use crate::state::EngineState;
use crate::engine::Engine;
use crate::threadcontext::{ThreadContext};

use std::{thread, time};
use std::time::{Instant, Duration};
use std::sync::{Arc, Barrier, mpsc, mpsc::TryRecvError, mpsc::Receiver, mpsc::Sender, Mutex};

use rmodel::{ConfigStatus, RunStatus};

#[derive(Debug)]
pub struct ThreadComms {
    pub handle : thread::JoinHandle<()>,
    pub tx : Sender<ThreadCommand>,
    pub rx : Receiver<ThreadResult>,
}

pub struct SimEngine<const N: usize> {
    pub soft_real_time : bool, // if true enable soft real-time behavior
    pub state : Arc<Mutex<EngineState>>,

    // trying to remove as much dynamic allocation as possible
    // unsure how to get around using Box
    pub barrier : Arc<Barrier>,

    pub runner : thread::JoinHandle<()>,
    pub runner_tx : Sender<ThreadCommand>,
    pub runner_rx : Receiver<ThreadResult>,
}

#[derive(PartialEq)]
pub enum ThreadCommand {
    INIT,
    EXECUTE(u64),
    PAUSE,
    SHUTDOWN,
}

pub enum ThreadResult {
    OK,
    ERR,
    END,
}

//impl<const N: usize> SimEngine<N> {
//    //
//}

impl<const N: usize> Engine for SimEngine<N> {

    fn get_state(&self) -> EngineState {
        match self.state.lock() {
            Ok(status) => {
                *status
            },
            _ => {
                EngineState::ERRORED
            }
        }
    }

    fn init(&mut self) -> i32 {
        return 0;
    }

    fn step(&mut self, _steps: usize) -> i32 {
        return 0;
    }

    fn pause(&mut self) -> i32 {
        return 0;
    }

    fn end(&mut self) -> i32 {
        return 0;
    }
}

// creates the SimEngine struct, starts threads that are ready to initialize
// @param[in] tcs - array of ThreadContext objects containing models to execute
fn start_engine<const N: usize>(tcs : [Box<dyn ThreadContext + Send>; N], soft_real_time : bool) -> SimEngine<N> {
    // create barrier for thread sync
    let barr = Arc::new(Barrier::new(N));

    let mut tc_all = Vec::new(); // temporary for insertion into contructor

    // spawn context threads
    for (ind, tc) in tcs.into_iter().enumerate() {
        let (txx, rxx) = mpsc::channel(); // trigger channel
        let (tx, rx)   = mpsc::channel(); // response channel
        let cbarrier = Arc::clone(&barr);
        let srt = soft_real_time;
        let timedelta  = Duration::from_secs_f64(tc.get_time().delta);
        let handle = thread::spawn(move||{
            let mut obj = tc;

            // before init procedures
            obj.set_tid(ind);
            // end init procedures

            let mut frame_start = Instant::now();

            loop {
                match rxx.recv() {
                    Ok(ThreadCommand::INIT) => {
                        match obj.init() {
                            ConfigStatus::OK => {
                                tx.send(ThreadResult::OK).unwrap();
                            },
                            ConfigStatus::CONTINUE => {
                                // TODO FIX
                                tx.send(ThreadResult::ERR).unwrap();
                            }
                            ConfigStatus::ERR => {
                                tx.send(ThreadResult::ERR).unwrap();
                            }
                        }
                    }
                    Ok(ThreadCommand::EXECUTE(steps)) => {
                        for _ in 0..steps {
                            if srt {
                                frame_start = Instant::now();
                            }
                            // wait for runner thread to trigger
                            cbarrier.wait();

                            match obj.step() {
                                RunStatus::OK => {
                                    tx.send(ThreadResult::OK).unwrap();
                                }
                                RunStatus::STOP => {
                                    tx.send(ThreadResult::END).unwrap();
                                }
                                RunStatus::ERR => {
                                    tx.send(ThreadResult::ERR).unwrap();
                                }
                            }
                            // check for pause command
                            match rxx.try_recv() {
                                Ok(ThreadCommand::PAUSE) => {
                                    //
                                    tx.send(ThreadResult::OK).unwrap();
                                    break;
                                },
                                _ => {
                                    // do nothing
                                }
                            }
                            if srt {
                                // calculate time to next frame and sleep
                                let elapsed = frame_start.elapsed();
                                if elapsed < timedelta {
                                    thread::sleep(timedelta - elapsed);
                                }
                            }
                        }
                    }
                    Ok(ThreadCommand::PAUSE) => {
                        // the loop is already in a paused-like state, do nothing
                        continue;
                    }
                    Ok(ThreadCommand::SHUTDOWN) => {
                        break;
                    }
                    _ => ()
                }
            }
        });

        let thread_comm = ThreadComms {
            handle : handle,
            tx : txx,
            rx : rx,
        };

        tc_all.push(thread_comm);
    }

    // setup the runner thread
    let (mtor_tx, mtor_rx) = mpsc::channel(); // api to runner
    let (_rtom_tx, rtom_rx) = mpsc::channel(); // runner to api

    let mut state = EngineState::CONFIG;

    // get an arc reference to the state so it can be modified from the runner
    let rstate = Arc::new(Mutex::new(EngineState::CONFIG));
    let mutex_state = Arc::clone(&rstate);

    let mut thread_state : [EngineState; N] = [EngineState::CONFIG; N];

    let run = thread::spawn(move|| {
        loop {
            let stat = mtor_rx.try_recv();
            match state {
                EngineState::CONFIG => {
                    if stat == Ok(ThreadCommand::INIT) {
                        let mut s = mutex_state.lock().unwrap();
                        state = EngineState::INITIALIZING;
                        *s = state;

                        // send commands to initialize threads
                        for i in 0..N {
                            tc_all[i].tx.send(ThreadCommand::INIT).unwrap();
                            thread_state[i] = EngineState::INITIALIZING;
                        }
                    }
                },
                EngineState::INITIALIZING => {
                    // poll state
                    let mut count = 0;
                    for i in 0..N {
                        match thread_state[i] {
                            EngineState::INITIALIZED => {
                                // finished initializing
                                count += 1;
                            },
                            EngineState::INITIALIZING => {
                                // check to see if it's finished
                                match tc_all[i].rx.try_recv() {
                                    Ok(ThreadResult::OK) => {
                                        thread_state[i] = EngineState::INITIALIZED;
                                        count += 1;
                                    },
                                    Ok(ThreadResult::ERR) => {
                                        let mut s = mutex_state.lock().unwrap();
                                        state = EngineState::ERRORED;
                                        *s = state;
                                        break;
                                    },
                                    Ok(ThreadResult::END) => {
                                        // go straight to ended state instead of ending
                                        let mut s = mutex_state.lock().unwrap();
                                        state = EngineState::ENDED;
                                        *s = state;
                                        break;
                                    },
                                    _ => {
                                        // do nothing
                                    }
                                }
                            },
                            _ => ()
                        }
                    }
                    if count == N {
                        // all threads have initialized!
                        let mut s = mutex_state.lock().unwrap();
                        state = EngineState::INITIALIZED;
                        *s = state;

                        println!("Sim Initialized");
                    }
                },
                EngineState::INITIALIZED | EngineState::PAUSED => {
                    match stat {
                        Ok(ThreadCommand::EXECUTE(steps)) => {
                            let mut s = mutex_state.lock().unwrap();
                            state = EngineState::RUNNING;
                            *s = state;

                            // send execute command
                            for i in 0..N {
                                tc_all[i].tx.send(ThreadCommand::EXECUTE(steps)).unwrap();
                            }
                        },
                        Ok(ThreadCommand::SHUTDOWN) => {
                            // go straight to the ended state instead of ending
                            let mut s = mutex_state.lock().unwrap();
                            state = EngineState::ENDED;
                            *s = state;
                        }
                        _ => ()
                    }
                },
                EngineState::RUNNING => {
                    // poll state
                    match stat {
                        Ok(ThreadCommand::SHUTDOWN) => {
                            // set flag to halt threads
                            state = EngineState::ENDING;

                            // send command to shutdown
                            for i in 0..N {
                                tc_all[i].tx.send(ThreadCommand::SHUTDOWN).unwrap();
                            }
                        },
                        Ok(ThreadCommand::PAUSE) => {
                            // set flag to halt threads
                            state = EngineState::PAUSED;
                        }
                        _ => ()
                    }
                },
                EngineState::ENDING => {
                    // poll state

                    // if all threads have paused, call final actions and shutdown
                }
                _ => ()
            }
            thread::sleep(time::Duration::from_millis(20)); // sleep to prevent hogging the cpu
        }
    });

    SimEngine {
        soft_real_time : false,
        state : rstate,
        barrier : barr,
        runner : run,
        runner_tx : mtor_tx,
        runner_rx : rtom_rx,
    }
}
