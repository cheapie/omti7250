local done = falsewpc
local dev = "/dev/sg0"
local function sendcmd(cdb,param)
	local tempname = "/tmp/omti-"..math.random(1000,9999)
	if param then
		local tempfile = io.open(tempname,"w")
		tempfile:write(param)
		tempfile:close()
	end
	os.execute("clear")
	print("Will send the following command to "..dev..":")
	print("CDB: "..cdb)
	if param then
		print("Parameter list:")
		os.execute("xxd "..tempname)
	else
		print("No parameter list")
	end
	print()
	local cmd = "sg_raw -vvvR "..dev.." "..cdb
	if param then
		cmd = cmd.." -s "..#param.." -i "..tempname
	end
	print("The line to be executed is:")
	print(cmd)
	io.write("Is this OK? [y/N]")
	local response = io.read()
	if string.lower(response) == "y" then
		print()
		print("Sending command...")
		os.execute(cmd)
		print()
		print("Press enter to continue")
		io.read()
	end
	if param then os.remove(tempname) end
end

local function loaddb()
	io.write("Loading fixed disk database... ")
	local drives = {}
	for line in io.lines("fixeddisks.cfg") do
		if string.sub(line,1,1) ~= "#" then
			local manuf,model,cyl,hd,sect,wpcomp,stephigh,steplow =
				string.match(line,"^MANUF (.*) MODEL (.*) CYL (.*) HD (.*) SECT (.*) WPCOMP (.*) LZ .* STEPHIGH (.*) STEPLOW (.*)$")
			if not drives[manuf] then drives[manuf] = {} end
			drives[manuf][model] = {
				cyl = cyl,
				hd = hd,
				sect = sect,
				wpcomp = wpcomp,
				stephigh = stephigh,
				steplow = steplow,
			}
		end
	end
	print("Done!")
	print()
	return drives
end

repeat
	os.execute("clear")
	io.write(
		"OMTI 7250 Configuration\n"..
		"=======================\n"..
		"1. Select Device ["..dev.."]\n"..
		"2. Test Unit Ready\n"..
		"3. Recalibrate\n"..
		"4. Format Unit\n"..
		"5. Start/Stop\n"..
		"6. Change Cartridge\n"..
		"7. Assign Disk Parameters\n"..
		"8. RAM Diagnostic\n"..
		"9. Drive Diagnostics\n"..
		"10. Internal Diagnostics\n"..
		"\n"..
		"0. Cancel\n"..
		"\n"..
		"Enter your choice: "
	)
	local choice = io.read()
	os.execute("clear")
	if choice == "1" then
		io.write("Enter new device name: ")
		dev = io.read()
	elseif choice == "2" then
		sendcmd("00 00 00 00 00 00")
	elseif choice == "3" then
		sendcmd("01 00 00 00 00 00")
	elseif choice == "4" then
		io.write("Enter skew value (0-15): ")
		local skew = tonumber(io.read()) or 0
		io.write("Enter interleave value (0-15): ")
		local interleave = tonumber(io.read()) or 0
		sendcmd(string.format("04 00 00 00 %1X%1X 00",skew,interleave))
	elseif choice == "5" then
		io.write("Enter 1 to start or 0 to stop: ")
		local op = io.read()
		if op == "1" then
			sendcmd("1A 00 00 00 01 00")
		elseif op == "0" then
			sendcmd("1A 00 00 00 00 00")
		end
	elseif choice == "6" then
		sendcmd("1B 00 00 00 00 00")
	elseif choice == "7" then
		local db = loaddb()
		print("Available vendors:")
		for ven in pairs(db) do print(ven) end
		print()
		local vendor
		repeat
			io.write("Enter a vendor name, or \"user\" for a user-defined drive: ")
			vendor = io.read()
		until (vendor == "user" or db[vendor])
		local cyl,hd,sect,wpcomp,stephigh,steplow
		if vendor == "user" then
			io.write("Enter number of cylinders (1-65536): ")
			cyl = tonumber(io.read()) or 1
			io.write("Enter number of heads (1-256): ")
			hd = tonumber(io.read()) or 1
			io.write("Enter sectors per track (1-256): ")
			sect = tonumber(io.read()) or 1
			io.write("Enter write precompensation starting cylinder (1-1023) or 0 for none: ")
			wpcomp = tonumber(io.read()) or 0
			io.write("Enter step pulse width (0-255): ")
			stephigh = tonumber(io.read()) or 0
			io.write("Enter step period (0-255): ")
			steplow = tonumber(io.read()) or 0
		else
			local drives = db[vendor]
			local drive
			print("Available models:")
			for mdl in pairs(drives) do print(mdl) end
			print()
			repeat
				io.write("Enter a model name: ")
				drive = io.read()
			until (drives[drive])
			local drvtbl = drives[drive]
			cyl = drvtbl.cyl
			hd = drvtbl.hd
			sect = drvtbl.sect
			wpcomp = drvtbl.wpcomp
			stephigh = drvtbl.stephigh
			steplow = drvtbl.steplow
		end
		wpcomp = math.max(wpcomp,0)
		cyl = cyl - 1
		hd = hd - 1
		sect = sect - 1
		local paramlist = string.char(stephigh,steplow,0,hd,math.floor(cyl/0x100),(cyl%0x100),(wpcomp%0x100),math.floor(wpcomp/0x100),sect,0)
		sendcmd("C2 00 00 00 00 00",paramlist)
	elseif choice == "8" then
		sendcmd("E0 00 00 00 00 00")
	elseif choice == "9" then
		sendcmd("E3 00 00 00 00 00")
	elseif choice == "10" then
		sendcmd("E4 00 00 00 00 00")
	elseif choice == "0" then
		done = true
	end
until done
