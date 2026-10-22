--!nocheck
local H = require("./harness")
local S = H.load()
local Missions = S.require(S.path("ReplicatedStorage.Shared.Config.Missions"))
local Gen = S.require(S.path("ServerScriptService.NightShift.Services.LayoutGenerator"))
local Val = S.require(S.path("ServerScriptService.NightShift.Services.LayoutValidator"))

print("Layout generator")
for missionId in Missions.Defs do
	local fallbacks = 0
	local attemptsTotal = 0
	for seed = 1, 40 do
		H.test(string.format("%s seed %d", missionId, seed), function()
			local layout, log = Gen.generate(seed * 1013, missionId)
			local ok, errors = Val.validate(layout, Gen.requiredKinds(Missions.Defs[missionId]))
			assert(ok, table.concat(errors, "; "))
			assert(#layout.nodes >= 14 and #layout.nodes <= 30, "node count " .. #layout.nodes)
			if layout.fallback then
				fallbacks += 1
			end
			attemptsTotal += layout.attempts
			-- D must be entered only via one security door
			local dEntries = 0
			local byId = {}
			for _, n in layout.nodes do byId[n.id] = n end
			for _, e in layout.edges do
				local a, b = byId[e.a], byId[e.b]
				if (a.sector == "D") ~= (b.sector == "D") then
					dEntries += 1
					assert(e.doorType == "security", "D entry must be security door")
				end
			end
			assert(dEntries == 1, "D entries " .. dEntries)
			local _ = log
		end)
	end
	print(string.format("  %s: fallbacks=%d avg attempts=%.2f", missionId, fallbacks, attemptsTotal / 40))
	assert(fallbacks <= 4, "too many fallbacks for " .. missionId)
end

H.test("same seed reproduces identical layout", function()
	local a = Gen.generate(4242, "ch1_last_shift")
	local b = Gen.generate(4242, "ch1_last_shift")
	H.eq(#a.nodes, #b.nodes)
	for i, n in a.nodes do
		H.eq(n.moduleId, b.nodes[i].moduleId)
		H.eq(n.x, b.nodes[i].x)
		H.eq(n.z, b.nodes[i].z)
	end
end)

H.test("fallback layouts valid for every mission", function()
	for id, def in Missions.Defs do
		local fb = Gen.fallback(def)
		local ok, errors = Val.validate(fb, Gen.requiredKinds(def))
		assert(ok, id .. ": " .. table.concat(errors, "; "))
	end
end)

H.finish()
