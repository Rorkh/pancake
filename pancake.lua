local lfs = require("lfs")

local midi = require("midi-parser")
local urch = require("urch")
local timer = require("timer")

local keymap = "1!2@34$5%6^78*9(0qQwWeErtTyYuiIoOpPasSdDfgGhHjJklLzZxcCvVbBnm"
local function key(n)
	local key = string.upper(string.sub(keymap, n - 35, n - 35))
	return tonumber(key) and tonumber(key) or key
end

local separator = package.config:sub(1,1)
local songs_path = "songs"

local songs = {}
for song in lfs.dir(songs_path .. separator) do if song:sub(-4) == ".mid" then table.insert(songs, song) end end

local current = 1

local function print_current()
	print("Selected: " .. songs[current])
end

local function play_midi()	
	local midi = midi(songs_path .. separator .. songs[current])
	local taps = {}

	local tempo = 500000
	local time = 0

	for _, track in ipairs(midi.tracks) do
		for _, message in ipairs(track.messages) do
			--if message.meta and message.meta == "Set Tempo" then tempo = message.tempo end

			if message.type == "on" then
				local delta
				if message.time > 0 then
					delta = message.time * (tempo * 1e-6 / 480)
				else
					delta = 0
				end

				time = time + (delta * 1000)
				timer.set_timer(time, function() urch.KeyPress(urch.key[key(message.number)]) end)
			end
		end
	end

	timer.waittimers()
end

while true do
	for k, v in ipairs(songs) do print(k .. ". " .. v) end

	urch.TrapKeys({urch.key.RIGHT, urch.key.LEFT, urch.key.ALT}, function(key)
		if key ~= urch.key.ALT then
			local new_value = (key == urch.key.RIGHT) and (current + 1) or (current - 1)
				if new_value == 0 then new_value = #songs end
				if new_value > #songs then new_value = 1 end

			current = new_value
			print_current()
		else
			play_midi()
		end
	end)
end