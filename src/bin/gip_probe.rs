use std::{error::Error, time::Duration};

use rusb::{Context, Direction, TransferType, UsbContext};

const VID: u16 = 0x045e;
const PID: u16 = 0x0b12;
const GIP_INIT: [u8; 5] = [0x05, 0x20, 0x00, 0x01, 0x00];

fn main() -> Result<(), Box<dyn Error>> {
    println!("BlackMamba Xbox USB/GIP probe");
    println!("Target: {:04x}:{:04x}", VID, PID);
    println!("This bypasses gilrs and talks directly to the controller over USB.");

    let context = Context::new()?;
    let mut handle = context
        .open_device_with_vid_pid(VID, PID)
        .ok_or("Xbox Series controller not found on USB")?;

    let device = handle.device();
    let descriptor = device.device_descriptor()?;
    println!(
        "USB device opened: bus={} address={} VID:PID {:04x}:{:04x}",
        device.bus_number(),
        device.address(),
        descriptor.vendor_id(),
        descriptor.product_id()
    );

    let config = device
        .config_descriptor(0)
        .or_else(|_| device.active_config_descriptor())?;

    let mut selected: Option<(u8, u8, u8)> = None;

    for interface in config.interfaces() {
        for interface_desc in interface.descriptors() {
            let interface_number = interface_desc.interface_number();
            let mut in_ep = None;
            let mut out_ep = None;

            for endpoint in interface_desc.endpoint_descriptors() {
                if endpoint.transfer_type() != TransferType::Interrupt {
                    continue;
                }

                match endpoint.direction() {
                    Direction::In if in_ep.is_none() => in_ep = Some(endpoint.address()),
                    Direction::Out if out_ep.is_none() => out_ep = Some(endpoint.address()),
                    _ => {}
                }
            }

            if let (Some(input), Some(output)) = (in_ep, out_ep) {
                selected = Some((interface_number, input, output));
                break;
            }
        }

        if selected.is_some() {
            break;
        }
    }

    let (interface, in_ep, out_ep) =
        selected.ok_or("No interface with interrupt IN + OUT endpoints was found")?;

    let _ = handle.set_auto_detach_kernel_driver(true);
    if handle.kernel_driver_active(interface).unwrap_or(false) {
        let _ = handle.detach_kernel_driver(interface);
    }

    handle
        .claim_interface(interface)
        .map_err(|err| format!("Could not claim USB interface {interface}: {err}. Try running this probe with sudo."))?;

    println!(
        "Claimed interface {} | IN=0x{:02x} OUT=0x{:02x}",
        interface, in_ep, out_ep
    );

    let written = handle.write_interrupt(out_ep, &GIP_INIT, Duration::from_millis(500))?;
    println!("GIP wake packet sent: {} bytes", written);
    println!("Move both sticks and press A/B/X/Y. Waiting for raw GIP packets...");

    let mut buffer = [0u8; 64];
    let mut packets = 0u64;

    loop {
        match handle.read_interrupt(in_ep, &mut buffer, Duration::from_secs(2)) {
            Ok(size) => {
                packets += 1;
                print!("RAW #{packets:05} ({size:02} bytes):");
                for byte in &buffer[..size] {
                    print!(" {byte:02x}");
                }
                println!();
            }
            Err(rusb::Error::Timeout) => {
                println!("... no USB packet in the last 2s");
            }
            Err(err) => {
                return Err(format!("USB read failed: {err}").into());
            }
        }
    }
}
