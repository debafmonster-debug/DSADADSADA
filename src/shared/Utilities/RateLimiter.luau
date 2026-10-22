--!nonstrict
-- Per-key token bucket for remote spam protection.
local RateLimiter = {}
RateLimiter.__index = RateLimiter

export type RateLimiter = typeof(setmetatable({} :: { capacity: number, refill: number, buckets: { [any]: { tokens: number, last: number } } }, RateLimiter))

function RateLimiter.new(capacity: number, refillPerSecond: number): RateLimiter
	return setmetatable({ capacity = capacity, refill = refillPerSecond, buckets = {} }, RateLimiter)
end

function RateLimiter.allow(self: RateLimiter, key: any, cost: number?): boolean
	local now = os.clock()
	local b = self.buckets[key]
	if not b then
		b = { tokens = self.capacity, last = now }
		self.buckets[key] = b
	end
	b.tokens = math.min(self.capacity, b.tokens + (now - b.last) * self.refill)
	b.last = now
	local c = cost or 1
	if b.tokens >= c then
		b.tokens -= c
		return true
	end
	return false
end

function RateLimiter.forget(self: RateLimiter, key: any)
	self.buckets[key] = nil
end

return RateLimiter
