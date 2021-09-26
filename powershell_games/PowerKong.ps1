# Script: PowerKong.ps1
# Author: Kurt Jaegers
# GitHub: https://github.com/kjaegers/kjaegers_misc_projects
#
# Disclaimer:
# This is a very (VERY) rudimentary implementation of game inspired by the Donkey Kong arcade game. Donkey Kong is the property of Nintendo,
# and this code isn't meant as any type of challange to that ownership... This should be viewed as a "tribute" to Shigeru Miyamoto's game.
#
#
# Description:
# This was my attempt to explore methods for making an arcade-style game in PowerShell. A video of the "game" in action is 
# available here: https://youtu.be/GeOKpO9v_sw
# 
# Because I was hacking this together as an experiment, much of the code is uncommented and probably not well optimized, but it
# does what I wanted to do for the most part.
#
# The central idea here is that the areas of the playfield that get changed each frame are remembered and "patched" instead of
# attempting to redraw th whole screen. Barrels falling and ladder climing are based on looking up certain indexes in the level
# screen array to determine if a ladder is present. This is why climbable ladders are represented with [-+-] and non-climbable
# ladders are [x+x]. The barrels are looking for the + symbol to see if they can fall there (they can fall on both types) while
# the player is looking for the - symbol to see if they can climb in that spot.
#

$signature = @'
[DllImport("user32.dll", CharSet=CharSet.Auto, ExactSpelling=true)] 
public static extern short GetAsyncKeyState(int virtualKeyCode); 
'@

$API = Add-Type -MemberDefinition $signature -Name 'Keypress' -Namespace API -Passthru

$keyList = @()
$keyList += 32 #Space bar
$keyList += 37 #Left
$keyList += 38 #Right
$keyList += 39 #Up
$keyList += 40 #Down
$keylist += 88 #X
$script.state = "title"
$scritp.score = 0

$keyState = @{}
foreach ($x in $keyList) {
	$keyState[$x] = $false
}

$script:nextbarrel = 10

$script:barrels = @()

function get-userinput () {
	foreach ($key in $keyList) {
		$keyState[$key] = ($API::GetAsyncKeyState($key) -lt 0);
	}
}

function get_foot_character ($x,$y) {
	$l = $script:level[$y + 2];
	return $l.substring($x + 1,1);
}

function get_playfield_char ($x,$y) {
	$l = $script:level[$y];
	return $l.substring($x,1);
}

function get_ground_character ($x,$y) {
	$l = $script:level[$y + 3];
	return $l.substring($x + 1,1);
}

function show_status_message ($msg) {
	$cur.x = 50
	$cur.y = 55
	$rui.cursorposition = $cur
	Write-Host -ForegroundColor yellow -BackgroundColor black $msg
}

function patch_screen ($x,$y,$w,$h) {
	$r = $y
	while ($r -le ($y + $h)) {
		$color = "white"
		$o = $script:level[$r].substring($x,$w)
		if ($script:level[$r].substring(15,1) -eq "=") {
			$color = "red"
		}
		$cur.x = $x
		$cur.y = $r
		$rui.cursorposition = $cur
		Write-Host -ForegroundColor $color -BackgroundColor black -NoNewline $o
		$r += 1
	}
}

function patch_title_screen ($x,$y,$w,$h) {
	$r = $y
	while ($r -le ($y + $h)) {
		$color = "white"
		$o = $script:title[$r].substring($x,$w)
		$cur.x = $x
		$cur.y = $r
		$rui.cursorposition = $cur
		Write-Host -ForegroundColor $color -BackgroundColor black -NoNewline $o
		$r += 1
	}
}

function draw_player ($x,$y,$frame) {
	$cur.x = $x
	$cur.y = $y
	$sline = $frame * 3
	$rui.cursorposition = $cur
	Write-Host -ForegroundColor magenta -BackgroundColor black $player[$sline]
	$cur.y += 1
	$rui.cursorposition = $cur
	Write-Host -ForegroundColor magenta -BackgroundColor black $player[$sline + 1]
	$cur.y += 1
	$rui.cursorposition = $cur
	Write-Host -ForegroundColor magenta -BackgroundColor black $player[$sline + 2]
}

