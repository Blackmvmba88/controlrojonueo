#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum DeckAction {
    PlayPause,
    NextTrack,
    PreviousTrack,
    VolumeUp,
    VolumeDown,
}
