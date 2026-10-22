--!nonstrict
-- Sound registry. IMPORTANT: every id below is a built-in client sound
-- (rbxasset://sounds/*) used as a PLACEHOLDER so the audio pipeline can be
-- exercised end-to-end without inventing marketplace asset ids. Replace the
-- `id` fields with authored assets; keep the keys. Voice lines are declared
-- with id = nil and are driven by subtitles until audio exists.
local Sounds = {}

export type SoundDef = { id: string?, volume: number, looped: boolean?, pitch: number?, rollOff: number?, placeholder: boolean?, category: string? }

local function def(id: string?, volume: number, extra: { [string]: any }?): SoundDef
	local d: SoundDef = { id = id, volume = volume, placeholder = true }
	if extra then
		for k, v in extra do
			d[k] = v
		end
	end
	return d
end

-- UI / tools
Sounds.UIClick = def("rbxasset://sounds/clickfast.wav", 0.35, { category = "sfx" })
Sounds.UIConfirm = def("rbxasset://sounds/electronicpingshort.wav", 0.45, { category = "sfx" })
Sounds.UIError = def("rbxasset://sounds/button.wav", 0.5, { pitch = 0.7, category = "sfx" })
Sounds.ToolBeep = def("rbxasset://sounds/electronicpingshort.wav", 0.4, { pitch = 1.3, category = "sfx" })
Sounds.ToolWrench = def("rbxasset://sounds/snap.wav", 0.5, { pitch = 0.8, category = "sfx" })
Sounds.ToolZip = def("rbxasset://sounds/unsheath.wav", 0.4, { category = "sfx" })
Sounds.Switch = def("rbxasset://sounds/switch3.wav", 0.6, { category = "sfx" })
Sounds.FlashlightClick = def("rbxasset://sounds/switch3.wav", 0.5, { pitch = 1.25, category = "sfx" })
Sounds.KeypadKey = def("rbxasset://sounds/clickfast.wav", 0.4, { pitch = 1.1, category = "sfx" })
Sounds.KeypadDeny = def("rbxasset://sounds/button.wav", 0.6, { pitch = 0.6, category = "sfx" })
Sounds.KeypadAccept = def("rbxasset://sounds/electronicpingshort.wav", 0.6, { pitch = 0.9, category = "sfx" })

-- Environment
Sounds.Wind = def("rbxasset://sounds/Rocket whoosh 01.wav", 0.45, { looped = true, pitch = 0.42, rollOff = 400, category = "ambient" })
Sounds.WindGust = def("rbxasset://sounds/swoosh.wav", 0.5, { pitch = 0.5, rollOff = 120, category = "ambient" })
Sounds.GeneratorHum = def("rbxasset://sounds/bass.wav", 0.55, { looped = true, pitch = 0.55, rollOff = 70, category = "ambient" })
Sounds.GeneratorStrain = def("rbxasset://sounds/bass.wav", 0.6, { looped = true, pitch = 0.4, rollOff = 70, category = "ambient" })
Sounds.VentHum = def("rbxasset://sounds/Launching rocket.wav", 0.18, { looped = true, pitch = 0.3, rollOff = 30, category = "ambient" })
Sounds.HeaterHum = def("rbxasset://sounds/Launching rocket.wav", 0.14, { looped = true, pitch = 0.22, rollOff = 18, category = "ambient" })
Sounds.ClockTick = def("rbxasset://sounds/clickfast.wav", 0.25, { pitch = 0.6, rollOff = 22, category = "ambient" })
Sounds.Relay = def("rbxasset://sounds/switch3.wav", 0.7, { pitch = 0.75, rollOff = 40, category = "sfx" })
Sounds.LampBuzz = def("rbxasset://sounds/Launching rocket.wav", 0.08, { looped = true, pitch = 0.9, rollOff = 12, category = "ambient" })
Sounds.LampFlicker = def("rbxasset://sounds/Rubber band snap.wav", 0.25, { pitch = 1.6, rollOff = 18, category = "sfx" })
Sounds.PowerDown = def("rbxasset://sounds/bass.wav", 0.7, { pitch = 0.3, rollOff = 120, category = "sfx" })
Sounds.PowerUp = def("rbxasset://sounds/Launching rocket.wav", 0.5, { pitch = 0.5, rollOff = 120, category = "sfx" })
Sounds.MetalHit = def("rbxasset://sounds/metal.ogg", 0.7, { rollOff = 40, category = "sfx" })
Sounds.MetalCreak = def("rbxasset://sounds/Short spring sound.wav", 0.5, { pitch = 0.5, rollOff = 50, category = "sfx" })
Sounds.DoorSwing = def("rbxasset://sounds/Short spring sound.wav", 0.55, { pitch = 0.7, rollOff = 36, category = "sfx" })
Sounds.DoorHeavy = def("rbxasset://sounds/metal.ogg", 0.8, { pitch = 0.6, rollOff = 60, category = "sfx" })
Sounds.DoorLocked = def("rbxasset://sounds/button.wav", 0.6, { pitch = 0.5, rollOff = 20, category = "sfx" })
Sounds.DoorHandle = def("rbxasset://sounds/snap.wav", 0.55, { pitch = 0.6, rollOff = 26, category = "sfx" })
Sounds.Knock = def("rbxasset://sounds/impact_generic.mp3", 0.8, { pitch = 0.7, rollOff = 40, category = "sfx" })
Sounds.HatchOpen = def("rbxasset://sounds/metal.ogg", 0.9, { pitch = 0.45, rollOff = 50, category = "sfx" })
Sounds.Lever = def("rbxasset://sounds/snap.wav", 0.7, { pitch = 0.55, rollOff = 40, category = "sfx" })
Sounds.ScannerOk = def("rbxasset://sounds/electronicpingshort.wav", 0.7, { pitch = 1.0, rollOff = 36, category = "sfx" })
Sounds.ScannerDeny = def("rbxasset://sounds/button.wav", 0.9, { pitch = 0.45, rollOff = 50, category = "sfx" })
Sounds.RadioStatic = def("rbxasset://sounds/Rocket whoosh 01.wav", 0.35, { looped = true, pitch = 1.6, rollOff = 26, category = "sfx" })
Sounds.RadioClick = def("rbxasset://sounds/clickfast.wav", 0.5, { pitch = 0.8, rollOff = 26, category = "sfx" })
Sounds.RadioTune = def("rbxasset://sounds/electronicpingshort.wav", 0.3, { pitch = 0.5, rollOff = 26, category = "sfx" })
Sounds.Alarm = def("rbxasset://sounds/HalloweenLightning.wav", 0.5, { pitch = 0.8, rollOff = 120, category = "sfx" })
Sounds.Glass = def("rbxasset://sounds/glassbreak.wav", 0.6, { rollOff = 40, category = "sfx" })
Sounds.PhoneRing = def("rbxasset://sounds/electronicpingshort.wav", 0.7, { pitch = 0.75, category = "sfx" })
Sounds.TVStatic = def("rbxasset://sounds/Rocket whoosh 01.wav", 0.12, { looped = true, pitch = 2.2, rollOff = 14, category = "ambient" })
Sounds.CarEngine = def("rbxasset://sounds/bass.wav", 0.5, { looped = true, pitch = 0.7, rollOff = 80, category = "sfx" })
Sounds.PlaneEngine = def("rbxasset://sounds/Launching rocket.wav", 0.8, { looped = true, pitch = 0.45, rollOff = 300, category = "sfx" })

-- Creature («Гость»)
Sounds.GuestStep = def("rbxasset://sounds/impact_generic.mp3", 0.5, { pitch = 0.5, rollOff = 48, category = "sfx" })
Sounds.GuestStepChase = def("rbxasset://sounds/impact_generic.mp3", 0.7, { pitch = 0.65, rollOff = 60, category = "sfx" })
Sounds.GuestBreath = def("rbxasset://sounds/HalloweenGhost.wav", 0.35, { pitch = 0.5, rollOff = 40, category = "sfx" })
Sounds.GuestTouch = def("rbxasset://sounds/metal.ogg", 0.45, { pitch = 0.35, rollOff = 50, category = "sfx" })
Sounds.GuestNotice = def("rbxasset://sounds/HalloweenGhost.wav", 0.5, { pitch = 0.8, rollOff = 60, category = "sfx" })
Sounds.GuestAttack = def("rbxasset://sounds/hit.wav", 0.9, { pitch = 0.6, rollOff = 50, category = "sfx" })
Sounds.DoubleReveal = def("rbxasset://sounds/HalloweenGhost.wav", 0.8, { pitch = 0.6, rollOff = 50, category = "sfx" })

-- Player
Sounds.Hurt = def("rbxasset://sounds/uuhhh.mp3", 0.6, { category = "sfx" })
Sounds.Downed = def("rbxasset://sounds/action_falling.mp3", 0.6, { category = "sfx" })
Sounds.Revive = def("rbxasset://sounds/action_get_up.mp3", 0.6, { category = "sfx" })
Sounds.FootMetal = def("rbxasset://sounds/action_footsteps_plastic.mp3", 0.35, { pitch = 0.9, category = "sfx" })
Sounds.FootConcrete = def("rbxasset://sounds/action_footsteps_plastic.mp3", 0.32, { pitch = 0.75, category = "sfx" })
Sounds.FootSnow = def("rbxasset://sounds/action_footsteps_plastic.mp3", 0.26, { pitch = 0.55, category = "sfx" })
Sounds.FootGrate = def("rbxasset://sounds/action_footsteps_plastic.mp3", 0.38, { pitch = 1.15, category = "sfx" })
Sounds.FootWood = def("rbxasset://sounds/action_footsteps_plastic.mp3", 0.3, { pitch = 0.68, category = "sfx" })
Sounds.Breath = def("rbxasset://sounds/action_swim.mp3", 0.2, { pitch = 0.6, category = "sfx" })
Sounds.Shiver = def("rbxasset://sounds/Rubber band snap.wav", 0.15, { pitch = 0.4, category = "sfx" })
Sounds.Pickup = def("rbxasset://sounds/unsheath.wav", 0.45, { pitch = 1.1, category = "sfx" })

-- Music: sparse; stingers rather than constant tension.
Sounds.MusicLobby = def("rbxasset://sounds/bass.wav", 0.12, { looped = true, pitch = 0.5, category = "music" })
Sounds.MusicStalk = def("rbxasset://sounds/bass.wav", 0.16, { looped = true, pitch = 0.35, category = "music" })
Sounds.MusicChase = def("rbxasset://sounds/Launching rocket.wav", 0.3, { looped = true, pitch = 0.6, category = "music" })
Sounds.MusicResult = def("rbxasset://sounds/victory.wav", 0.4, { category = "music" })

-- Voice hooks (no audio yet). Subtitle timing lives in Config/Dialogue.
Sounds.VoiceDispatcher = { id = nil, volume = 1, category = "voice", placeholder = true }
Sounds.VoicePlayer = { id = nil, volume = 1, category = "voice", placeholder = true }

return Sounds
