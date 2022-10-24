$ftpdest = "/media/EXTERNAL/ps2/"
$dvddrive = "E:"
$workdir = "R:\Work"
$username = "root"
$password = ConvertTo-SecureString "linux" -AsPlainText -Force
$cred = new-object System.Management.Automation.PSCredential($username, $password)
$SFTPSession = New-SFTPSession -ComputerName batocera -Credential $cred -AcceptKey

cd $workdir

$gamename = read-host "Game Name?"
write-host "Ripping $dvddrive to $workdir\$gamename.iso..."
c:\wbin\dd if=\\.\$dvddrive of="$workdir\$gamename.iso" bs=1M 2>$null

$Eject = New-Object -ComObject "Shell.Application"
$Eject.Namespace(17).Items() | Where-Object { $_.Type -eq "CD Drive" } | foreach { $_.InvokeVerb("Eject") }

write-host "Converting $workdir\$gamename.iso to $workdir\$gamename.chd..."
c:\wbin\chdman createcd -i "$workdir\$gamename.iso" -o "$workdir\$gamename.chd" 2>$null

write-host "Uploading $workdir\$gamename.chd to batocera..."

Set-SFTPItem -SessionId $SFTPSession.SessionID -Path "$workdir\$gamename.chd" -destination $ftpdest

del "$workdir\$gamename.iso"
del "$workdir\$gamename.chd"

Remove-SSHSession -SessionId $SFTPSession.SessionID
