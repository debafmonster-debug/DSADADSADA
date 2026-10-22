--!nonstrict
-- Minimal typed signal (no BindableEvent allocation; handlers run in order).
export type Connection = { Disconnect: (self: Connection) -> () }
export type Signal<T...> = {
	Connect: (self: Signal<T...>, fn: (T...) -> ()) -> Connection,
	Once: (self: Signal<T...>, fn: (T...) -> ()) -> Connection,
	Fire: (self: Signal<T...>, T...) -> (),
	Wait: (self: Signal<T...>) -> T...,
	Destroy: (self: Signal<T...>) -> (),
}

local Signal = {}
Signal.__index = Signal

function Signal.new<T...>(): Signal<T...>
	return setmetatable({ _handlers = {} :: { any } }, Signal) :: any
end

function Signal:Connect(fn)
	local handlers = self._handlers
	local entry = { fn = fn, alive = true }
	table.insert(handlers, entry)
	return {
		Disconnect = function()
			entry.alive = false
			local i = table.find(handlers, entry)
			if i then
				table.remove(handlers, i)
			end
		end,
	}
end

function Signal:Once(fn)
	local conn
	conn = self:Connect(function(...)
		conn:Disconnect()
		fn(...)
	end)
	return conn
end

function Signal:Fire(...)
	for _, entry in table.clone(self._handlers) do
		if entry.alive then
			task.spawn(entry.fn, ...)
		end
	end
end

function Signal:Wait()
	local thread = coroutine.running()
	self:Once(function(...)
		task.spawn(thread, ...)
	end)
	return coroutine.yield()
end

function Signal:Destroy()
	table.clear(self._handlers)
end

return Signal
