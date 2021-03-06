local component=require("component")
if not component.isAvailable("gpu") then
	test.logp("Skipping gpu tests")
	return
end
local test=require("test")
local unicode=require("unicode")
local event=require("event")
local gpu=component.gpu

print("Backing up GPU ...")
local gpuW, gpuH=gpu.getResolution()
local depth=gpu.getDepth()
local fgc, fgp=gpu.getForeground()
local bgc, bgp=gpu.getBackground()
local palcol
if depth > 1 then
	palcol={}
	for i=0, 15 do
		palcol[i]=gpu.getPaletteColor(i)
	end
end

do
-- Subtly test for screen_resized event.
local detectedResizedEvent=false
local function detectResizeEvent()
	detectedResizedEvent=true
	return false
end
event.listen("screen_resized", detectResizeEvent)

print("Configuring GPU ...")
gpu.setResolution(50, 16)
gpu.setForeground(0x1DDDDDD)
gpu.setBackground(0x1234567)
gpu.setDepth(1)

local monochrome=0xFFFFFF
test.log(string.format("These GPU tests assume your monochrome color is set to %06X", monochrome))
test.log(string.format("If your current monochrome color is not %06X, please change it and try again", monochrome))

-- Common tier tests

-- Foreground and Background tests
local color
color=gpu.setForeground(0xABCDEF)
test.compare(0x1DDDDDD, color)
color=gpu.getForeground()
test.compare(0xABCDEF, color)
color=gpu.setBackground(0x000000)
test.compare(0x1234567, color)
color=gpu.getBackground()
test.compare(0x000000, color)

gpu.fill(1, 1, 50, 16, " ")
local spaces=0
local fg=0
local bg=0
for x=1, 50 do
	local char, gfc, gbc=gpu.get(x, 1)
	if char == " " then
		spaces=spaces + 1
	end
	if gfc == monochrome then
		fg=fg + 1
	end
	if gbc == 0x000000 then
		bg=bg + 1
	end
end
test.compare(50, spaces)
test.compare(50, fg)
test.compare(50, bg)

local wide=unicode.char(0x3000) -- Nothing special about this character

-- Set/Get tests
gpu.set(1, 1, ("Hello Wide World"):gsub(" ", wide) .. "")
test.evaluate("d", gpu.get, 18, 1)
gpu.set(1, 1, ("Hello There"):gsub(" ", wide) .. "", true)
test.evaluate("e", gpu.get, 1, 11)
gpu.set(7, 1, "x")
test.evaluate(" ", gpu.get, 7, 1)
gpu.set(6, 1, " x")
test.evaluate("x", gpu.get, 7, 1)
gpu.set(6, 1, wide)
test.evaluate(" ", gpu.get, 7, 1)
gpu.set(50, 1, "x")
gpu.set(50, 1, wide)
test.evaluate("x", gpu.get, 50, 1)
test.evaluate(true, gpu.set, 1.63, 1.34, "r")
test.evaluate("r", gpu.get, 1.99, 1.99)
test.shouldError(gpu.get, 0, 1)
test.shouldError(gpu.get, 51, 1)
test.shouldError(gpu.get, 1, 0)
test.shouldError(gpu.get, 1, 17)
test.shouldNotError(gpu.get, 50.99, 1)
test.valueMatch(table.pack("r", monochrome, 0, nil, nil), gpu.get, 1, 1)

-- Fill tests
gpu.fill(1, 1, 50, 16, " ")
gpu.fill(2, 2, 6, 7, "x")
test.evaluate("x", gpu.get, 2, 2)
test.evaluate("x", gpu.get, 7, 2)
test.evaluate("x", gpu.get, 2, 8)
test.evaluate("x", gpu.get, 7, 8)
gpu.fill(2, 2, 6, 7, wide)
test.evaluate(wide, gpu.get, 2, 2)
test.evaluate(wide, gpu.get, 12, 2)
test.evaluate(wide, gpu.get, 2, 8)
test.evaluate(wide, gpu.get, 12, 8)
test.evaluate(" ", gpu.get, 3, 2)
gpu.set(50, 1, "x")
gpu.fill(50, 1, 1, 1, wide)
test.evaluate("x", gpu.get, 50, 1)
test.valueMatch(table.pack(nil, "invalid fill value"), gpu.fill, 1, 1, 1, 1, "xx")
test.valueMatch(table.pack(nil, "invalid fill value"), gpu.fill, 1, 1, 1, 1, string.rep(wide, 2))
test.evaluate(true, gpu.fill, 1, 1, 1, 1, "x")
test.evaluate(true, gpu.fill, 1, 1, 1, 1, wide)

-- Copy tests
gpu.copy(4, 2, 9, 7, -1, 0)
test.evaluate(wide, gpu.get, 3, 2)
test.evaluate(" ", gpu.get, 12, 2)
test.evaluate(" ", gpu.get, 13, 2)
gpu.fill(2, 2, 6, 7, wide)
gpu.copy(2, 2, 12, 7, 1, 0)
test.evaluate(wide, gpu.get, 3, 2)
test.evaluate(" ", gpu.get, 12, 2)
test.evaluate(wide, gpu.get, 13, 2)
gpu.set(50, 1, "x")
test.shouldNotError(gpu.copy, 2, 2, 1, 1, 48, -1)
-- You will see an x, but be told it's the wide character
test.evaluate(wide, gpu.get, 50, 1)
test.evaluate(true, gpu.copy, -3423, 34536, 4395729, -5435, 0, 0)

