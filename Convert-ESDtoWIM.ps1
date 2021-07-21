# When you create a Windows .iso using the Media Creation Tool, you get an "install.esd" instead of an "install.wim" file
# This script converts the .esd to a .wim, that we can use with MDT
# Just change the paths below - assumes .iso is mounted as F:


dism /export-image /SourceImageFile:F:\Sources\install.esd /SourceIndex:6 /DestinationImageFile:E:\Path\To\outputFile.wim /Compress:max /CheckIntegrity
