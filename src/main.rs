mod actions;
mod backend;
mod input;

use std::{thread, time::Duration};

use backend::{macos::MacOsBackend, MediaBackend};
use gilrs::{EventType, Gilrs};

fn main() -> Result<(), Box<dyn std::error::Error>> {
    let mut gilrs = Gilrs::new().map_err(|err| format!("failed to initialize gamepad input: {err}"))?;
    let mut backend = MacOsBackend::new();

    println!("BlackMamba Controller MVP");
    println!("Searching for Bluetooth/USB gamepads...\n");

    let mut found = false;
    for (id, gamepad) in gilrs.gamepads() {
        found = true;
        println!("✓ {:?}: {}", id, gamepad.name());
    }

    if !found {
        println!("No controller detected yet. Pair it in macOS Bluetooth settings; this process will keep listening.");
    }

    println!("\nMapping:");
    println!("  South/A/Cross -> Play/Pause");
    println!("  East/B/Circle -> Next track");
    println!("  West/X/Square -> Previous track");
    println!("  D-pad Up      -> Volume +5%");
    println!("  D-pad Down    -> Volume -5%");
    println!("\nListening... Ctrl+C to stop.\n");

    loop {
        while let Some(event) = gilrs.next_event() {
            match event.event {
                EventType::Connected => {
                    println!("✓ connected: {}", gilrs.gamepad(event.id).name());
                }
                EventType::Disconnected => {
                    println!("✗ disconnected: {:?}", event.id);
                }
                EventType::ButtonPressed(button, _) => {
                    if let Some(action) = input::map_button(button) {
                        println!("{:?} -> {:?}", button, action);
                        if let Err(err) = backend.execute(action) {
                            eprintln!("action failed: {err}");
                        }
                    }
                }
                _ => {}
            }
        }

        thread::sleep(Duration::from_millis(8));
    }
}
