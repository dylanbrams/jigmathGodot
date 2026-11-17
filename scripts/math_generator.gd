class_name MathGenerator
extends RefCounted
## Port of the Unity MathMap/MathGroup logic.
## Fills a cols x rows grid with equation fragments, row by row. Each row is split
## into equation groups of 2..5 cells ("a + b = c" has 5 tokens; narrower groups
## merge neighbouring tokens, e.g. "3 +"). Number tokens are kept unique across the
## puzzle so every piece has exactly one possible home.

const MIN_GROUP := 2
const MAX_GROUP := 5
const EQUATION_TOKENS := 5
const MAX_ADD := 20
const MAX_FACTOR := 12
const UNIQUE_TRIES := 40
const OPERATORS := ["+", "-", "*", "/", "="]

static func generate(cols: int, rows: int, rng: RandomNumberGenerator) -> Array[String]:
	var tokens: Array[String] = []
	tokens.resize(cols * rows)
	var used := {}
	for row in rows:
		var col := 0
		for width in _split_row(cols, rng):
			var group := _make_group(width, rng, used)
			for i in width:
				tokens[row * cols + col + i] = group[i]
			col += width
	return tokens


static func _split_row(cols: int, rng: RandomNumberGenerator) -> Array[int]:
	var widths: Array[int] = []
	var remaining := cols
	while remaining > 0:
		if remaining <= MIN_GROUP:
			widths.append(remaining)
			break
		var w := rng.randi_range(MIN_GROUP, mini(MAX_GROUP, remaining))
		if remaining - w == 1: # never leave a lone 1-cell group behind
			w = w + 1 if w < MAX_GROUP else w - 1
		widths.append(w)
		remaining -= w
	return widths


static func _make_group(width: int, rng: RandomNumberGenerator, used: Dictionary) -> Array[String]:
	var best: Array[String] = []
	var best_clashes := 1 << 30
	for attempt in UNIQUE_TRIES:
		var row := _compress(_make_equation(rng), width, rng)
		var clashes := 0
		for token in row:
			if not OPERATORS.has(token) and used.has(token):
				clashes += 1
		if clashes < best_clashes:
			best = row
			best_clashes = clashes
		if clashes == 0:
			break
	for token in best:
		used[token] = true
	return best


static func _make_equation(rng: RandomNumberGenerator) -> Array[String]:
	var op: String = ["+", "-", "*", "/"][rng.randi_range(0, 3)]
	var a := 0
	var b := 0
	var c := 0
	match op:
		"+":
			a = rng.randi_range(1, MAX_ADD)
			b = rng.randi_range(1, MAX_ADD)
			c = a + b
		"-":
			a = rng.randi_range(2, MAX_ADD)
			b = rng.randi_range(1, a - 1)
			c = a - b
		"*":
			a = rng.randi_range(2, MAX_FACTOR)
			b = rng.randi_range(2, MAX_FACTOR)
			c = a * b
		"/":
			c = rng.randi_range(2, MAX_FACTOR)
			b = rng.randi_range(2, MAX_FACTOR)
			a = c * b
	var eq: Array[String] = [str(a), op, str(b), "=", str(c)]
	return eq


static func _compress(tokens: Array[String], width: int, rng: RandomNumberGenerator) -> Array[String]:
	var out := tokens.duplicate()
	while out.size() > width:
		var i := rng.randi_range(0, out.size() - 2)
		out[i] = out[i] + " " + out[i + 1]
		out.remove_at(i + 1)
	var result: Array[String] = []
	result.assign(out)
	return result
