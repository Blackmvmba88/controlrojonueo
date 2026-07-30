use crate::actions::DeckAction;

pub mod macos;

pub trait MediaBackend {
    fn execute(&mut self, action: DeckAction) -> Result<(), String>;
}
