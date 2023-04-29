#Настройки
$ClearOwner = $true              #Удалять теги Owner и BuiltBy?

#Текст обертки для чертежей
$header1 = "<?xml version=""1.0""?>"
$header2 = "<Definitions xmlns:xsd=""http://www.w3.org/2001/XMLSchema"" xmlns:xsi=""http://www.w3.org/2001/XMLSchema-instance"">"
$header3 = "<ShipBlueprints>"
$header4 = "<ShipBlueprint xsi:type=""MyObjectBuilder_ShipBlueprintDefinition"">"
$header5 = "<Id Type=""MyObjectBuilder_ShipBlueprintDefinition"" Subtype="""
$header5_2 = """ />"
$header6 = "<CubeGrids>"
$header7 = "<CubeGrid>"
$footer1 = "</CubeGrid>"
$footer2 = "</CubeGrids>"
$footer3 = "</ShipBlueprint>"
$footer4 = "</ShipBlueprints>"
$footer5 = "</Definitions>"

#разные переменные
$child = 0
$write = 0
$file = 0
$index = -1
$startindex = 0
$path = ""
$extracted = ""

Write-Host "Читаем файл Sandbox"

$sandbox = Get-Content SANDBOX_0_0_0_.sbs -Encoding UTF8NoBOM

#Создаем папки
New-Item "extracted" -ItemType Directory -ErrorAction SilentlyContinue | Out-Null
#New-Item "bp" -ItemType Directory -ErrorAction SilentlyContinue | Out-Null

Write-Host "Выгрызаем из Sandbox CubeGrid"

#Обрабатываем файл Sandbox.
foreach($strsandbox in $sandbox){
#Считаем строки.
    $index +=1
#Ищем объекты EntityBase. При нахождении - увеличиваем количество дочерних объектов из-за того, что объекты могут быть вложенными.
    if ($strsandbox.Contains("<MyObjectBuilder_EntityBase")) {
        $child += 1
    }
#Если объект - CubeGrid, и это первый уровень вложенности, то сохраняем номер строки, увеличиваем номер файла и включаем флаг записи.
    if (($strsandbox.Contains("MyObjectBuilder_CubeGrid")) -and ($child -eq 1) -and ($write -eq 0)) {
        $write = 1
        $file += 1
        $startindex = $index
    }
#Если найден конец объекта CubeGrid, то сохраняем объект в отдельный файл без тэгов самого объекта.
    if (($strsandbox.Contains("</MyObjectBuilder_EntityBase")) -and ($child -eq 1) -and ($write -eq 1)) {
        $write = 0
        $path = "extracted\"+$file
        Set-Content $path $sandbox[($StartIndex+1)..($Index-1)] -Encoding UTF8NoBOM
    }
#Уменьшаем количество вложенности, если найден конец объекта.
    if ($strsandbox.Contains("</MyObjectBuilder_EntityBase")) {
        $child -= 1
    }

}

Write-Host "Создаем чертежи"

$extracted = Get-ChildItem "extracted\"

foreach ($file in $extracted){
#Забираем либо полностью весь файл, либо вычищаем теги Owner и BuiltBy
    if ($ClearOwner) {
        $text = (Select-String $file.FullName -Pattern "<Owner>","<BuiltBy>" -NotMatch -Encoding UTF8NoBOM).Line
    }else{
        $text = Get-Content $file.FullName -Encoding UTF8NoBOM
    }
#Ищем строки с тегом DisplayName и из последнего получаем название для чертежа
    $dn = (Select-String $file.FullName -Pattern "DisplayName")[-1] -match "<DisplayName>(.*)</DisplayName>"
    $name = $matches[1] -replace '["?]','_'    #Заменяем символы, которые не подходят для имени файла
#Выводим название чертежа и, при наличии тега AutomaticBehaviour, предупреждаем
    $ab = (Select-String $file.FullName -Pattern "AutomaticBehaviour").Length
    if ($ab -eq 0) {
        Write-Host $name
    } else {
        Write-Host $name -NoNewline
        Write-Host " (присутствует AutomaticBehaviour)" -ForegroundColor Red
    }
#Создаем папку чертежа и сохраняем в нее чертеж, добавляя необходимые теги
    $path = <#"bp\"+#>$name+"_"+$file.Name
    $bpfile = $path+"\bp.sbc"
    New-Item $path -ItemType Directory -ErrorAction SilentlyContinue | Out-Null
    Set-Content $bpfile $header1,$header2,$header3,$header4 -Encoding UTF8NoBOM
    Add-Content $bpfile $header5$name$header5_2 -Encoding UTF8NoBOM
    Add-Content $bpfile $header6,$header7 -Encoding UTF8NoBOM
    Add-Content $bpfile $text -Encoding UTF8NoBOM
    Add-Content $bpfile $footer1,$footer2,$footer3,$footer4,$footer5 -Encoding UTF8NoBOM
}

#Удаляем временные файлы
Remove-Item "extracted" -Recurse

Write-Host "Готово. Нажмите что-нибудь."

$x = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")