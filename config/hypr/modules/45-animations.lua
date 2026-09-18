hl.curve("linear", { type = "bezier", points = { {0.0, 0.0}, {1.0, 1.0} } })
hl.curve("snap",   { type = "bezier", points = { {0.2, 0.9}, {0.3, 1.0} } })

hl.config({ animations = { enabled = true } })

hl.animation({ leaf = "windowsIn",   enabled = true, speed = 2, bezier = "snap", style = "popin 80%" })
hl.animation({ leaf = "windowsOut",  enabled = true, speed = 2, bezier = "snap", style = "popin 80%" })
hl.animation({ leaf = "windowsMove", enabled = true, speed = 2, bezier = "snap", style = "slide" })

hl.animation({ leaf = "fadeIn",     enabled = true, speed = 2, bezier = "snap" })
hl.animation({ leaf = "fadeOut",    enabled = true, speed = 2, bezier = "snap" })
hl.animation({ leaf = "fadeSwitch", enabled = true, speed = 1, bezier = "snap" })
hl.animation({ leaf = "fadeShadow", enabled = true, speed = 1, bezier = "snap" })
hl.animation({ leaf = "fadeDim",    enabled = true, speed = 1, bezier = "snap" })

hl.animation({ leaf = "border", enabled = true, speed = 2, bezier = "linear" })

hl.animation({ leaf = "workspaces",       enabled = true, speed = 2, bezier = "snap", style = "slidevert" })
hl.animation({ leaf = "specialWorkspace", enabled = true, speed = 2, bezier = "snap", style = "slidevert" })