function is_key_pressed ($vkey) {
	return [bool]($getKeyState::GetAsyncKeyState($vkey) -eq -32767)
}


# Spawn a new barrel at the given coordinates. All barrels start going right
function create_barrel ($x,$y) {
	$b = " " | Select-Object x,y,f,s,d,c,a
	
	$b.x = $x         # x position
	$b.y = $y         # y position
	$b.d = 1          # direction (0=left, 1=right, 2=down and then left, 3=down and then right)
	$b.s = 1          # shape of the barrel (end-on=1, side-on=2)
	$b.f = 1          # barrel frame
	$b.c = 0          # barrel animation counter
	$b.a = $true      # Barrel active (true/false)
	
	$script:barrels += $b
}

# Update any active barrels
function update_barrels () {

    # Size for rectangles for collision detection.
	$r1w = 1
	$r1h = 1
	$r2w = 2
	$r2h = 3

	foreach ($b in $script:barrels) {
		if ($b.a) {
			patch_screen ($b.x) ($b.y) 5 3

			if ($b.c -ge 0) {
				$b.f = ($b.f + 1) % 2
				if ($b.d -eq 1) { $b.x += 1 }
				if ($b.d -eq 0) { $b.x -= 1 }

				# Maybe go down a ladder
				$ct = get_playfield_char $b.x ($b.y + 3)
				if ($ct -eq "+") {
					if ((Get-Random -max 100) -ge 85) {
						if ($b.d -eq 1) { $b.d = 2; $b.s = 2; $b.y += 1 }
						if ($b.d -eq 0) { $b.d = 3; $b.s = 2; $b.y += 1; }
					}
				}

				if ($b.x -le 1) { $b.d = 3; $b.s = 2; $b.x = 2; $b.y += 1; if ($b.y -ge 50) { $b.a = $false; patch_screen $b.x $b.y 5 3 } }
				if ($b.x -ge 70) { $b.d = 2; $b.s = 2; $b.x = 69; $b.y += 1 }

				if ($b.d -ge 2) {
					if ((($b.y - 12) % 8) -eq 0) {
						$b.d -= 2
						$b.s = 1
					} else {
						$b.y += 1
					}
				}
				$b.c = 0
			} else {
				$b.c += 1
			}

			$cur.x = $b.x
			$cur.y = $b.y
			$rui.cursorposition = $cur
			if ($b.s -eq 1) {
				$r1w=1
				if ($b.f -eq 1) {
					Write-Host -ForegroundColor yellow -BackgroundColor black "()"
				} else {
					Write-Host -ForegroundColor yellow -BackgroundColor black "[]"
				}
				$cur.y += 1
				$rui.cursorposition = $cur
				if ($b.f -eq 1) {
					Write-Host -ForegroundColor yellow -BackgroundColor black "()"
				} else {
					Write-Host -ForegroundColor yellow -BackgroundColor black "[]"
				}
			}
			if ($b.s -eq 2) {
				$r1w=4
				if ($b.f -eq 1) {
					Write-Host -ForegroundColor yellow -BackgroundColor black "(---)"
				} else {
					Write-Host -ForegroundColor yellow -BackgroundColor black "(###)"
				}
				$cur.y += 1
				$rui.cursorposition = $cur
				if ($b.f -eq 1) {
					Write-Host -ForegroundColor yellow -BackgroundColor black "(---)"
				} else {
					Write-Host -ForegroundColor yellow -BackgroundColor black "[###]"
				}
			}

			$r1x = $b.x
			$r1y = $b.y

			$r2x = $script:px
			$r2y = $script:py

			$coll = $false;

			if (($r1x -lt ($r2x + $r2w)) -and (($r1x + $r1w) -gt ($r2x)) -and ($r1y -lt ($r2y + $r2h)) -and (($r1y + $r1h -gt $r2y))) { $coll = $true }

			if ($coll) {
				$script:state = "title"
			}
		}
	}
}


