#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum DeckAction {
    LeftClick,
    RightClick,
    DoubleClick,
    Back,
    PlayPause,
    Fullscreen,
    PreviousTab,
    NextTab,
    PreviousApp,
    NextApp,
    SeekBackward,
    SeekForward,
    VolumeUp,
    VolumeDown,
    Enter,
    MissionControl,
}
