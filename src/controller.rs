use gilrs::{GamepadId, Gilrs, PowerInfo};

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Transport {
    Wired,
    Wireless,
    Unknown,
}

impl Transport {
    pub fn label(self) -> &'static str {
        match self {
            Self::Wired => "USB/cable",
            Self::Wireless => "Bluetooth/wireless",
            Self::Unknown => "unknown",
        }
    }

    fn priority(self) -> u8 {
        match self {
            Self::Wired => 3,
            Self::Wireless => 2,
            Self::Unknown => 1,
        }
    }
}

#[derive(Debug, Default)]
pub struct ControllerRouter {
    active: Option<GamepadId>,
}

impl ControllerRouter {
    pub fn bootstrap(gilrs: &Gilrs) -> Self {
        let active = best_connected(gilrs);
        Self { active }
    }

    pub fn accepts(&self, id: GamepadId) -> bool {
        self.active == Some(id)
    }

    /// Re-evaluate the active physical source after a hotplug event.
    ///
    /// Policy:
    /// - wired wins over wireless/unknown;
    /// - otherwise keep the current source if it is still connected;
    /// - if the active source vanished, fail over to the best connected source.
    pub fn reconcile(&mut self, gilrs: &Gilrs) -> bool {
        let previous = self.active;

        let current_is_connected = self
            .active
            .map(|id| gilrs.gamepad(id).is_connected())
            .unwrap_or(false);

        let best = best_connected(gilrs);

        self.active = if !current_is_connected {
            best
        } else if let Some(current) = self.active {
            match best {
                Some(candidate) => {
                    let current_gamepad = gilrs.gamepad(current);
                    let candidate_gamepad = gilrs.gamepad(candidate);
                    let current_transport =
                        transport_for(current_gamepad.uuid(), current_gamepad.power_info());
                    let candidate_transport =
                        transport_for(candidate_gamepad.uuid(), candidate_gamepad.power_info());

                    if candidate_transport.priority() > current_transport.priority() {
                        Some(candidate)
                    } else {
                        Some(current)
                    }
                }
                None => Some(current),
            }
        } else {
            // Defensive fallback. In normal operation this state cannot happen
            // because None active implies current_is_connected == false.
            best
        };

        previous != self.active
    }

    pub fn describe(gilrs: &Gilrs, id: GamepadId) -> String {
        let gamepad = gilrs.gamepad(id);
        let uuid = format_uuid(gamepad.uuid());
        let vendor = gamepad
            .vendor_id()
            .map(|value| format!("{value:04x}"))
            .unwrap_or_else(|| "????".to_string());
        let product = gamepad
            .product_id()
            .map(|value| format!("{value:04x}"))
            .unwrap_or_else(|| "????".to_string());
        let transport = transport_for(gamepad.uuid(), gamepad.power_info());

        format!(
            "{} | os='{}' | {} | VID:PID {}:{} | UUID {}",
            gamepad.name(),
            gamepad.os_name(),
            transport.label(),
            vendor,
            product,
            uuid
        )
    }

    pub fn active_description(&self, gilrs: &Gilrs) -> Option<String> {
        self.active.map(|id| Self::describe(gilrs, id))
    }
}

fn best_connected(gilrs: &Gilrs) -> Option<GamepadId> {
    gilrs
        .gamepads()
        .filter(|(_, gamepad)| gamepad.is_connected())
        .max_by_key(|(_, gamepad)| transport_for(gamepad.uuid(), gamepad.power_info()).priority())
        .map(|(id, _)| id)
}

fn transport_for(uuid: [u8; 16], power: PowerInfo) -> Transport {
    // gilrs UUIDs follow SDL's joystick GUID convention. Depending on the
    // platform/backend, the leading bus code can expose USB/Bluetooth.
    // We treat this only as a transport hint and fall back to power state.
    match u16::from_le_bytes([uuid[0], uuid[1]]) {
        0x0001 | 0x0003 => Transport::Wired,
        0x0002 | 0x0005 => Transport::Wireless,
        _ => match power {
            PowerInfo::Wired => Transport::Wired,
            PowerInfo::Discharging(_) | PowerInfo::Charging(_) | PowerInfo::Charged => {
                Transport::Wireless
            }
            PowerInfo::Unknown => Transport::Unknown,
        },
    }
}

fn format_uuid(bytes: [u8; 16]) -> String {
    let mut out = String::with_capacity(36);
    for (index, byte) in bytes.iter().enumerate() {
        if matches!(index, 4 | 6 | 8 | 10) {
            out.push('-');
        }
        use std::fmt::Write as _;
        let _ = write!(&mut out, "{byte:02x}");
    }
    out
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn wired_has_highest_priority() {
        assert!(Transport::Wired.priority() > Transport::Wireless.priority());
        assert!(Transport::Wireless.priority() > Transport::Unknown.priority());
    }

    #[test]
    fn uuid_formatter_is_stable() {
        assert_eq!(
            format_uuid([0; 16]),
            "00000000-0000-0000-0000-000000000000"
        );
    }

    #[test]
    fn common_guid_bus_hints_distinguish_usb_and_bluetooth() {
        let mut usb = [0u8; 16];
        usb[0..2].copy_from_slice(&0x0003u16.to_le_bytes());
        assert_eq!(transport_for(usb, PowerInfo::Unknown), Transport::Wired);

        let mut bluetooth = [0u8; 16];
        bluetooth[0..2].copy_from_slice(&0x0005u16.to_le_bytes());
        assert_eq!(
            transport_for(bluetooth, PowerInfo::Unknown),
            Transport::Wireless
        );
    }
}