-- Palette tests
test.shouldError(gpu.setForeground, monochrome, true)
test.shouldError(gpu.setBackground, 0x000000, true)

-- Depth tests
test.evaluate(1, gpu.getDepth)
for i=0, 9 do
	if i ~= 1 and i ~= 4 and i ~= 8 then
		test.shouldError(gpu.setDepth, i)
	end
end
test.evaluate(1, gpu.getDepth)
test.shouldNotError(gpu.setDepth, 1.5)
test.evaluate(1, gpu.getDepth)

-- Resolution tests
test.evaluate(true, gpu.setResolution, 49, 16)
test.evaluate(true, gpu.setResolution, 50, 16)
test.evaluate(false, gpu.setResolution, 50, 16)
test.shouldError(gpu.setResolution, 0, 1)
test.shouldError(gpu.setResolution, 1, 0)
test.shouldError(gpu.setResolution, 0, 0)
local gpuMW, gpuMH=gpu.maxResolution()
test.shouldError(gpu.setResolution, gpuMW+1, gpuMH)
test.shouldError(gpu.setResolution, gpuMW, gpuMH+1)
test.shouldError(gpu.setResolution, gpuMW+1, gpuMH+1)
gpu.setResolution(50.9, 16.8)
test.valueMatch(table.pack(50, 16), gpu.getResolution)

if gpu.maxDepth() > 1 then

-- Tier 2 tests
test.evaluate("OneBit", gpu.setDepth, 4)
-- Palette Tests
for i=0, 15 do
	gpu.setPaletteColor(i, i)
end
test.evaluate("FourBit", gpu.setDepth, 1)
gpu.setDepth(4) -- Changing depth will change the palette
local t2pal={[0]=0xFFFFFF, 0xFFCC33, 0xCC66CC, 0x6699FF, 0xFFFF33, 0x33CC33, 0xFF6699, 0x333333, 0xCCCCCC, 0x336699, 0x9933CC, 0x333399, 0x663300, 0x336600, 0xFF3333, 0x000000}
for i=0, 15 do
	test.evaluate(t2pal[i], gpu.getPaletteColor, i)
end
test.shouldError(gpu.getPaletteColor, -1)
test.shouldError(gpu.getPaletteColor, 16)
test.shouldError(gpu.setPaletteColor, -1, 0)
test.shouldError(gpu.setPaletteColor, 16, 0)
gpu.setPaletteColor(0, 0xFEDCBA)
test.evaluate(0xFEDCBA, gpu.setPaletteColor, 0, 0xFFFFFF)
gpu.setForeground(0, true)
test.valueMatch(table.pack(0, true), gpu.getForeground)
gpu.setBackground(15, true)
test.valueMatch(table.pack(15, true), gpu.getBackground)
gpu.fill(1, 1, 50, 16, " ")
test.valueMatch(table.pack(" ", 0xFFFFFF, 0, 0, 15), gpu.get, 1, 1)
gpu.setBackground(0x000000)
gpu.setForeground(0xFFCC33)
gpu.set(1, 1, "x")
test.valueMatch(table.pack("x", 0xFFCC33, 0, 1, 15), gpu.get, 1, 1)
gpu.setPaletteColor(1, 0xFEDCBA)
test.valueMatch(table.pack("x", 0xFEDCBA, 0, 1, 15), gpu.get, 1, 1)
gpu.setForeground(0xCCCCCC)
test.valueMatch(table.pack(0xCCCCCC, false), gpu.getForeground)
gpu.setBackground(0x333333)
test.valueMatch(table.pack(0x333333, false), gpu.getBackground)
gpu.setDepth(1) -- Changing depth will also decolor the screen
test.valueMatch(table.pack("x", monochrome, 0, nil, nil), gpu.get, 1, 1)
if gpu.maxDepth() > 4 then

-- Tier 3 tests
gpu.setDepth(8)
for i=0, 15 do
	test.evaluate((i+1)*0x0F0F0F, gpu.getPaletteColor, i)
end
gpu.setBackground(0x002440)
gpu.setForeground(0xFFDBBF)
gpu.set(1, 1, "x")
test.valueMatch(table.pack("x", 0xFFDBBF, 0x002440, nil, nil), gpu.get, 1, 1)

else -- maxDepth() == 4

test.shouldError(gpu.setDepth, 8)

end -- maxDepth() > 4

else -- maxDepth() == 1

test.shouldError(gpu.setDepth, 4)
test.shouldError(gpu.setDepth, 8)

end -- maxDepth() > 1

-- Check if screen_resized event fired
os.sleep(0.05)
test.compare(true, detectedResizedEvent) -- this test is unstable
end

print("Restoring GPU ...")
gpu.setResolution(gpuW, gpuH)
gpu.setDepth(depth)
gpu.setForeground(fgc, fgp)
gpu.setBackground(bgc, bgp)
if palcol then
	for i=0, 15 do
		gpu.setPaletteColor(i, palcol[i])
	end
end
gpu.fill(1, 1, gpuW, gpuH, " ")
