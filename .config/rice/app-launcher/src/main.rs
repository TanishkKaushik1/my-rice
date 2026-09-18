mod desktop;
mod usage;
mod ipc;
 
fn main() {
    // Start IPC server — blocks forever serving requests.
    // App list is scanned fresh on each "list" request (see ipc.rs),
    // so newly installed/removed apps show up on refresh without
    // restarting this daemon.
    ipc::serve();
}