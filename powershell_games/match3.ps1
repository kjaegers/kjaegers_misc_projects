#requires -version 2

#
# Powershell Match 3 Game
# Author : Kurt Jaegers
#
# A "simple" match 3 game in Powershell... Why? BECAUSE! :)
#

function Initialize-RawUI($fgColor, $bgColor)
{
	# Generate script-level variables to store the RawUI components, along with
	# a "System.Management.Automation.Host.Coordinates" object we can use to
	# store cursor positions
    $script:ui=(get-host).ui
    $script:rui=$script:ui.rawui
    $script:rui.BackgroundColor=$bgColor
    $script:rui.ForegroundColor=$fgColor
	$script:cursor = new-object System.Management.Automation.Host.Coordinates
    cls
}

function Write-Direct($x, $y, $text, $fgColor, $bgColor)
{
    # Write text to the display at a given X and Y with color information
	$script:cursor.x = $x
	$script:cursor.y = $y
	$script:rui.cursorposition = $script:cursor
	write-host -foregroundcolor $fgColor -backgroundcolor $bgColor -nonewline $text
}

function Initialize-Game
{
    # Draw out instructions and set up variables that control how the game board 
	# gets displayed on the screen.
	Write-Direct 9 1 "Powershell Match Three by Kurt Jaegers" "Yellow" "Black"
	Write-Direct 3 2 "http://www.twentysidedblog.com/powershell-match-3-game" "Yellow" "Black"
	Write-Direct 3 40 "W, A, S, D to Move Hilight" "Yellow" "Black"
	Write-Direct 3 41 "Arrow keys to swap in that direction" "Yellow" "Black"
    Write-Direct 3 42 "Q to Shuffle Board" "Yellow" "Black"
	Write-Direct 3 43 "Escape to Quit" "Yellow" "Black"
	$script:MinMatchLength = 3
	$script:BoardXOffset = 14
	$script:BoardYOffset = 5
	$script:PlayerScore = 0
}

function Draw-Gamepiece($x, $y, $pieceType, $phase)
{
	# Draw an individual piece given the location and
	# piece type. If the passed $phase is 2, it will be
	# drawn color on black, otherwise it will be drawn
	# with a color background with a black foreground
	
    $c1="black"
	
	switch ($pieceType)
	{
	  1 { $c2="cyan";  $s="+"; break; }
	  2 { $c2="red";  $s="@"; break; }
	  3 { $c2="green";  $s="$"; break; }
	  4 { $c2="magenta";  $s="#"; break; }
	  5 { $c2="white";  $s="%"; break; }
	  6 { $c2="blue";  $s="*"; break; }
	  7 { $c2="yellow";  $s="="; break; }
	  default { $c2="black"; $s=" "; break; }
	}

	# if the piece is empty, draw spaces to overwrite what might be there
    if ($pieceType -eq -1)	
	{
	  Write-Direct $x $y "   " $c1 $c2;
      Write-Direct $x ($y+1) "   " $c1 $c2;
	  Write-Direct $x ($y+2) "   " $c1 $c2;
	}
	else
	{
	  # If the piece is disappearing, draw it inverted (color on black background)
	  if ($phase -eq 2)
	  {
	    $cTemp=$c1
		$c1=$c2
		$c2=$cTemp
	  }
      Write-Direct $x $y "---" $c1 $c2;
      Write-Direct $x ($y+1) "|$s|" $c1 $c2;
	  Write-Direct $x ($y+2) "---" $c1 $c2;
	}
}

function Draw-Hilight($x, $y, $color)
{
    # Draw the hilight frame to indicate which piece the player
	# currently has selected. "Erasing" the hilight is just done
	# by drawing it again in black on black.
    Write-Direct $x $y "+---+" $color "black"
	Write-Direct $x ($y+1) "|" $color "black"
	Write-Direct $x ($y+2) "|" $color "black"
	Write-Direct $x ($y+3) "|" $color "black"
	Write-Direct ($x+4) ($y+1) "|" $color "black"
	Write-Direct ($x+4) ($y+2) "|" $color "black"
	Write-Direct ($x+4) ($y+3) "|" $color "black"
    Write-Direct $x ($y+4) "+---+" $color "black"
}

