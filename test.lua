dofile("wav.lua")

-- Write
local out, samples, freq = wav("out.wav", "w"), {n = 0}, math.pi * 2 * 300
out.init(2, 22050, 16)
for i = 0, 66150 do
	for c = 1, 2 do
		samples.n = samples.n + 1
		samples[samples.n] = math.sin(i % 22050 / 22049 * freq) * 32767
	end
end
out.write_samples_interlaced(samples)
out.finish()

-- Read
local inp = wav("out.wav", "r")
print("Filename: " .. inp.get_filename())
print("Mode: " .. inp.get_mode())
print("File size: " .. inp.get_file_size())
print("Channels: " .. inp.get_channels_number())
print("Sample rate: " .. inp.get_sample_rate())
print("Byte rate: " .. inp.get_byte_rate())
print("Block align: " .. inp.get_block_align())
print("Bitdepth: " .. inp.get_bits_per_sample())
print("Samples per channel: " .. inp.get_samples_per_channel())
print("Sample at 500ms: " .. inp.get_sample_from_ms(500))
print("Milliseconds from 3rd sample: " .. inp.get_ms_from_sample(3))
print(string.format("Min- & maximal amplitude: %d <-> %d", inp.get_min_max_amplitude()))
inp.set_position(1024)
print("Sample 1024, channel 2: " .. inp.get_samples(1)[2][1])

-- Transformation
local transformed_samples = samples_transform(inp.get_samples(256)[1])
for _, sample in ipairs(transformed_samples) do
	print(sample)
end