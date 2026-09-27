use std::{thread, time::Duration};

use enigo::{
    Axis as ScrollAxis, Button as MouseButton, Coordinate, Direction, Enigo, Key, Keyboard, Mouse,
    Settings,
};

use crate::actions::DeckAction;

use super::DesktopBackend;

pub struct MacOsBackend {
    enigo: Enigo,
}

impl MacOsBackend {
    pub fn new() -> Result<Self, String> {
        let enigo = Enigo::new(&Settings::default())
            .map_err(|err| format!("failed to initialize macOS input injection: {err}"))?;
        Ok(Self { enigo })
    }

    fn input_error(context: &str, err: impl std::fmt::Display) -> String {
        format!("{context}: {err}. Grant Accessibility permission to this app/Terminal in System Settings > Privacy & Security > Accessibility")
    }

    fn key(&mut self, key: Key) -> Result<(), String> {
        self.enigo
            .key(key, Direction::Click)
            .map_err(|err| Self::input_error("keyboard event failed", err))
    }

    fn combo(&mut self, modifiers: &[Key], key: Key) -> Result<(), String> {
        for modifier in modifiers {
            self.enigo
                .key(modifier.clone(), Direction::Press)
                .map_err(|err| Self::input_error("modifier press failed", err))?;
        }

        let key_result = self
            .enigo
            .key(key, Direction::Click)
            .map_err(|err| Self::input_error("shortcut key failed", err));

        let mut release_error = None;
        for modifier in modifiers.iter().rev() {
            if let Err(err) = self.enigo.key(modifier.clone(), Direction::Release) {
                release_error = Some(Self::input_error("modifier release failed", err));
            }
        }

        key_result?;
        if let Some(err) = release_error {
            return Err(err);
        }
        Ok(())
    }

    fn click(&mut self, button: MouseButton) -> Result<(), String> {
        self.enigo
            .button(button, Direction::Click)
            .map_err(|err| Self::input_error("mouse click failed", err))
    }
}

impl DesktopBackend for MacOsBackend {
    fn execute(&mut self, action: DeckAction) -> Result<(), String> {
        match action {
            DeckAction::LeftClick => self.click(MouseButton::Left),
            DeckAction::RightClick => self.click(MouseButton::Right),
            DeckAction::DoubleClick => {
                self.click(MouseButton::Left)?;
                thread::sleep(Duration::from_millis(55));
                self.click(MouseButton::Left)
            }
            DeckAction::Back => self.click(MouseButton::Back),
            DeckAction::PlayPause => self.key(Key::MediaPlayPause),
            DeckAction::Fullscreen => self.combo(&[Key::Control, Key::Meta], Key::Unicode('f')),
            DeckAction::PreviousTab => self.combo(&[Key::Control, Key::Shift], Key::Tab),
            DeckAction::NextTab => self.combo(&[Key::Control], Key::Tab),
            DeckAction::PreviousApp => self.combo(&[Key::Meta, Key::Shift], Key::Tab),
            DeckAction::NextApp => self.combo(&[Key::Meta], Key::Tab),
            DeckAction::SeekBackward => self.key(Key::LeftArrow),
            DeckAction::SeekForward => self.key(Key::RightArrow),
            DeckAction::VolumeUp => self.key(Key::VolumeUp),
            DeckAction::VolumeDown => self.key(Key::VolumeDown),
            DeckAction::Enter => self.key(Key::Return),
            DeckAction::MissionControl => self.combo(&[Key::Control], Key::UpArrow),
        }
    }

    fn move_cursor(&mut self, dx: i32, dy: i32) -> Result<(), String> {
        if dx == 0 && dy == 0 {
            return Ok(());
        }
        self.enigo
            .move_mouse(dx, dy, Coordinate::Rel)
            .map_err(|err| Self::input_error("cursor movement failed", err))
    }

    fn scroll(&mut self, horizontal: i32, vertical: i32) -> Result<(), String> {
        if horizontal != 0 {
            self.enigo
                .scroll(horizontal, ScrollAxis::Horizontal)
                .map_err(|err| Self::input_error("horizontal scroll failed", err))?;
        }
        if vertical != 0 {
            self.enigo
                .scroll(vertical, ScrollAxis::Vertical)
                .map_err(|err| Self::input_error("vertical scroll failed", err))?;
        }
        Ok(())
    }
}
