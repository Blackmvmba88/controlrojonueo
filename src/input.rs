use gilrs::{Axis, Button};

use crate::actions::DeckAction;

const STICK_DEADZONE: f32 = 0.16;
const SCROLL_DEADZONE: f32 = 0.22;

#[derive(Debug, Default, Clone, Copy)]
pub struct PointerState {
    left_x: f32,
    left_y: f32,
    right_x: f32,
    right_y: f32,
    scroll_x_accumulator: f32,
    scroll_y_accumulator: f32,
}

impl PointerState {
    pub fn update_axis(&mut self, axis: Axis, value: f32) {
        match axis {
            Axis::LeftStickX => self.left_x = value,
            Axis::LeftStickY => self.left_y = value,
            Axis::RightStickX => self.right_x = value,
            Axis::RightStickY => self.right_y = value,
            _ => {}
        }
    }

    pub fn reset(&mut self) {
        *self = Self::default();
    }

    pub fn cursor_delta(&self) -> (i32, i32) {
        let dx = mouse_curve(self.left_x);
        // gilrs reports positive Y toward the top on common Xbox mappings;
        // Enigo relative mouse coordinates are positive toward the bottom.
        let dy = -mouse_curve(self.left_y);
        (dx, dy)
    }

    pub fn take_scroll_delta(&mut self) -> (i32, i32) {
        self.scroll_x_accumulator += scroll_curve(self.right_x);
        self.scroll_y_accumulator += scroll_curve(-self.right_y);

        let horizontal = whole_steps(&mut self.scroll_x_accumulator);
        let vertical = whole_steps(&mut self.scroll_y_accumulator);
        (horizontal, vertical)
    }
}

pub fn map_button(button: Button) -> Option<DeckAction> {
    match button {
        Button::South => Some(DeckAction::LeftClick),
        Button::East => Some(DeckAction::Back),
        Button::West => Some(DeckAction::PlayPause),
        Button::North => Some(DeckAction::Fullscreen),
        Button::LeftTrigger => Some(DeckAction::PreviousTab),
        Button::RightTrigger => Some(DeckAction::NextTab),
        Button::LeftTrigger2 => Some(DeckAction::PreviousApp),
        Button::RightTrigger2 => Some(DeckAction::NextApp),
        Button::DPadUp => Some(DeckAction::VolumeUp),
        Button::DPadDown => Some(DeckAction::VolumeDown),
        Button::DPadLeft => Some(DeckAction::SeekBackward),
        Button::DPadRight => Some(DeckAction::SeekForward),
        Button::LeftThumb => Some(DeckAction::DoubleClick),
        Button::RightThumb => Some(DeckAction::RightClick),
        Button::Select => Some(DeckAction::MissionControl),
        Button::Start => Some(DeckAction::Enter),
        _ => None,
    }
}

fn mouse_curve(value: f32) -> i32 {
    let magnitude = normalize_deadzone(value.abs(), STICK_DEADZONE);
    if magnitude == 0.0 {
        return 0;
    }

    let pixels = 1.0 + 22.0 * magnitude.powf(2.15);
    (pixels * value.signum()).round() as i32
}

fn scroll_curve(value: f32) -> f32 {
    let magnitude = normalize_deadzone(value.abs(), SCROLL_DEADZONE);
    if magnitude == 0.0 {
        return 0.0;
    }

    (0.08 + 0.42 * magnitude.powf(1.7)) * value.signum()
}

fn normalize_deadzone(value: f32, deadzone: f32) -> f32 {
    if value <= deadzone {
        0.0
    } else {
        ((value - deadzone) / (1.0 - deadzone)).clamp(0.0, 1.0)
    }
}

fn whole_steps(accumulator: &mut f32) -> i32 {
    let steps = accumulator.trunc() as i32;
    *accumulator -= steps as f32;
    steps
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn center_stick_does_not_move_cursor() {
        let state = PointerState::default();
        assert_eq!(state.cursor_delta(), (0, 0));
    }

    #[test]
    fn deadzone_filters_small_drift() {
        let mut state = PointerState::default();
        state.update_axis(Axis::LeftStickX, 0.10);
        state.update_axis(Axis::LeftStickY, -0.08);
        assert_eq!(state.cursor_delta(), (0, 0));
    }

    #[test]
    fn full_stick_has_fast_pointer_response() {
        let mut state = PointerState::default();
        state.update_axis(Axis::LeftStickX, 1.0);
        assert!(state.cursor_delta().0 >= 20);
    }

    #[test]
    fn xbox_a_maps_to_left_click() {
        assert_eq!(map_button(Button::South), Some(DeckAction::LeftClick));
    }

    #[test]
    fn bumpers_and_triggers_have_separate_navigation_jobs() {
        assert_eq!(map_button(Button::LeftTrigger), Some(DeckAction::PreviousTab));
        assert_eq!(map_button(Button::RightTrigger), Some(DeckAction::NextTab));
        assert_eq!(map_button(Button::LeftTrigger2), Some(DeckAction::PreviousApp));
        assert_eq!(map_button(Button::RightTrigger2), Some(DeckAction::NextApp));
    }
}
