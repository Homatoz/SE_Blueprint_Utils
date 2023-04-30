$XPathToMin = "/Definitions/ShipBlueprints/ShipBlueprint/CubeGrids/CubeGrid/CubeBlocks/MyObjectBuilder_CubeBlock/Min"
$XPathToSetMin = "/Definitions/ShipBlueprints/ShipBlueprint/CubeGrids/CubeGrid/CubeBlocks/MyObjectBuilder_CubeBlock"

$MinX = $null; $MaxX = $null; $MinY = $null; $MaxY = $null; $MinZ = $null; $MaxZ = $null

[xml]$XML = Get-Content .\bp.sbc

#Исправляем отсутствие Min 0,0,0
Select-Xml $XML -XPath $XPathToSetMin | ForEach-Object {
    if ($_.Node.min -eq $null) {
        $NullMin = $XML.CreateElement("Min")
        $NullMinAdd = $_.Node.AppendChild($NullMin)
        $NullMinAdd.SetAttribute("x","0")
        $NullMinAdd.SetAttribute("y","0")
        $NullMinAdd.SetAttribute("z","0")
    }
}
#Получаем минимальное и максимальное значение по координатам
Select-Xml $XML -XPath $XPathToMin | ForEach-Object {
    $Coord = $_.Node
    if ($MinX -eq $null) { $MinX = $Coord.x; $MaxX = $Coord.x; $MinY = $Coord.y; $MaxY = $Coord.y; $MinZ = $Coord.z; $MaxZ = $Coord.z }
    if ([int]$MaxX -lt [int]$Coord.x) { $MaxX = [int]$Coord.x }
    if ([int]$MinX -gt [int]$Coord.x) { $MinX = [int]$Coord.x }
    if ([int]$MaxY -lt [int]$Coord.y) { $MaxY = [int]$Coord.y }
    if ([int]$MinY -gt [int]$Coord.y) { $MinY = [int]$Coord.y }
    if ([int]$MaxZ -lt [int]$Coord.z) { $MaxZ = [int]$Coord.z }
    if ([int]$MinZ -gt [int]$Coord.z) { $MinZ = [int]$Coord.z }
}

Set-Content GridIntegrity "Проверка целостности объектов"
for ($i = $MinX; $i -le $MaxX; $i += 1) {
    Add-Content GridIntegrity ("")
    Add-Content GridIntegrity ("Уровень "+$i)
    Add-Content GridIntegrity ("")
    $BadIntegrity = [string[]]""
    for ($j = $MinY; $j -le $MaxY; $j += 1) {
        $Row = ""
        for ($k = $MinZ; $k -le $MaxZ; $k += 1) {
            $Node = Select-Xml $XML -XPath ($XPathToMin+"[@x='"+$i+"'][@y='"+$j+"'][@z='"+$k+"']")
            if ($Node.Count -eq 0) {
                $Row += "."
            } else {
                if ($null -eq $Node.Node.ParentNode.IntegrityPercent) {
                    $Row += "O"
                } else {
                    $Row += "X"
                    $BadIntegrity += ([string]$j+" "+$k+" "+$Node.Node.ParentNode.SubtypeName+" "+$Node.Node.ParentNode.CustomName)
                }
            }
        }
        Add-Content GridIntegrity $Row
    }
    Add-Content GridIntegrity $BadIntegrity
}
