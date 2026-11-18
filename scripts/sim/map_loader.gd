class_name MapLoader
extends RefCounted
## Construit une GameGrid à partir d'un plan en texte (voir maps/map_01.gd).

const SYMBOLS := {
	".": GameGrid.Cell.EMPTY,
	"#": GameGrid.Cell.ROCK,
	"B": GameGrid.Cell.BASE,
	"M": GameGrid.Cell.METAL,
	"E": GameGrid.Cell.ESSENCE,
	"S": GameGrid.Cell.SPAWN,
}


static func from_layout(layout: String) -> GameGrid:
	var lines: Array[String] = []
	for raw in layout.split("\n"):
		var line := raw.strip_edges()
		if line != "":
			lines.append(line)
	if lines.is_empty():
		push_error("MapLoader : plan vide")
		return GameGrid.new(1, 1)

	var w := lines[0].length()
	var grid := GameGrid.new(w, lines.size())
	for y in lines.size():
		var line := lines[y]
		if line.length() != w:
			push_error("MapLoader : la ligne %d fait %d cases au lieu de %d" % [y, line.length(), w])
		for x in mini(line.length(), w):
			var ch := line[x]
			if not SYMBOLS.has(ch):
				push_error("MapLoader : symbole inconnu '%s' en (%d, %d)" % [ch, x, y])
				continue
			grid.set_cell(Vector2i(x, y), SYMBOLS[ch])
	return grid
