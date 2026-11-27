package game

// The one sound the page plays after a command or tap, picked from what happened. The WAVs are made
// in the Anvil (assets/anvil/world.json, exported to assets/sfx/); the page's SFX list must match
// this order.

Sfx :: enum i32 {
	None,
	Blip,
	Plant,
	Hire,
	Harvest,
	Sell,
	Seed,
	Turn,
	Hungry,
	Quit,
	Denied,
	Buy,
	Rats,
	Cat,
	Build,
	Crows,
	Wander,
	Dismiss,
	Fall,
	Rot,
	Manure,
	License,
	Goal,
}

sound_for :: proc(events: bit_set[Event]) -> Sfx {
	switch {
	case .Goal in events:
		return .Goal
	case .Quit in events:
		return .Quit
	case .Rats in events:
		return .Rats
	case .Crows in events:
		return .Crows
	case .Wandered in events:
		return .Wander
	case .Fell in events:
		return .Fall
	case .Rotted in events:
		return .Rot
	case .Hungry in events:
		return .Hungry
	case .Turned in events:
		return .Turn
	case .Harvested in events:
		return .Harvest
	case .Sold in events:
		return .Sell
	case .Seeded in events:
		return .Seed
	case .Built in events, .Placed in events:
		return .Build
	case .Dismissed in events:
		return .Dismiss
	case .Manured in events:
		return .Manure
	case .Cat in events:
		return .Cat
	case .Licensed in events:
		return .License
	case .Bought in events:
		return .Buy
	case .Hired in events, .Carried in events:
		return .Hire
	case .Planted in events:
		return .Plant
	case .Denied in events:
		return .Denied
	case .Moved in events:
		return .Blip
	}
	return .None
}
