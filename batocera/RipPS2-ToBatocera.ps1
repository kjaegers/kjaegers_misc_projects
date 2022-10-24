# A simple script to rip a PS2 Game Disc, convert it to CHD, and upload it to my Batocera box.
#
# Requires - posh-ssh module, dd for windows, and chdman. My dd and chdman are located in c:\wbin
#
# Notes: I have an extensive collection of physical PS2 games, and recently put together a Batocera Linux
# box for emulation purposes. I wrote the script below to auomate the process of ripping the PS2 disc to
# my computer and converting the ISO into a CHD file, followed by uploading the result over SFTP to the
# batocea box.
#
# This script is not meant to support piracy... I have 350+ physical PS2 games, but it is much more
# convenient to play them via Batocera than hook up one of my PS2s to TVs that really no longer support
# the video connections involved.
#
# I use a ram drive for the work folder, so nothing ever gets written to physical disks/ssds to avoid
# wear on writing temp files.
#
# On the batocera side, I use linux bind mappings to allow me to make folders from an external drive into
# the /userdata/roms folder so my larger games are stored externally to the root batocera drive.

# directory on the batocera system to upload the file to
$ftpdest = "/media/EXTERNAL/ps2/"

# What is the drive letter of the DVD drive?
$dvddrive = "E:"

# Where to store the temp/working files.
$workdir = "R:\Work"

# SFTP username and password. **Update the password to match your system** the default PW (linux) is below
# for simplicity's sake.
$username = "root"
$password = ConvertTo-SecureString "linux" -AsPlainText -Force
$cred = new-object System.Management.Automation.PSCredential($username, $password)

# Create the SFTP session for us to use
$SFTPSession = New-SFTPSession -ComputerName batocera -Credential $cred -AcceptKey

# Prompt for the name of the name. I could probably build a lookup to a web service for this, but this is
# simple.
$gamename = read-host "Game Name?"

# Use dd to rip the contents of the drive to an ISO file
write-host "Ripping $dvddrive to $workdir\$gamename.iso..."
c:\wbin\dd if=\\.\$dvddrive of="$workdir\$gamename.iso" bs=1M 2>$null

# Eject the DVD drive so a new game can be loaded while we convert/upload if desired
$Eject = New-Object -ComObject "Shell.Application"
$Eject.Namespace(17).Items() | Where-Object { $_.Type -eq "CD Drive" } | foreach { $_.InvokeVerb("Eject") }

# Convert the ISO file to a CHD file. CHD stands for Compressed Hunks of Data and is a common emulator rom
# format popularized by MAME.
write-host "Converting $workdir\$gamename.iso to $workdir\$gamename.chd..."
c:\wbin\chdman createcd -i "$workdir\$gamename.iso" -o "$workdir\$gamename.chd" 2>$null

# SFTP the file to the batocera box
write-host "Uploading $workdir\$gamename.chd to batocera..."
Set-SFTPItem -SessionId $SFTPSession.SessionID -Path "$workdir\$gamename.chd" -destination $ftpdest

# Delete the work files
del "$workdir\$gamename.iso"
del "$workdir\$gamename.chd"

# Close the SSH session
Remove-SSHSession -SessionId $SFTPSession.SessionID
