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

-- To ASS
local filename, ms_to_play = "bad_apple.wav", 1000
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
local function floor_pow2(n)
	local p = 2
	while p < n do
		p = p * 2
	end
	return p / 2
end
local reader = wav(filename, "r")
local chunk_size = reader.get_sample_from_ms(40)
local chunk_size_pow2 = floor_pow2(chunk_size)
local line_template, start_sample, samples
for ms = 0, ms_to_play-1, 40 do
	line_template = string.format("\nDialogue: 0,%s,%s,Default,,0,0,0,,", ass_timestamp(ms), ass_timestamp(ms+40))
	start_sample = math.floor(reader.get_sample_from_ms(ms))
	reader.set_position(start_sample)
	file:write(line_template .. "{\\pos(10,300)\\c&H4040FF&\\p1}" .. audio_to_ass(reader.get_samples(chunk_size)[1], 1000, 1/162, 6))
	reader.set_position(start_sample)
	samples = reader.get_samples(chunk_size_pow2)[1]
	for i=1, samples.n do
		samples[i] = samples[i] / 32768
	end
	samples = samples_transform(samples)
	for i=1, samples.n do
		samples[i] = -samples[i]
	end
	file:write(line_template .. "{\\pos(10,700)\\c&HFF4040&\\p1}" .. audio_to_ass(samples, 1000, 2, 6))
end