--!nonstrict
-- Deterministic PRNG (PCG-style LCG on 32-bit) so a layout seed reproduces
-- exactly the same complex in Studio, on live servers and in Lune tests.
local SeededRandom = {}
SeededRandom.__index = SeededRandom

export type SeededRandom = typeof(setmetatable({} :: { state: number, seed: number }, SeededRandom))

local MOD = 2 ^ 32

function SeededRandom.new(seed: number): SeededRandom
	local s = math.floor(math.abs(seed)) % MOD
	local self = setmetatable({ state = s, seed = s }, SeededRandom)
	for _ = 1, 3 do
		self:nextUint()
	end
	return self
end

function SeededRandom.nextUint(self: SeededRandom): number
	-- glibc LCG multiplier 1103515245 split into 16-bit halves so the product
	-- stays exact in doubles.
	local s = self.state
	local hi = math.floor(s / 65536)
	local lo = s % 65536
	local aHi, aLo = 16838, 20077
	local prod = ((aHi * lo + aLo * hi) % 65536) * 65536 + aLo * lo
	s = (prod + 12345) % MOD
	self.state = s
	return s
end

function SeededRandom.nextNumber(self: SeededRandom, min: number?, max: number?): number
	local r = self:nextUint() / MOD
	if min and max then
		return min + (max - min) * r
	end
	return r
end

function SeededRandom.nextInteger(self: SeededRandom, min: number, max: number): number
	return min + math.floor(self:nextNumber() * (max - min + 1))
end

function SeededRandom.chance(self: SeededRandom, p: number): boolean
	return self:nextNumber() < p
end

function SeededRandom.pick<T>(self: SeededRandom, list: { T }): T
	return list[self:nextInteger(1, #list)]
end

function SeededRandom.shuffle<T>(self: SeededRandom, list: { T }): { T }
	local out = table.clone(list)
	for i = #out, 2, -1 do
		local j = self:nextInteger(1, i)
		out[i], out[j] = out[j], out[i]
	end
	return out
end

return SeededRandom
