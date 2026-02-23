package shell

import _ "embed"

//go:embed init.bash.tmpl
var BashInit string

//go:embed init.fish.tmpl
var FishInit string
