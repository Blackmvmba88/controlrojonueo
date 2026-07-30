use std::process::Command;

use crate::actions::DeckAction;

use super::MediaBackend;

pub struct MacOsBackend;

impl MacOsBackend {
    pub fn new() -> Self {
        Self
    }

    fn run_osascript(script: &str) -> Result<(), String> {
        let output = Command::new("osascript")
            .args(["-e", script])
            .output()
            .map_err(|err| format!("failed to launch osascript: {err}"))?;

        if output.status.success() {
            Ok(())
        } else {
            Err(String::from_utf8_lossy(&output.stderr).trim().to_owned())
        }
    }
}

impl MediaBackend for MacOsBackend {
    fn execute(&mut self, action: DeckAction) -> Result<(), String> {
        let script = match action {
            DeckAction::PlayPause => r#"tell application "Music" to playpause"#,
            DeckAction::NextTrack => r#"tell application "Music" to next track"#,
            DeckAction::PreviousTrack => r#"tell application "Music" to previous track"#,
            DeckAction::VolumeUp => {
                r#"set v to output volume of (get volume settings)
set nv to v + 5
if nv > 100 then set nv to 100
set volume output volume nv"#
            }
            DeckAction::VolumeDown => {
                r#"set v to output volume of (get volume settings)
set nv to v - 5
if nv < 0 then set nv to 0
set volume output volume nv"#
            }
        };

        Self::run_osascript(script)
    }
}