function Generate-Board
{
  # Randomly generate a gameboard full of pieces. The board
  # is just a one-dimensional array of integers between 1 and 7
  # that indicate the piece type/color.
  #
  # boardPhase is used to indicate that the piece is either 
  # normal (1) or fading (2).
  #
  # The oldBoard variable holds a copy of the current board so
  # we can compare it when drawing and only draw changes rather
  # than constantly flashing the cursor around to draw everything
  # every frame.
  $script:board = @()
  $script:boardPhase = @()
  for ($x=0; $x -lt 6; $x++)
  {
    for ($y=0; $y -lt 6; $y++)
	{
	  $script:board += get-random -minimum 1 -maximum 8
	  $script:boardPhase  += 1
	  $script:oldBoard += -1
	}  
  }
}

function Draw-Board
{
  # Draw the current game board. A piece will only be drawn if it
  # is different from the previous time the board was drawn. After
  # drawing, the board is copied to oldBoard.
  for ($x=0; $x -lt $script:board.count; $x++)
  {
    if ($script:oldBoard[$x] -ne $script:board[$x])
	{
      Draw-Gamepiece (((Get-PieceX $x) * 5) + ($script:BoardXOffset)) (((Get-PieceY $x) * 5)+ ($script:BoardYOffset)) $script:board[$x] $script:boardPhase[$x]
	}
  }
  
  $script:oldBoard = $script:board | foreach { $_ }
}

function Get-Neighbours($piece)
{
  # Get the neighbours associated with a piece.
  $nlist = @()

  # Left Neighbour
  if ((Get-PieceX $piece)  -gt 0)
  {
    $nlist += ($piece - 1)
  }
  
  # right Neighbour
  if ((Get-PieceX $piece) -lt 5)
  {
    $nlist += ($piece + 1)
  }
  
  # Top neighbour
  if ((Get-PieceY $piece) -gt 1)
  {
    $nlist += ($piece - 6)
  }
  
  # Bottom Neighbour
  if ((Get-PieceY $piece) -lt 5)
  {
    $nlist += ($piece + 6)
  }
  
  return $nlist
}

function Get-AreNeighbours($piece1, $piece2)
{
  # Returns true if two pieces are neighbours with each other
  if (Get-Neighbours($piece1) -contains $piece2)
  {
    return $true
  }
  else
  {
    return $false
  }
}

function CheckFor-Matches($piece)
{
  # Check for matches related to a piece. When two pieces are swapped, one of the two
  # must be involved in a valid match. If it isn't, the swap won't happen.
  $script:MatchList = @()
  Build-MatchList $script:board[$piece] $piece (Get-PieceX $piece) (Get-PieceY $piece)
  Validate-MatchList $piece $script:MatchList
}

function Build-MatchList($pieceType, $piece, $x, $y)
{
  # Recursively called to add neighbouring pieces that match the piece type
  # to the match list. They aren't necessarially co-linear, which is why we
  # need to use the Validate-MatchList function on the list after building it.
  if ($script:board[$piece] -ne $pieceType)
  {
    return
  }
  
  if ($Script:MatchList -contains $piece)
  {
    return
  }
  
  $script:MatchList += $piece 
  
  if (($x -eq (Get-PieceX $piece)) -or ($y -eq (Get-PieceY $piece)))
  {
    foreach ($n in Get-Neighbours $piece)
	{
	  Build-MatchList $pieceType $n $x $y
	}
  }
}

function Validate-MatchList($piece, $MatchList)
{
  # Work through the passed list and split it into
  # columns and rows of matching pieces. If the row or
  # column is longer than the minimum length necessary
  # to score (generally, since this is "Match 3" (!)) 
  # the match scores and we toggle the pieces to phase 2,
  # indicating that they should fade and disappear.
  # We also score 2 points for every piece we toggle.
  $cols = @()
  $rows = @()
  
  for ($i=0; $i -lt $MatchList.Count; $i++)
  {
    if ((Get-PieceX $MatchList[$i]) -eq (Get-PieceX $piece))
	{
	  $cols += $MatchList[$i]
	}
	if ((Get-PieceY $MatchList[$i]) -eq (Get-PieceY $piece))
	{
	  $rows += $MatchList[$i]
	}
  }
  
  if ($rows.Count -ge $script:MinMatchLength)
  {
    $script:IsMatched = $true
	foreach ($p in $rows)
	{
	  if ($script:boardPhase[$p] -ne 2)
	  {
	    $script:PlayerScore += 2;
	  }
	  $script:boardPhase[$p] = 2
	  $script:oldBoard[$p] = -1
	}
  }
  
  if ($cols.Count -ge $script:MinMatchLength)
  {
    $script:IsMatched = $true
	foreach ($p in $cols)
	{
	  if ($script:boardPhase[$p] -ne 2)
	  {
	    $script:PlayerScore += 2;
	  }
	  $script:boardPhase[$p] = 2
	  $script:oldBoard[$p] = -1
    }
  }  
}

