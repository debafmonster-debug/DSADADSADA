--!nonstrict
-- Sound library. Only Roblox built-in client assets (rbxasset://sounds/*) are
-- referenced so every id is guaranteed to exist. They are functional
-- placeholders: replace with licensed horror audio by editing this table only.
export type SoundDef = { id: string, volume: number, looped: boolean?, pitch: number?, rollOff: number? }

local Sounds: { [string]: SoundDef } = {
	-- UI / tools
	UIClick = { id = "rbxasset://sounds/clickfast.wav", volume = 0.35 },
	UIConfirm = { id = "rbxasset://sounds/electronicpingshort.wav", volume = 0.5 },
	UIError = { id = "rbxasset://sounds/button.wav", volume = 0.5, pitch = 0.7 },
	ToolBeep = { id = "rbxasset://sounds/electronicpingshort.wav", volume = 0.5, pitch = 1.2 },
	ToolWrench = { id = "rbxasset://sounds/snap.wav", volume = 0.6, pitch = 0.8 },
	ToolZip = { id = "rbxasset://sounds/unsheath.wav", volume = 0.4, pitch = 0.9 },
	Switch = { id = "rbxasset://sounds/switch3.wav", volume = 0.7 },
	FlashlightClick = { id = "rbxasset://sounds/switch3.wav", volume = 0.45, pitch = 1.4 },
	TerminalKey = { id = "rbxasset://sounds/clickfast.wav", volume = 0.3, pitch = 1.3 },

	-- environment
	AmbientHum = { id = "rbxasset://sounds/bass.wav", volume = 0.12, looped = true, pitch = 0.5 },
	VentHum = { id = "rbxasset://sounds/Rocket whoosh 01.wav", volume = 0.08, looped = true, pitch = 0.35, rollOff = 30 },
	Relay = { id = "rbxasset://sounds/clickfast.wav", volume = 0.5, pitch = 0.6, rollOff = 20 },
	MetalHit = { id = "rbxasset://sounds/metal.ogg", volume = 0.6, pitch = 0.6, rollOff = 60 },
	DoorSlide = { id = "rbxasset://sounds/Short spring sound.wav", volume = 0.6, pitch = 0.6, rollOff = 30 },
	DoorLocked = { id = "rbxasset://sounds/button.wav", volume = 0.6, pitch = 0.5, rollOff = 20 },
	Alarm = { id = "rbxasset://sounds/Launching rocket.wav", volume = 0.5, looped = true, pitch = 0.5 },
	PowerUp = { id = "rbxasset://sounds/Rocket shot.wav", volume = 0.6, pitch = 0.5 },
	Glass = { id = "rbxasset://sounds/glassbreak.wav", volume = 0.5 },
	Announce = { id = "rbxasset://sounds/electronicpingshort.wav", volume = 0.6, pitch = 0.8 },

	-- creature
	WardenStep = { id = "rbxasset://sounds/impact_generic.mp3", volume = 0.55, pitch = 0.5, rollOff = 55 },
	WardenStepChase = { id = "rbxasset://sounds/impact_generic.mp3", volume = 0.8, pitch = 0.7, rollOff = 80 },
	WardenSuspicious = { id = "rbxasset://sounds/HalloweenGhost.wav", volume = 0.5, pitch = 0.55, rollOff = 70 },
	WardenAttack = { id = "rbxasset://sounds/swoosh.wav", volume = 0.9, pitch = 0.6, rollOff = 50 },
	WardenGearCreak = { id = "rbxasset://sounds/Rubber band snap.wav", volume = 0.35, pitch = 0.4, rollOff = 40 },

	-- player
	Hurt = { id = "rbxasset://sounds/uuhhh.mp3", volume = 0.7 },
	Downed = { id = "rbxasset://sounds/action_falling.mp3", volume = 0.6, pitch = 0.6 },
	Revive = { id = "rbxasset://sounds/action_get_up.mp3", volume = 0.6 },
	FootConcrete = { id = "rbxasset://sounds/action_footsteps_plastic.mp3", volume = 0.35, pitch = 0.85 },
	FootMetal = { id = "rbxasset://sounds/action_footsteps_plastic.mp3", volume = 0.45, pitch = 1.1 },

	-- music states (layered placeholders)
	MusicLobby = { id = "rbxasset://sounds/bass.wav", volume = 0.07, looped = true, pitch = 0.42 },
	MusicExplore = { id = "rbxasset://sounds/bass.wav", volume = 0.05, looped = true, pitch = 0.3 },
	MusicSuspicion = { id = "rbxasset://sounds/HalloweenGhost.wav", volume = 0.12, looped = true, pitch = 0.3 },
	MusicChase = { id = "rbxasset://sounds/Launching rocket.wav", volume = 0.22, looped = true, pitch = 0.9 },
	MusicEvac = { id = "rbxasset://sounds/Launching rocket.wav", volume = 0.14, looped = true, pitch = 0.6 },
	MusicResult = { id = "rbxasset://sounds/victory.wav", volume = 0.3 },

	-- in-engine shorts (prologue "Станция Восток"); played 2D by CinematicController
	CineWind = { id = "rbxasset://sounds/Rocket whoosh 01.wav", volume = 0.35, looped = true, pitch = 0.45 },
	CineDrill = { id = "rbxasset://sounds/bass.wav", volume = 0.3, looped = true, pitch = 0.7 },
	CineStatic = { id = "rbxasset://sounds/Rocket whoosh 01.wav", volume = 0.3, looped = true, pitch = 1.7 },
	CineBoom = { id = "rbxasset://sounds/impact_generic.mp3", volume = 0.9, pitch = 0.45 },
	CineSting = { id = "rbxasset://sounds/HalloweenGhost.wav", volume = 0.6, pitch = 0.8 },
	CineRelay = { id = "rbxasset://sounds/switch3.wav", volume = 0.7, pitch = 0.6 },
	MusicCinematic = { id = "rbxasset://sounds/HalloweenGhost.wav", volume = 0.1, looped = true, pitch = 0.45 },
}

return Sounds
