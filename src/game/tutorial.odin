package game

// The guided first farm: one goal at a time, shown above the log. Each goal ticks off from what the
// game already does; the rules are the normal ones throughout. Started by a fresh visit or the Help
// tab's Tutorial button, skipped from the same button.

Tutorial_Step :: struct {
	goal: string,
	done: proc(g: ^Game) -> bool,
}

TUTORIAL := [?]Tutorial_Step {
	{"Plant a carrot: pick Carrot (4) and press Space on bare soil.", proc(g: ^Game) -> bool {return .Planted in g.events}},
	{"End the turn with T. Crops grow a step each turn.", proc(g: ^Game) -> bool {return .Turned in g.events}},
	{"End turns until the carrot is ripe, then Space on it to harvest.", proc(g: ^Game) -> bool {return .Harvested in g.events}},
	{"Barn tab (Tab): with Carrot picked, Z keeps one back as seed.", proc(g: ^Game) -> bool {return .Seeded in g.events}},
	{"Sell a crop: X sells one of the picked crop from the barn.", proc(g: ^Game) -> bool {return .Sold in g.events}},
	{"Buy land: Space on a bright-edged wild square next to yer soil.", proc(g: ^Game) -> bool {return .Bought in g.events}},
	{"Hire a farmhand (1, $25). Crops around a fed hand grow faster.", proc(g: ^Game) -> bool {return .Hired in g.events}},
	{"Put up a scarecrow (2, $20) to keep crows off the 5x5 around it.", proc(g: ^Game) -> bool {return .Placed in g.events}},
	{"License a new crop: pick it and press L (Radish is $10).", proc(g: ^Game) -> bool {return .Licensed in g.events}},
	{"Barn tab: set a seed target with . so seeds keep themselves.", proc(g: ^Game) -> bool {
			for crop in Crop {
				if g.seed_target[crop] > 0 {
					return true
				}
			}
			return false
		}},
}

// Ticks off the current goal if the last command did it.
tutorial_check :: proc(g: ^Game) {
	if g.tutorial < 1 || g.tutorial > len(TUTORIAL) || !TUTORIAL[g.tutorial - 1].done(g) {
		return
	}
	g.tutorial += 1
	g.events += {.Goal}
	if g.tutorial > len(TUTORIAL) {
		g.tutorial = 0
		say(g, "Tutorial done. The farm is yers. The Help tab has the manual.", COLOR_YELLOW)
	}
}