function Get-PieceX($piece)
{
  # Get the X location of a piece, based on the board's width
  $piece % 6
}

function Get-PieceY($piece)
{
  # get the Y location of a piece, besed on the board's width
  [Math]::Floor($piece / 6)
}

function Try-Swap($piece1, $piece2)
{
  # Attempt to swap two pieces. They must be neighbours, and
  # the result of the swap must result in a match involving 
  # at least one of the pieces, or it will not take place.
  $script:IsMatched = $false
  if (Get-AreNeighbours $piece1 $piece2)
  {
    $script:MatchList = @()
	$l1 = @()
	$l2 = @()
	Build-MatchList $script:board[$piece1] $piece1 (Get-PieceX $piece1) (Get-PieceY $piece1) 
	$l1 = $script:MatchList | foreach { $_ }
	$script:MatchList = @()
	Build-MatchList $script:board[$piece2] $piece2 (Get-PieceX $piece2) (Get-PieceY $piece2)
	$l2 = $script:MatchList | foreach { $_ }
	
	Validate-MatchList $piece1 $l1
	Validate-MatchList $piece2 $l2
  }

  return $script:IsMatched  
}

function Swap-Pieces($piece1, $piece2)
{
  # Swap two pieces. We save the old positions in case
  # we need to swap back because the move is invalid
  # (doesn't make a match).
  $old_piece1 = $script:board[$piece1]
  $old_piece2 = $script:board[$piece2]
  $script:board[$piece1] = $old_piece2
  $script:board[$piece2] = $old_piece1
  
  if (Try-Swap $piece1 $piece2)
  {
    # If we made a match, we need to stop player input
	# while the board is animated and the pieces fade
	# and new ones fall into place.
    $script:animating = $true
  } 
  else 
  {
    $script:board[$piece1] = $old_piece1;
	$script:board[$piece2] = $old_piece2;
  }
}

function CheckFor-ExistingMatches()
{
    # Check the board for matches that already exist
	# without the need to swap pieces. This can happen
	# either with a new board or as the result of a move
	# when new pieces appear and others fall into place.
    for ($i=0; $i -lt $script:board.count; $i++)
    {
      CheckFor-Matches $i
	  if ($script:isMatched)
	  {
  	    $script:animating = $true
	  }
    }	
}


####################################
#
# Main script execution starts here
#
####################################

$done=$false

if ($host.name -ne "ConsoleHost") 
{
  write-host "This script should only be run in a ConsoleHost window (outside of the ISE)"
  exit
  $done=$true
} 

Initialize-RawUI "White" "Black" 
Initialize-Game
Generate-Board
$hdir = -1
$hilight = 0
$hilightwas = 2
$sdir = -1
$script:animating = $false