$script:level = @()
$script:level += "                                                                              "
$script:level += "                                                                              "
$script:level += "                                                                              "
$script:level += "                                                                              "
$script:level += " jgs  .""``"".                                                                   "
$script:level += "  .-./ _=_ \.-.                                                               "
$script:level += " {  (,(oYo),) }}                                                              "
$script:level += " {{ |   ""   |} }  ===============                                             "
$script:level += " { { \(---)/  }}  |-+-|     |-+-|                                             "
$script:level += " {{  }'-=-'{ } }  |-+-|     |-+-|                                             "
$script:level += " { { }._:_.{  }}  |-+-|     |-+-|                                             "
$script:level += " {{  } -:- { } }  |-+-|     |-+-|                                             "
$script:level += " {_{ }``===``{  _}  |-+-|     |-+-|                                             "
$script:level += "((((\)     (/)))) |-+-|     |-+-|                                             "
$script:level += " ======================================================================       "
$script:level += "                    [x+x]                                      |-+-|          "
$script:level += "                    [x+x]                                      |-+-|          "
$script:level += "                                                               |-+-|          "
$script:level += "                                                               |-+-|          "
$script:level += "                                                               |-+-|          "
$script:level += "                    [x+x]                                      |-+-|          "
$script:level += "                    [x+x]                                      |-+-|          "
$script:level += "  =====================================================================       "
$script:level += "    |-+-|      |-+-|                                                          "
$script:level += "    |-+-|      |-+-|                                                          "
$script:level += "    |-+-|      |-+-|                                                          "
$script:level += "    |-+-|      |-+-|                                                          "
$script:level += "    |-+-|      |-+-|                                                          "
$script:level += "    |-+-|      |-+-|                                                          "
$script:level += "    |-+-|      |-+-|                                                          "
$script:level += "  =====================================================================       "
$script:level += "                     [x+x]              |-+-|                  |-+-|          "
$script:level += "                                        |-+-|                  |-+-|          "
$script:level += "                                        |-+-|                  |-+-|          "
$script:level += "                                        |-+-|                  |-+-|          "
$script:level += "                                        |-+-|                  |-+-|          "
$script:level += "                     [x+x]              |-+-|                  |-+-|          "
$script:level += "                     [x+x]              |-+-|                  |-+-|          "
$script:level += "  =====================================================================       "
$script:level += "    |-+-|                     |-+-|                                           "
$script:level += "    |-+-|                     |-+-|                                           "
$script:level += "    |-+-|                     |-+-|                                           "
$script:level += "    |-+-|                     |-+-|                                           "
$script:level += "    |-+-|                     |-+-|                                           "
$script:level += "    |-+-|                     |-+-|                                           "
$script:level += "    |-+-|                     |-+-|                                           "
$script:level += "  =====================================================================       "
$script:level += "                     [x+x]                                     |-+-|          "
$script:level += "                                                               |-+-|          "
$script:level += "                                                               |-+-|          "
$script:level += "                                                               |-+-|          "
$script:level += "   [***]                                                       |-+-|          "
$script:level += "   [***]             [x+x]                                     |-+-|          "
$script:level += "   [***]             [x+x]                                     |-+-|          "
$script:level += "  =====================================================================       "
$script:level += "                                                                              "
$script:level += "                                                                              "
$script:level += "                                                                              "


