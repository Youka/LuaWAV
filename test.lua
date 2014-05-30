dofile("wav.lua")

-- Write audio file
local samples, freq = {n = 0}, math.pi * 2 * 500
for i = 0, 44100*3 do
	for c = 1, 2 do
		samples.n = samples.n + 1
		samples[samples.n] = math.sin(i % 44100 / 44099 * freq) * 32767
	end
end
local writer = wav.create_context("out.wav", "w")
writer.init(2, 44100, 16)
writer.write_samples_interlaced(samples)
writer.finish()

-- Read audio file
local reader = wav.create_context("out.wav", "r")
print("Filename: " .. reader.get_filename())
print("Mode: " .. reader.get_mode())
print("File size: " .. reader.get_file_size())
print("Channels: " .. reader.get_channels_number())
print("Sample rate: " .. reader.get_sample_rate())
print("Byte rate: " .. reader.get_byte_rate())
print("Block align: " .. reader.get_block_align())
print("Bitdepth: " .. reader.get_bits_per_sample())
print("Samples per channel: " .. reader.get_samples_per_channel())
print("Sample at 500ms: " .. reader.get_sample_from_ms(500))
print("Milliseconds from 3rd sample: " .. reader.get_ms_from_sample(3))
print(string.format("Min- & maximal amplitude: %d <-> %d", reader.get_min_max_amplitude()))
reader.set_position(256)
print("Sample 256, channel 2: " .. reader.get_samples(1)[2][1])

-- Get first frequencies
reader.set_position(0)
local samples = reader.get_samples(1024)[1]
for i=1, samples.n do
	samples[i] = samples[i] / 32768
end
local analyzer = wav.create_frequency_analyzer(samples, reader.get_sample_rate())
print("\nFrequency weight 400-600Hz: " .. analyzer.get_frequency_range_weight(400,600))
print("FREQUENCY: WEIGHT")
for _, frequency in ipairs(analyzer.get_frequencies()) do
	print(string.format("%.2f: %f", frequency.freq, frequency.weight))
end

-- Audio samples to ASS
local filename, ms_to_play = "out.wav", 1000
local file = io.open("audio.ass", "w")
file:write(string.format([[[Script Info]
Title: Audio to ASS
ScriptType: v4.00+
WrapStyle: 0
ScaledBorderAndShadow: yes
PlayResX: 1280
PlayResY: 720
Video file: ?dummy:25.000000:2250:1280:720:0:0:0:
Audio file: %s
Audio URI: %s

[V4+ Styles]
Format: Name, Fontname, Fontsize, PrimaryColour, SecondaryColour, OutlineColour, BackColour, Bold, Italic, Underline, StrikeOut, ScaleX, ScaleY, Spacing, Angle, BorderStyle, Outline, Shadow, Alignment, MarginL, MarginR, MarginV, Encoding
Style: Default,Arial,30,&H00FFFFFF,&H000000FF,&H00000000,&H00000000,0,0,0,0,100,100,0,0,1,2,0,7,0,0,0,1

[Events]
Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text]], filename, filename))
local function ass_timestamp(t)
	local ms = t % 1000
	t = math.floor(t / 1000)
	local s = t % 60
	t = math.floor(t / 60)
	local m = t % 60
	t = math.floor(t / 60)
	local h = t
	return string.format("%02d:%02d:%02d.%02d", h, m, s, ms / 10)
end
reader = wav.create_context(filename, "r")
local chunk_size = reader.get_sample_from_ms(40)
for ms = 0, ms_to_play-1, 40 do
	reader.set_position(math.floor(reader.get_sample_from_ms(ms)))
	file:write(string.format("\nDialogue: 0,%s,%s,Default,,0,0,0,,{\\pos(10,300)\\c&H4040FF&\\p1}%s", ass_timestamp(ms), ass_timestamp(ms+40), audio_to_ass(reader.get_samples(chunk_size)[1], 1000, 1/162, 6)))
end