while (!$done)
{
  if (!$script:animating) 
  {
      $script:animCount = 0
	  if ($rui.KeyAvailable)
	  {
		$key = $rui.ReadKey("NoEcho,IncludeKeyDown,IncludeKeyUp")
		# There will be "junk" left over in the buffer, resulting in
		# KeyAvailable returning true and us getting hung up waiting
		# for a key to be read and preventing animation and board
		# checking, so after each key we do read, we clear the keyboard
		# buffer by reading everything that is left and throwing it away.
	    while ($script:rui.KeyAvailable)
	    {
	      $q = $script:rui.ReadKey("NoEcho,IncludeKeyDown,IncludeKeyUp")
	    }
		if ($key.keydown)
		{
		  switch ($key.virtualkeycode)
		  {
		    27 { $done = $true; break; } # Escape
			37 { $sdir = 0; break; } # Left Arrow
			38 { $sdir = 1; break; } # Up Arrow
			39 { $sdir = 2; break; } # Right Arrow
			40 { $sdir = 3; break; } # Down Arrow
			65 { $hdir = 0; break; } # A (Left)
			87 { $hdir = 1; break; } # W (Up)
			68 { $hdir = 2; break; } # D (Right)
			83 { $hdir = 3; break; } # S (Down)
			81 { Generate-Board; break; } # Q - Regenrate Board
			default { }
		  }
		}
	  }
	  
	  # hdir controls which direction the hilight should move
	  if ($hdir -eq 0)
	  {
		if (($hilight % 6) -gt 0)
		  {
			$hilight--
		  }
	  }
	  
	  if ($hdir -eq 1)
	  {
		if ($hilight -gt 5)
		{
		  $hilight -= 6
		}
	  }
	  
	  if ($hdir -eq 2)
	  {
		if (($hilight % 6) -lt 5)
		{
		  $hilight++
		}
	  }
	  
	  if ($hdir -eq 3)
	  {
		if ($hilight -lt  30)
		{
		  $hilight += 6
		}
	  }
	  
	  # sdir determines which direction we are attempting
	  # to swap pieces in.
	  if ($sdir -eq 0)
	  { 
	    if (($hilight % 6) -gt 0)
		{
		  Swap-Pieces $hilight ($hilight-1)
		}
	  }
	  
	  if ($sdir -eq 1)
	  {
	    if ($hilight -gt 5)
		{
		  Swap-Pieces $hilight ($hilight - 6)
		}
	  }
	  
	  if ($sdir -eq 2)
	  {
		if (($hilight % 6) -lt 5)
		{
		  Swap-Pieces $hilight ($hilight + 1)
		}
	  }
	  
	  if ($sdir -eq 3)
	  {
		if ($hilight -lt 30)
		{
		  Swap-Pieces $hilight ($hilight + 6)
		}
	  }

	  $sdir=-1
	  $hdir=-1	  
	  
	  Draw-Board
	  
	  # If the hilight moved, erase the old one (draw it in black)
	  # and draw a new one in red
	  if ($hilight -ne $hilightwas) {
		Draw-Hilight ((($hilightwas % 6) * 5) + ($script:BoardXOffset-1)) (([Math]::Floor($hilightwas / 6) * 5)+ ($script:BoardYOffset-1)) "black"
		Draw-Hilight ((($hilight % 6) * 5) + ($script:BoardXOffset-1)) (([Math]::Floor($hilight / 6) * 5)+ ($script:BoardYOffset-1)) "red"
		$hilightwas=$hilight
	  }	 
  }
  else
  {
    # We are animating, so we have an animation frame count
	# that we use to make the action visible over a few frames
	$script:animCount++
	
	# Three frames after we start animating, erase all of the
	# pieces that were marked as fading and set their piece type
	# to -1 (empty)
	if ($script:animCount -eq 3)
	{
	  for ($i=0; $i -lt $script:board.count; $i++)
	  {
	    if ($script:boardPhase[$i] -eq 2)
		{
		  $script:board[$i] = -1
		  $script:boardPhase[$i] = 1
		}
	  }
	}
	
	# Starting at 6 frames after we began animating, run through
	# the array and drop all of the pieces that have empty spaces
	# below them by one slot. We do this 6 times, so we will always
	# know that pieces have moved as low as they can when we reach
	# animCount 12
	if ($script:animCount -ge 6)
	{
	  for ($i=35; $i -gt 5; $i--)
	  {
	    if ($script:board[$i] -eq -1)
		{
		  $script:board[$i] = $script:board[$i-6]
		  $script:board[$i-6] = -1
		}
	  }
	}
	
	# We have moved all of the falling pieces down now, so it is 
	# time to generate new pieces anywhere there are still empty (-1)
	# pieces on the board. We also toggle off IsMatched and Animating
	# so we can accept input again.
	if ($script:animCount -eq 12)
	{
	  for ($i=0; $i -lt $script:board.count; $i++)
	  {
	    if ($script:board[$i] -eq -1)
		{
		  $script:board[$i] = get-random -minimum 1 -maximum 8
		}
      }	  
	  $script:IsMatched=$false
	  $script:animating=$false	  
	  $script:animcount=0
	}
	Draw-Board
  }
  
  start-sleep -mil 100

  Write-Direct 14 38 "Score: $script:PlayerScore           " "Green" "Black"
  
  # If we aren't currently dealing with a match, check the board for
  # "passive" matches.
  if (!$script:IsMatched)
  {
    CheckFor-ExistingMatches
  }
}

cls
