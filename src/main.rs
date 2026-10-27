mod actions;
mod backend;
mod controller;
mod input;
mod mode;
mod spatial;

use std::{thread, time::{Duration, Instant}};

use actions::DeckAction;
use backend::{macos::MacOsBackend, DesktopBackend};
use controller::ControllerRouter;
use gilrs::{Axis, Button, EventType, Gilrs};
use input::PointerState;
use mode::{AutoModeDetector, RuntimeMode};
use spatial::SpatialNavigator;

fn main() -> Result<(), Box<dyn std::error::Error>> {
    let mut gilrs = Gilrs::new().map_err(|err| format!("failed to initialize gamepad input: {err}"))?;
    let mut backend = MacOsBackend::new()?;
    let mut pointer = PointerState::default();
    let mut spatial = SpatialNavigator::default();
    let mut controllers = ControllerRouter::bootstrap(&gilrs);
    let mut mode_detector = AutoModeDetector::new();
    let mut mode = mode_detector.update();

    println!("BlackMamba Controller Desktop v0.3");
    println!("Searching for Bluetooth/USB gamepads...\n");

    let mut found = false;
    for (id, _gamepad) in gilrs.gamepads() {
        found = true;
        println!("✓ {:?}: {}", id, ControllerRouter::describe(&gilrs, id));
    }

    if !found {
        println!("No controller detected yet. Connect it by USB or pair it by Bluetooth; this process will keep listening.");
    } else if let Some(description) = controllers.active_description(&gilrs) {
        println!("ACTIVE -> {description}");
    }

    print_mapping();
    println!("\nMode policy: AUTO (GAME when a game/xCloud session is detected; DESKTOP otherwise)");
    println!("Current mode: {:?}", mode);
    println!("Transport: AUTO (prefers USB/cable, fails over to Bluetooth/wireless)");
    println!("Override: BLACKMAMBA_FORCE_MODE=desktop|game|auto");
    println!("Listening... Ctrl+C to stop.\n");

    let mut last_error = String::new();
    let mut last_axis_log = Instant::now() - Duration::from_secs(1);

    loop {
        while let Some(event) = gilrs.next_event() {
            match event.event {
                EventType::Connected => {
                    println!("✓ connected: {}", ControllerRouter::describe(&gilrs, event.id));
                    if controllers.reconcile(&gilrs) {
                        pointer.reset();
                        spatial.disable();
                        if let Some(description) = controllers.active_description(&gilrs) {
                            println!("⇄ ACTIVE SOURCE -> {description}");
                        }
                    }
                }
                EventType::Disconnected => {
                    let was_active = controllers.accepts(event.id);
                    println!("✗ disconnected: {:?}{}", event.id, if was_active { " (active)" } else { "" });
                    if controllers.reconcile(&gilrs) {
                        pointer.reset();
                        spatial.disable();
                        match controllers.active_description(&gilrs) {
                            Some(description) => println!("⇄ FAILOVER -> {description}"),
                            None => println!("… waiting for USB/Bluetooth controller to reconnect"),
                        }
                    }
                }
                EventType::AxisChanged(axis, value, _) if controllers.accepts(event.id) => {
                    if spatial.is_enabled() && axis == Axis::RightStickX {
                        if let Some(action) = spatial.axis_action(axis, value) {
                            println!("SPATIAL {:?} -> focused visual item", action);
                            if let Err(err) = backend.execute(action) {
                                report_once(&mut last_error, err);
                            }
                        }
                    } else {
                        pointer.update_axis(axis, value);
                    }

                    if value.abs() >= 0.25 && last_axis_log.elapsed() >= Duration::from_millis(140) {
                        println!("INPUT axis {:?} = {:+.3} | mode={:?} | spatial={}", axis, value, mode, spatial.is_enabled());
                        last_axis_log = Instant::now();
                    }
                }
                EventType::ButtonChanged(button, value, _) if controllers.accepts(event.id) => {
                    if value >= 0.45 && last_axis_log.elapsed() >= Duration::from_millis(140) {
                        println!(
                            "INPUT analog-button {:?} = {:.3} | mapped={:?} | mode={:?}",
                            button,
                            value,
                            input::map_button(button),
                            mode
                        );
                        last_axis_log = Instant::now();
                    }
                }
                EventType::ButtonPressed(button, _) if controllers.accepts(event.id) => {
                    println!(
                        "INPUT button {:?} | mapped={:?} | mode={:?} | spatial={}",
                        button,
                        input::map_button(button),
                        mode,
                        spatial.is_enabled()
                    );

                    if mode != RuntimeMode::Desktop {
                        println!("ACTION suppressed: GAME mode owns the controller");
                        continue;
                    }

                    if button == Button::Mode {
                        let enabled = spatial.toggle();
                        pointer.reset();
                        println!(
                            "{} SPATIAL HUD — right-stick flick selects, A activates, B exits",
                            if enabled { "◉" } else { "○" }
                        );
                        continue;
                    }

                    if spatial.is_enabled() {
                        match button {
                            Button::South => {
                                println!("SPATIAL activate -> focused visual item");
                                if let Err(err) = backend.execute(DeckAction::VisualActivate) {
                                    report_once(&mut last_error, err);
                                }
                            }
                            Button::East => {
                                spatial.disable();
                                pointer.reset();
                                println!("○ SPATIAL HUD — closed");
                            }
                            _ => {}
                        }
                        continue;
                    }

                    let action = input::map_button(button);
                    if let Some(action) = action {
                        println!("ACTION {:?} -> macOS", action);
                        match backend.execute(action) {
                            Ok(()) => println!("ACTION {:?} -> sent", action),
                            Err(err) => report_once(&mut last_error, err),
                        }
                    } else {
                        println!("LEARN unmapped button: {:?}", button);
                    }
                }
                _ => {}
            }
        }

        let next_mode = mode_detector.update();
        if next_mode != mode {
            mode = next_mode;
            pointer.reset();
            spatial.disable();
            last_error.clear();
            match mode {
                RuntimeMode::Desktop => println!("🖱  DESKTOP mode — Xbox controls mouse/navigation"),
                RuntimeMode::Game => println!("🎮 GAME mode — desktop injection suspended; controller passes through"),
            }
        }

        if mode == RuntimeMode::Desktop {
            let (dx, dy) = pointer.cursor_delta();
            if let Err(err) = backend.move_cursor(dx, dy) {
                report_once(&mut last_error, err);
            }

            let (horizontal, vertical) = pointer.take_scroll_delta();
            if let Err(err) = backend.scroll(horizontal, vertical) {
                report_once(&mut last_error, err);
            }
        }

        thread::sleep(Duration::from_millis(8));
    }
}

fn report_once(last_error: &mut String, err: String) {
    if *last_error != err {
        eprintln!("⚠ {err}");
        *last_error = err;
    }
}

fn print_mapping() {
    println!("\nDesktop mapping:");
    println!("  Left stick       -> Mouse cursor (deadzone + acceleration)");
    println!("  Right stick      -> Scroll");
    println!("  Xbox/Mode        -> Toggle Spatial HUD selection mode");
    println!("  Spatial + RS ←/→ -> Previous / next visual focus target");
    println!("  Spatial + A      -> Activate focused target");
    println!("  Spatial + B      -> Exit Spatial HUD");
    println!("  A                 -> Left click");
    println!("  B                 -> Back");
    println!("  X                 -> Play/Pause");
    println!("  Y                 -> Fullscreen");
    println!("  LB / RB           -> Previous / next browser tab");
    println!("  LT / RT           -> Previous / next application");
    println!("  D-pad Left/Right  -> Seek backward / forward");
    println!("  D-pad Up/Down     -> Volume up / down");
    println!("  L3                -> Double click");
    println!("  R3                -> Right click");
    println!("  View              -> Mission Control");
    println!("  Menu              -> Enter");
}
