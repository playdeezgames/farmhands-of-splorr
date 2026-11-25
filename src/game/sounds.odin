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
}

sound_for :: proc(events: bit_set[Event]) -> Sfx {
	switch {
	case .Quit in events:
		return .Quit
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
	case .Bought in events:
		return .Buy
	case .Hired in events:
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
