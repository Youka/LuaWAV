--[[
	Reads or writes audio file in WAVE format with PCM integer samples.
	
	Function 'wav' requires 2 arguments: a filename and a mode, which can be "r" (read) or "w" (write).
	A call returns one table with methods depending on the used mode.
	On reading, following methods are callable:
	- get_filename()
	- get_mode()
	- get_file_size()
	- get_channels_number()
	- get_sample_rate()
	- get_byte_rate()
	- get_block_align()
	- get_bits_per_sample()
	- get_samples_per_channel()
	- get_sample_from_ms(ms)
	- get_ms_from_sample(sample)
	- get_min_max_amplitude()
	- get_position()
	- set_position(pos)
	- get_samples_interlaced(n)
	- get_samples(n)
	On writing, following methods are callable:
	- init(channels_number, sample_rate, bits_per_sample)
	- write_samples_interlaced(samples)
	- finish()
	
	(WAVE format: https://ccrma.stanford.edu/courses/422/projects/WaveFormat/)
]]
function wav(filename, mode)
	-- Check function parameters
	if type(filename) ~= "string" or not (mode == "r" or mode == "w") then
		error("invalid function parameters, expected filename and mode \"r\" or \"w\"", 2)
	end
	-- Audio file handle
	local file = io.open(filename, mode == "r" and "rb" or "wb")
	if not file then
		error(string.format("couldn't open file %q", filename), 2)
	end
	-- Byte-string(unsigend integer,little endian)<->Lua-number converters
	local function bton(s)
		local bytes = {s:byte(1,#s)}
		local n, bytes_n = 0, #bytes
		for i = 0, bytes_n-1 do
			n = n + bytes[1+i] * 2^(i*8)
		end
		return n
	end
	local unpack = table.unpack or unpack	-- Lua 5.1 or 5.2 table unpacker
	local function ntob(n, len)
		local n, bytes = math.max(math.floor(n), 0), {}
		for i=1, len do
			bytes[i] = n % 256
			n = math.floor(n / 256)
		end
		return string.char(unpack(bytes))
	end
	-- Check for integer
	local function isint(n)
		return type(n) == "number" and n == math.floor(n)
	end
	-- Initialize read process
	if mode == "r" then
		-- Audio meta informations
		local file_size, channels_number, sample_rate, byte_rate, block_align, bits_per_sample, samples_per_channel
		-- Audio samples file area
		local data_begin, data_end
		-- Read file type
		if file:read(4) ~= "RIFF" then
			error("not a RIFF file", 2)
		end
		file_size = file:read(4)
		if not file_size then
			error("file header incomplete (file size)")
		end
		file_size = bton(file_size) + 8
		if file:read(4) ~= "WAVE" then
			error("not a WAVE file", 2)
		end
		-- Read file chunks
		local chunk_id, chunk_size
		while true do
			-- Read chunk header
			chunk_id, chunk_size = file:read(4), file:read(4)
			if not chunk_size then
				break
			end
			chunk_size = bton(chunk_size)
			-- Identify chunk type
			if chunk_id == "fmt " then
				-- Read format informations
				local bytes = file:read(2)
				if not bytes or bton(bytes) ~= 1 then
					error("data must be in PCM format", 2)
				end
				bytes = file:read(2)
				if not bytes then
					error("channels number not found", 2)
				end
				channels_number = bton(bytes)
				bytes = file:read(4)
				if not bytes then
					error("sample rate not found", 2)
				end
				sample_rate = bton(bytes)
				bytes = file:read(4)
				if not bytes then
					error("byte rate not found", 2)
				end
				byte_rate = bton(bytes)
				bytes = file:read(2)
				if not bytes then
					error("block align not found", 2)
				end
				block_align = bton(bytes)
				bytes = file:read(2)
				if not bytes then
					error("bits per sample not found")
				end
				bits_per_sample = bton(bytes)
				if bits_per_sample ~= 8 and bits_per_sample ~= 16 and bits_per_sample ~= 24 and bits_per_sample ~= 32 then
					error("bits per sample must be 8, 16, 24 or 32", 2)
				end
				file:seek("cur", chunk_size-16)
			elseif chunk_id == "data" then
				-- Read samples
				if not block_align then
					error("format informations must be defined before sample data", 2)
				end
				samples_per_channel = chunk_size / block_align
				data_begin = file:seek()
				data_end = data_begin + chunk_size
				break	-- Stop here for later reading
			else
				-- Skip chunk
				file:seek("cur", chunk_size)
			end
		end
		-- Return audio handler
		local obj
		obj = {
			get_filename = function()
				return filename
			end,
			get_mode = function()
				return mode
			end,
			get_file_size = function()
				return file_size
			end,
			get_channels_number = function()
				return channels_number
			end,
			get_sample_rate = function()
				return sample_rate
			end,
			get_byte_rate = function()
				return byte_rate
			end,
			get_block_align = function()
				return block_align
			end,
			get_bits_per_sample = function()
				return bits_per_sample
			end,
			get_samples_per_channel = function()
				return samples_per_channel
			end,
			get_sample_from_ms = function(ms)
				if not isint(ms) or ms < 0 then
					error("positive integer expected", 2)
				end
				return ms * 0.001 * sample_rate
			end,
			get_ms_from_sample = function(sample)
				if not isint(sample) or sample < 0 then
					error("positive integer expected", 2)
				end
				return sample / sample_rate * 1000
			end,
			get_min_max_amplitude = function()
				local half_level = 2^bits_per_sample / 2
				return -half_level, half_level - 1
			end,
			get_position = function()
				if not block_align then
					error("no format informations available", 2)
				elseif not data_begin then
					error("no samples available", 2)
				end
				return (file:seek() - data_begin) / block_align
			end,
			set_position = function(pos)
				if not isint(pos) or pos < 0 then
					error("positive integer expected", 2)
				elseif not block_align then
					error("no format informations available", 2)
				elseif not data_begin then
					error("no samples available", 2)
				elseif data_begin + pos * block_align > data_end then
					error("tried to set position behind data end", 2)
				end
				file:seek("set", data_begin + pos * block_align)
			end,
			get_samples_interlaced = function(n)
				if not isint(n) or n <= 0 then
					error("positive integer greater zero expected", 2)
				elseif not block_align then
					error("no format informations available", 2)
				elseif not data_begin then
					error("no samples available", 2)
				elseif file:seek() + n * block_align > data_end then
					error("tried to read over data end", 2)
				end
				local bytes, sample, output = file:read(n * block_align), nil, {n = 0}
				local bytes_n = #bytes
				if bits_per_sample == 8 then
					for i=1, bytes_n, 1 do
						sample = bton(bytes:sub(i,i))
						output.n = output.n + 1
						output[output.n] = sample > 127 and sample - 256 or sample
					end
				elseif bits_per_sample == 16 then
					for i=1, bytes_n, 2 do
						sample = bton(bytes:sub(i,i+1))
						output.n = output.n + 1
						output[output.n] = sample > 32767 and sample - 65536 or sample
					end
				elseif bits_per_sample == 24 then
					for i=1, bytes_n, 3 do
						sample = bton(bytes:sub(i,i+2))
						output.n = output.n + 1
						output[output.n] = sample > 8388607 and sample - 16777216 or sample
					end
				else	-- if bits_per_sample == 32 then
					for i=1, bytes_n, 4 do
						sample = bton(bytes:sub(i,i+3))
						output.n = output.n + 1
						output[output.n] = sample > 2147483647 and sample - 4294967296 or sample
					end
				end
				return output
			end,
			get_samples = function(n)
				local success, samples = pcall(obj.get_samples_interlaced, n)
				if not success then
					error(samples, 2)
				end
				local output, channel_samples = {n = channels_number}
				for c=1, output.n do
					channel_samples = {n = samples.n / channels_number}
					for s=1, channel_samples.n do
						channel_samples[s] = samples[c + (s-1) * channels_number]
					end
					output[c] = channel_samples
				end
				return output
			end
		}
		return obj
	-- Initialize write process
	else
		-- Audio meta informations
		local channels_number_private, bytes_per_sample
		-- Return audio handler
		return {
			init = function(channels_number, sample_rate, bits_per_sample)
				-- Check function parameters
				if not isint(channels_number) or channels_number < 1 or
					not isint(sample_rate) or sample_rate < 1 or
					not (bits_per_sample == 8 or bits_per_sample == 16 or bits_per_sample == 24 or bits_per_sample == 32) then
					error("valid channels number, sample rate and bits per sample expected", 2)
				-- Already finished?
				elseif not file then
					error("already finished", 2)
				-- Already initialized?
				elseif file:seek() > 0 then
					error("already initialized", 2)
				end
				-- Write file type
				file:write("RIFF????WAVE")	-- file size to insert later
				-- Write format chunk
				file:write("fmt ",
							ntob(16, 4),
							ntob(1, 2),
							ntob(channels_number, 2),
							ntob(sample_rate, 4),
							ntob(sample_rate * channels_number * (bits_per_sample / 8), 4),
							ntob(channels_number * (bits_per_sample / 8), 2),
							ntob(bits_per_sample, 2))
				-- Write data chunk (so far)
				file:write("data????")	-- data size to insert later
				-- Set format memory
				channels_number_private, bytes_per_sample = channels_number, bits_per_sample / 8
			end,
			write_samples_interlaced = function(samples)
				-- Check function parameters
				if type(samples) ~= "table" then
					error("table expected", 2)
				end
				local samples_n = #samples
				if samples_n == 0 or samples_n % channels_number_private ~= 0 then
					error("valid number of samples expected (multiple of channels)", 2)
				-- Already finished?
				elseif not file then
					error("already finished", 2)
				-- Already initialized?
				elseif file:seek() == 0 then
					error("initialize before writing samples", 2)
				end
				-- All samples are numbers?
				for i=1, samples_n do
					if type(samples[i]) ~= "number" then
						error("samples have to be numbers", 2)
					end
				end
				-- Write samples to file
				local sample
				if bytes_per_sample == 1 then
					for i=1, samples_n do
						sample = samples[i]
						file:write(ntob(sample < 0 and sample + 256 or sample, 1))
					end
				elseif bytes_per_sample == 2 then
					for i=1, samples_n do
						sample = samples[i]
						file:write(ntob(sample < 0 and sample + 65536 or sample, 2))
					end
				elseif bytes_per_sample == 3 then
					for i=1, samples_n do
						sample = samples[i]
						file:write(ntob(sample < 0 and sample + 16777216 or sample, 3))
					end
				else	-- if bytes_per_sample == 4 then
					for i=1, samples_n do
						sample = samples[i]
						file:write(ntob(sample < 0 and sample + 4294967296 or sample, 4))
					end
				end
			end,
			finish = function()
				-- Already finished?
				if not file then
					error("already finished", 2)
				-- Already initialized?
				elseif file:seek() == 0 then
					error("initialize before finishing", 2)
				end
				-- Get file size
				local file_size = file:seek()
				if file_size < 44 then
					error("file not complete", 2)
				end
				-- Save file size
				file:seek("set", 4)
				file:write(ntob(file_size - 8, 4))
				-- Save data size
				file:seek("set", 40)
				file:write(ntob(file_size - 44, 4))
				-- Finalize file for secure reading
				file:close()
				file = nil
			end
		}
	end
end

--[[
	Apply fourier transformtion on samples.

	(FFT: http://www.relisoft.com/science/physics/fft.html)
]]
function samples_transform(samples)
	-- Check function parameters
	if type(samples) ~= "table" then
		error("table expected", 2)
	end
	do
		local n = #samples
		while n % 2 == 0 and n > 1 do
			n = n / 2
		end
		if n ~= 1 then
			error("table size have to be a power of two", 2)
		end
	end
	for _, sample in ipairs(samples) do
		if type(sample) ~= "number" then
			error("table have only to contain numbers", 2)
		elseif sample > 1 or sample < -1 then
			error("numbers should be normalized / limited to -1 until 1", 2)
		end
	end
	-- Complex numbers
	local complex_t
	do
		local function tocomplex(a, b)
			if type(b) == "number" then return a, {r = b, i = 0}
			elseif type(a) == "number" then return {r = a, i = 0}, b
			else return a, b end
		end
		local complex = {}
		complex.__add = function(a, b)
			local c1, c2 = tocomplex(a, b)
			return setmetatable({r = c1.r + c2.r, i = c1.i + c2.i}, complex)
		end
		complex.__sub = function(a, b)
			local c1, c2 = tocomplex(a, b)
			return setmetatable({r = c1.r - c2.r, i = c1.i - c2.i}, complex)
		end
		complex.__mul = function(a, b)
			local c1, c2 = tocomplex(a, b)
			return setmetatable({r = c1.r * c2.r - c1.i * c2.i, i = c1.r * c2.i + c1.i * c2.r}, complex)
		end
		complex.__index = complex
		complex_t = function(r, i)
			return setmetatable({r = r, i = i}, complex)
		end
	end
	local function polar(theta)
		return complex_t(math.cos(theta), math.sin(theta))
	end
	local function magnitude(c)
		return math.sqrt(c.r^2 + c.i^2)
	end
	-- Fast Fourier Transform
	local function fft(x)
		-- Check recursion break
		local N = x.n
		if N > 1 then
			-- Divide
			local even, odd = {n = 0}, {n = 0}
			for i=1, N, 2 do
				even.n = even.n + 1
				even[even.n] = x[i]
			end
			for i=2, N, 2 do
				odd.n = odd.n + 1
				odd[odd.n] = x[i]
			end
			-- Conquer
			fft(even)
			fft(odd)
			--Combine
			local t
			for k = 1, N/2 do
				t = polar(-2 * math.pi * (k-1) / N) * odd[k]
				x[k] = even[k] + t
				x[k+N/2] = even[k] - t
			end
		end
	end
	-- Numbers to complex numbers
	local data = {n = 0}
	for _, sample in ipairs(samples) do
		data.n = data.n + 1
		data[data.n] = complex_t(sample, 0)
	end
	-- Process FFT
	fft(data)
	-- Complex numbers to numbers
	for i = 1, data.n do
		data[i] = magnitude(data[i])
	end
	return data
end

--[[
	Convert samples into an ASS (Advanced Substation Alpha) subtitle shape code.
]]
function audio_to_ass(samples, wave_width, wave_height_scale, wave_thickness)
	-- Check function parameters
	if type(samples) ~= "table" or not samples[1] or
		type(wave_width) ~= "number" or wave_width <= 0 or
		type(wave_height_scale) ~= "number" or
		type(wave_thickness) ~= "number" or wave_thickness <= 0 then
		error("samples table, positive wave width, height scale and thickness expected", 2)
	end
	for _, sample in ipairs(samples) do
		if type(sample) ~= "number" then
			error("table have only to contain numbers", 2)
		end
	end
	-- Better fitting forms of known variables for most use
	local thick2, samples_n = wave_thickness / 2, #samples
	-- Build shape
	local shape = string.format("m 0 %d l", samples[1] * wave_height_scale - thick2)
	for i=2, samples_n do
		shape = string.format("%s %d %d", shape, (i-1) / (samples_n-1) * wave_width, samples[i] * wave_height_scale - thick2)
	end
	for i=samples_n, 1, -1 do
		shape = string.format("%s %d %d", shape, (i-1) / (samples_n-1) * wave_width, samples[i] * wave_height_scale + thick2)
	end
	return shape
end