use std::{
    env,
    path::{Path, PathBuf},
    process::Command,
    time::{Duration, Instant},
};

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum RuntimeMode {
    Desktop,
    Game,
}

pub struct AutoModeDetector {
    current: RuntimeMode,
    last_check: Instant,
    check_every: Duration,
}

impl AutoModeDetector {
    pub fn new() -> Self {
        Self {
            current: RuntimeMode::Desktop,
            last_check: Instant::now() - Duration::from_secs(2),
            check_every: Duration::from_millis(750),
        }
    }

    pub fn update(&mut self) -> RuntimeMode {
        if let Some(forced) = forced_mode() {
            self.current = forced;
            return self.current;
        }

        if self.last_check.elapsed() < self.check_every {
            return self.current;
        }

        self.last_check = Instant::now();
        self.current = if game_session_active() {
            RuntimeMode::Game
        } else {
            RuntimeMode::Desktop
        };
        self.current
    }
}

fn forced_mode() -> Option<RuntimeMode> {
    match env::var("BLACKMAMBA_FORCE_MODE")
        .unwrap_or_else(|_| "auto".to_string())
        .to_ascii_lowercase()
        .as_str()
    {
        "desktop" | "mouse" => Some(RuntimeMode::Desktop),
        "game" | "gaming" => Some(RuntimeMode::Game),
        _ => None,
    }
}

fn game_session_active() -> bool {
    if game_marker().exists() {
        return true;
    }

    let Some(frontmost) = frontmost_application() else {
        return false;
    };
    let app = frontmost.to_ascii_lowercase();

    if configured_game_apps()
        .iter()
        .any(|candidate| app.contains(candidate))
    {
        return true;
    }

    if is_known_native_game_name(&app) {
        return true;
    }

    if app.contains("google chrome") {
        return browser_url("Google Chrome")
            .map(|url| is_cloud_game_url(&url))
            .unwrap_or(false);
    }

    if app == "safari" {
        return browser_url("Safari")
            .map(|url| is_cloud_game_url(&url))
            .unwrap_or(false);
    }

    false
}

fn game_marker() -> PathBuf {
    env::var_os("BLACKMAMBA_GAME_ACTIVE_FILE")
        .map(PathBuf::from)
        .unwrap_or_else(|| PathBuf::from("/tmp/blackmamba-game-active"))
}

fn configured_game_apps() -> Vec<String> {
    env::var("BLACKMAMBA_GAME_APPS")
        .unwrap_or_default()
        .split(',')
        .map(str::trim)
        .filter(|value| !value.is_empty())
        .map(str::to_ascii_lowercase)
        .collect()
}

fn is_known_native_game_name(app: &str) -> bool {
    [
        "microsoft flight simulator",
        "xbox cloud gaming",
        "geforce now",
    ]
    .iter()
    .any(|candidate| app.contains(candidate))
}

fn is_cloud_game_url(url: &str) -> bool {
    let url = url.to_ascii_lowercase();
    [
        "xbox.com/play",
        "xbox.com/en-us/play",
        "xbox.com/es-mx/play",
        "play.geforcenow.com",
        "luna.amazon.",
    ]
    .iter()
    .any(|needle| url.contains(needle))
}

fn frontmost_application() -> Option<String> {
    run_osascript(
        r#"tell application "System Events" to get name of first application process whose frontmost is true"#,
    )
}

fn browser_url(application: &str) -> Option<String> {
    let script = match application {
        "Google Chrome" => {
            r#"tell application "Google Chrome"
if (count of windows) is 0 then return ""
return URL of active tab of front window
end tell"#
        }
        "Safari" => {
            r#"tell application "Safari"
if (count of windows) is 0 then return ""
return URL of current tab of front window
end tell"#
        }
        _ => return None,
    };
    run_osascript(script)
}

fn run_osascript(script: &str) -> Option<String> {
    let output = Command::new("osascript")
        .args(["-e", script])
        .output()
        .ok()?;

    if !output.status.success() {
        return None;
    }

    let value = String::from_utf8_lossy(&output.stdout).trim().to_string();
    (!value.is_empty()).then_some(value)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn xcloud_urls_are_detected() {
        assert!(is_cloud_game_url("https://www.xbox.com/play"));
        assert!(is_cloud_game_url("https://www.xbox.com/es-MX/play/launch/foo"));
        assert!(!is_cloud_game_url("https://www.youtube.com/watch?v=123"));
    }

    #[test]
    fn marker_path_has_safe_default() {
        if env::var_os("BLACKMAMBA_GAME_ACTIVE_FILE").is_none() {
            assert_eq!(game_marker(), Path::new("/tmp/blackmamba-game-active"));
        }
    }
}