$script:title = @()
$script:title +=  "                                                                              "
$script:title +=  "                                                                              "
$script:title +=  "                                                                              "
$script:title +=  "                                                                              "
$script:title +=  "                                .""``"".                                         "
$script:title +=  "                            .-./ _ _ \.-.                                     "
$script:title +=  "                           {  (,(oYo),) }}                                    "
$script:title +=  "                           {{ |   ""   |} }                                    "
$script:title +=  "                           { { \(---)/  }}                                    "
$script:title +=  "                           {{  }'- -'{ } }                                    "
$script:title +=  "                           { { }._:_.{  }}                                    "
$script:title +=  "                           {{  } -:- { } }                                    "
$script:title +=  "                     jgs   {_{ }``   ``{  _}                                    "
$script:title +=  "                          ((((\)     (/))))                                   "
$script:title +=  "                                                                              "
$script:title +=  " ============================================================================ "
$script:title +=  "                                                                              "
$script:title +=  "          XXXX                        X    X                                  "
$script:title +=  "          X   X                       X    X                                  "
$script:title +=  "          X   X                       X   X                                   "
$script:title +=  "          X   X                       X  X                                    "
$script:title +=  "          XXXX   XXX  X   X XXXX XXX  XXX     XXX  X   X  XXX                 "
$script:title +=  "          X     X   X X   X X    X  X X  X   X   X XX  X X                    "
$script:title +=  "          X     X   X X X X XXX  XXX  X   X  X   X X X X X XXX                "
$script:title +=  "          X     X   X X X X X    X X  X    X X   X X  XX X   X                "
$script:title +=  "          X      XXX   X X  XXXX X  X X    X  XXX  X   X  XXX                 "
$script:title +=  "                                                                              "
$script:title +=  "                            PowerKong v0.5                                    "
$script:title +=  "                                                                              "
$script:title +=  "                                                                              "
$script:title +=  "                                                                              "
$script:title +=  "                                                                              "
$script:title +=  "                                                                              "
$script:title +=  "                                                                              "
$script:title +=  "                                                                              "
$script:title +=  "                                                                              "
$script:title +=  "                                                                              "
$script:title +=  "                                                                              "
$script:title +=  "                                                                              "
$script:title +=  "                                                                              "
$script:title +=  "                                                                              "
$script:title +=  "                                                                              "
$script:title +=  "                                                                              "
$script:title +=  "                                                                              "
$script:title +=  "                                                                              "
$script:title +=  "           ASCII Gorilla by 'jgs' from https://www.asciiart.eu                "
$script:title +=  "                                                                              "
$script:title +=  "                                                                              "
$script:title +=  "                                                                              "
$script:title +=  "                                                                              "
$script:title +=  "                                                                              "
$script:title +=  "                                                                              "
$script:title +=  "                                                                              "
$script:title +=  "                         Press X to Start                                     "
$script:title +=  "                                                                              "
$script:title +=  "                                                                              "
$script:title +=  "                                                                              "
$script:title +=  "                                                                              "

$player = @()
$player += " o "
$player += "-|-"
$player += "/ \"

$player += " o "
$player += "``|'"
$player += "// "

$player += " o "
$player += "'|``"
$player += " \\"


$cur = New-Object System.Management.Automation.Host.Coordinates
$cur.x = 0
$cur.y = 0

$script:levelW = $script:level[0].length - 1
$script:levelH = $script:level.count - 1

$ui = (Get-Host).ui
$rui = $ui.rawui
$rui.BackgroundColor = "Black"
$rui.ForegroundColor = "Red"
Clear-Host

$script:go = $true
$script:px = 8
$script:py = ($script:level.length - 6)
$script:ox = $script:px
$script:oy = $script:py

#patch_screen 0 0 $script:levelW $script:levelH


$f = 0
$v = 0
$jumping = $true
$climbing = $false
$jdir = 0
$gframes = 0
$cframes = 0
$bscounter = 0
create_barrel 3 12
$ftime = 0
$script:state = "title"

