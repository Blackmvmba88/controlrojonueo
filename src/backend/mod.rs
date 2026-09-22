use crate::actions::DeckAction;

pub mod macos;

pub trait DesktopBackend {
    fn execute(&mut self, action: DeckAction) -> Result<(), String>;
    fn move_cursor(&mut self, dx: i32, dy: i32) -> Result<(), String>;
    fn scroll(&mut self, horizontal: i32, vertical: i32) -> Result<(), String>;
}
