# usb-writer.yazi

A Yazi plugin for writing disk images (ISO, IMG, etc.) to USB drives directly from the file manager.

## Features

- 🔍 Automatically detects USB drives
- 📋 Shows drive information (size, model)
- ⚠️ Requires explicit "YES" confirmation before writing
- 📊 Shows progress during write operation
- 🔒 Uses `sudo` with secure privilege escalation

## Installation

Copy the plugin to your Yazi plugins directory:

```bash
mkdir -p ~/.config/yazi/plugins/
cp -r usb-writer.yazi ~/.config/yazi/plugins/
```

## Usage

Add a keybinding in `~/.config/yazi/keymap.toml`:

```toml
[[manager.prepend_keymap]]
on   = [ "u", "w" ]
run  = "plugin usb-writer"
desc = "Write disk image to USB"
```

Note that the keybinding above is just an example - adjust it to avoid conflicts with your other commands/plugins.

### How to use:

1. Navigate to an ISO, IMG, DMG, or BIN file in Yazi
2. Press `uw` (or your configured keybinding)
3. Select the target USB drive from the list (press the number)
4. Type `YES` (must be uppercase) to confirm the operation
5. Enter your sudo password if prompted
6. The image will be written to the USB drive

## Requirements

- `lsblk` - for detecting USB drives (usually pre-installed)
- `dd` - for writing disk images (usually pre-installed)
- `sudo` - for privilege escalation
- Linux operating system

## Safety Features

- Only detects removable USB drives (hotpluggable devices)
- Requires explicit "YES" confirmation (case-sensitive)
- Shows clear warnings with drive details before writing
- Uses `sync` to ensure data is fully written
- Will not proceed if no USB drive is detected

## Troubleshooting

**No USB drives detected:**
- Ensure the USB drive is plugged in and recognized by the system
- Check with `lsblk -d` to see if the drive appears
- Verify it shows as a USB device with `lsblk -o NAME,TRAN,HOTPLUG`

**Permission denied:**
- Ensure `sudo` is available and configured
- You may need to enter your password when prompted

**Write fails:**
- Check if the USB drive is mounted - unmount it first with `sudo umount /dev/sdX`
- Verify you have write permissions
- Ensure the USB drive has sufficient space

## Configuration

You can modify the supported file extensions by editing the `valid_extensions` table in `main.lua`:

```lua
local valid_extensions = { iso = true, img = true, dmg = true, bin = true }
```

## License

MIT License - feel free to modify and distribute.
