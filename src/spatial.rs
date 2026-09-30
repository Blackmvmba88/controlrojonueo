use gilrs::Axis;

use crate::actions::DeckAction;

const SELECT_THRESHOLD: f32 = 0.68;
const RELEASE_THRESHOLD: f32 = 0.28;

#[derive(Debug, Default)]
pub struct SpatialNavigator {
    enabled: bool,
    horizontal_latch: i8,
}

impl SpatialNavigator {
    pub fn is_enabled(&self) -> bool {
        self.enabled
    }

    pub fn toggle(&mut self) -> bool {
        self.enabled = !self.enabled;
        self.horizontal_latch = 0;
        self.enabled
    }

    pub fn disable(&mut self) {
        self.enabled = false;
        self.horizontal_latch = 0;
    }

    pub fn axis_action(&mut self, axis: Axis, value: f32) -> Option<DeckAction> {
        if !self.enabled || axis != Axis::RightStickX {
            return None;
        }

        if value.abs() <= RELEASE_THRESHOLD {
            self.horizontal_latch = 0;
            return None;
        }

        if value >= SELECT_THRESHOLD && self.horizontal_latch != 1 {
            self.horizontal_latch = 1;
            return Some(DeckAction::VisualNext);
        }

        if value <= -SELECT_THRESHOLD && self.horizontal_latch != -1 {
            self.horizontal_latch = -1;
            return Some(DeckAction::VisualPrevious);
        }

        None
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn disabled_navigator_emits_nothing() {
        let mut nav = SpatialNavigator::default();
        assert_eq!(nav.axis_action(Axis::RightStickX, 1.0), None);
    }

    #[test]
    fn right_flick_selects_next_once_until_release() {
        let mut nav = SpatialNavigator::default();
        nav.toggle();

        assert_eq!(nav.axis_action(Axis::RightStickX, 0.9), Some(DeckAction::VisualNext));
        assert_eq!(nav.axis_action(Axis::RightStickX, 0.95), None);
        assert_eq!(nav.axis_action(Axis::RightStickX, 0.0), None);
        assert_eq!(nav.axis_action(Axis::RightStickX, 0.9), Some(DeckAction::VisualNext));
    }

    #[test]
    fn left_flick_selects_previous() {
        let mut nav = SpatialNavigator::default();
        nav.toggle();
        assert_eq!(nav.axis_action(Axis::RightStickX, -0.9), Some(DeckAction::VisualPrevious));
    }
}
