use gilrs::Button;

use crate::actions::DeckAction;

pub fn map_button(button: Button) -> Option<DeckAction> {
    match button {
        Button::South => Some(DeckAction::PlayPause),
        Button::East => Some(DeckAction::NextTrack),
        Button::West => Some(DeckAction::PreviousTrack),
        Button::DPadUp => Some(DeckAction::VolumeUp),
        Button::DPadDown => Some(DeckAction::VolumeDown),
        _ => None,
    }
}