while ($script:go) {
	if ($script:state -eq "title" -or $script:state -eq "title_shown") {
		if ($script:state -eq "title") {
			patch_title_screen 0 0 $script:levelW $script:levelH
			$script:state = "title_shown"
		}
		get-userinput
		if ($keyState[88]) {
			$script:state="game"
			
			$script:px = 8
			$script:py = ($script:level.length - 7)
			$script:ox = $script:px
			$script:oy = $script:py
			$gframes=0
			$cframes=0
			$jdir=0
			$jumping=$false
			$climbing=$false
			
			$script:barrels = @()
			
			patch_screen 0 0 $script:levelW $script:levelH
		}
	}
	
	if ($script:state -eq "game") {
		draw_player $script:px $script:py $f
		$start_time = Get-Date

		$rd = $false
		get-userinput
		$script:ox = $script:px
		$script:oy = $script:py

		if ($keyState[37] -and !$jumping -and !$climbing) { $script:px -= 1; $rd = $true }
		if ($keyState[39] -and !$jumping -and !$climbing) { $script:px += 1; $rd = $true }

		if ($keyState[32]) {
			if (!$jumping -and !$climbing) {
				$v = -2;
				$jumping = $true;
				$rd = $true;
				if ($ox -lt $script:px) {
					$jdir = 2
				} else {
					if ($ox -gt $script:px) {
						$jdir = 1
					} else {
						$jdir = 0
					}
				}
			}
		}

		if ($keyState[38]) {
			if ($cframes -ge 3) {
				if (!$jumping) {
					$c1 = get_playfield_char $script:px ($script:py + 1)
					$c2 = get_playfield_char ($script:px + 2) ($script:py + 1)
					if ($c1 -eq "-" -or $c2 -eq "-") { # -or $c1 -eq "|" -or $c2 -eq "|") {
						$script:py -= 1
						$climbing = $true
						$jumping = $false
						$jdir = 0
					}
					if ($c1 -eq "=" -or $c2 -eq "=") {
						$script:py -= 2
						$climbing = $false
					}
				}
				$cframes = 0;
			} else { $cframes += 1 }
		}

		if ($keyState[40]) {
			if ($cframes -ge 1) {
				if (!$jumping) {
					$c1 = get_playfield_char $script:px ($script:py + 5)
					$c2 = get_playfield_char ($script:px + 2) ($script:py + 5)
					if ($c1 -eq "-" -or $c2 -eq "-") {
						$script:py += 1
						$climbing = $true
						$jumping = $false
						$jdir = 0
					}
					if ($c1 -eq "=" -or $c2 -eq "=") {
						$script:py += 2
						$climbing = $false
					}
				}
				$cframes = 0
			} else { $cframes += 1 }
		}

		if ($script:px -lt 2) { $script:px = 2 }
		if ($script:px -gt ($script:level[0].length - 4)) { $script:px = $script:level[0].length - 4 }

		if ($jumping) {
			if ($gframes -ge 2) {
				$gframes = 0
				$script:py += $v
				$v += 1
				if ((get_ground_character $script:px $script:py) -like "=") {
					$v = 0
					$jumping = $false
				}
				if ((get_ground_character $script:px ($script:py - 1)) -like "=") {
					$v = 0
					$script:py -= 1
					$jumping = $false
				}

				if ($v -gt 2) { $v = 2 }
				if ($v -lt -2) { $v = -2 }
			} else {
				if ($jdir -eq 1) { $script:px -= 1 }
				if ($jdir -eq 2) { $script:px += 1 }
				$gframes += 1
			}
		}

		if ($rd) { $f = ($f + 1) % 3 }

		if ($script:py -lt 2) { $script:py = 2 }
		if ($script:py -gt $script:level.length - 3) { $script:py = ($script:level.length - 3) }

		$bscounter += 1
		if ($bscounter -ge $script:nextbarrel) {
			create_barrel 17 12
			$bscounter = 0;
			$script:nextbarrel = ((get-random -max 125) + 25)
		}

		update_barrels

		$end_time = Get-Date
		$elapsed = ($end_time - $start_time).milliseconds

		sleep -Milliseconds ([math]::max(0,(30 - $elapsed)))

		patch_screen $script:ox $script:oy 3 3
	}
	
	$cur.x = 50
	$cur.y = 50
	$rui.cursorposition = $cur
}

