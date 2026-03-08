--- @since 25.5.31

-- Helper function to get selected or hovered file
local selected_or_hovered = ya.sync(function()
	local h = cx.active.current.hovered
	if h then
		return tostring(h.url)
	end
	return nil
end)

-- Get list of removable USB drives
local function get_usb_drives()
	local output, err = Command("lsblk")
		:arg({ "-ndo", "NAME,SIZE,TRAN,TYPE,HOTPLUG,VENDOR,MODEL" })
		:stdout(Command.PIPED)
		:stderr(Command.PIPED)
		:output()
	
	if not output then
		return {}, "Failed to run lsblk: " .. tostring(err)
	end
	
	if not output.status.success then
		return {}, "lsblk failed: " .. output.stderr
	end
	
	local drives = {}
	for line in output.stdout:gmatch("[^\n]+") do
		-- Parse: NAME SIZE TRAN TYPE HOTPLUG VENDOR MODEL
		local parts = {}
		for part in line:gmatch("%S+") do
			table.insert(parts, part)
		end
		
		if #parts >= 5 and parts[3] == "usb" and parts[4] == "disk" and parts[5] == "1" then
			local name = parts[1]
			local size = parts[2]
			local model = ""
			for i = 6, #parts do
				model = model .. parts[i] .. " "
			end
			
			table.insert(drives, {
				path = "/dev/" .. name,
				size = size,
				model = model:gsub("^%s+", ""):gsub("%s+$", "")
			})
		end
	end
	
	return drives, nil
end

-- Show drive selection using ya.which
local function show_drive_menu(drives)
	if #drives == 0 then
		return nil
	end
	
	local cands = {}
	for i, drive in ipairs(drives) do
		table.insert(cands, {
			on = tostring(i),
			desc = string.format("%s (%s) - %s", drive.path, drive.size, drive.model)
		})
	end
	
	local choice = ya.which { cands = cands, silent = false }
	if not choice then
		return nil
	end
	
	return drives[choice]
end

-- Confirm the write operation
local function confirm_write(image_path, drive)
	local cands = {
		{ on = "y", desc = "write image to usb" },
		{ on = "n", desc = "cancel operation" },
	}
	
	local choice = ya.which {
		cands = cands,
		silent = false,
		title = string.format("⚠️  WARNING: Erase all data on %s (%s) - %s?", drive.path, drive.size, drive.model)
	}
	
	return choice == 1  -- 1 = Yes, nil or 2 = No
end

-- Check if sudo is already authenticated
local function sudo_already()
	local status = Command("sudo"):arg({ "--validate", "--non-interactive" }):status()
	return status and status.success
end

-- Check if device is writable without sudo
local function check_write_access(device_path)
	local status = Command("test"):arg({ "-w", device_path }):status()
	return status and status.success
end

-- Write image to USB drive
local function write_image(image_path, drive)
	-- Build the dd command
	local dd_cmd = string.format(
		"dd if='%s' of='%s' bs=4M status=progress conv=fsync oflag=direct && sync",
		image_path:gsub("'", "'\\''"),
		drive.path
	)
	
	-- Check if we need sudo
	local needs_sudo = not check_write_access(drive.path)
	local permit
	local child, err
	
	ya.notify {
		title = "USB Writer",
		content = string.format("Writing %s to %s...", image_path:match("[^/]+$"), drive.path),
		timeout = 5,
		level = "info",
	}
	
	if needs_sudo then
		-- Check sudo access
		if not sudo_already() then
			permit = ya.hide()
			print("Sudo password required to write disk image")
		end
		
		-- Run the command with sudo
		child, err = Command("sudo")
			:arg({ "sh", "-c", dd_cmd })
			:spawn()
		
		if permit then
			permit:drop()
		end
	else
		-- Run the command directly without sudo
		child, err = Command("sh")
			:arg({ "-c", dd_cmd })
			:spawn()
	end
	
	if not child then
		ya.notify {
			title = "USB Writer",
			content = "Failed to execute: " .. tostring(err),
			timeout = 5,
			level = "error",
		}
		return
	end
	
	-- Wait for completion
	local status = child:wait()
	
	if status and status.success then
		ya.notify {
			title = "USB Writer ✓",
			content = string.format("Successfully wrote to %s!", drive.path),
			timeout = 5,
			level = "info",
		}
	else
		ya.notify {
			title = "USB Writer ✗",
			content = "Write operation failed!",
			timeout = 5,
			level = "error",
		}
	end
end

-- Main entry point
local function entry()
	ya.emit("escape", { visual = true })
	
	-- Get the currently hovered file
	local file_path = selected_or_hovered()
	
	if not file_path then
		ya.notify {
			title = "USB Writer",
			content = "No file selected",
			timeout = 3,
			level = "error",
		}
		return
	end
	
	-- Check if it's a disk image file
	local file_ext = file_path:match("%.([^.]+)$")
	local valid_extensions = { iso = true, img = true, dmg = true, bin = true }
	
	if not file_ext or not valid_extensions[file_ext:lower()] then
		ya.notify {
			title = "USB Writer",
			content = "Please select a disk image file (.iso, .img, .dmg, .bin)",
			timeout = 3,
			level = "warn",
		}
		return
	end
	
	-- Get available USB drives
	local drives, err = get_usb_drives()
	if err then
		ya.notify {
			title = "USB Writer",
			content = err,
			timeout = 5,
			level = "error",
		}
		return
	end
	
	if #drives == 0 then
		ya.notify {
			title = "USB Writer",
			content = "No USB drives detected!",
			timeout = 3,
			level = "error",
		}
		return
	end
	
	-- Show drive selection menu
	local selected_drive = show_drive_menu(drives)
	if not selected_drive then
		ya.notify {
			title = "USB Writer",
			content = "Operation cancelled",
			timeout = 3,
			level = "info",
		}
		return
	end
	
	-- Confirm the operation
	if not confirm_write(file_path, selected_drive) then
		ya.notify {
			title = "USB Writer",
			content = "Operation cancelled (type YES to confirm)",
			timeout = 3,
			level = "info",
		}
		return
	end
	
	-- Write the image
	write_image(file_path, selected_drive)
end

return { entry = entry }
