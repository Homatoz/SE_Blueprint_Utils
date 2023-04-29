#Настройки
$ClearOwner = $true              #Удалять теги Owner и BuiltBy?

#Текст обертки для чертежей
$Header1 = "<?xml version=""1.0""?>"
$Header2 = "<Definitions xmlns:xsd=""http://www.w3.org/2001/XMLSchema"" xmlns:xsi=""http://www.w3.org/2001/XMLSchema-instance"">"
$Header3 = "<ShipBlueprints>"
$Header4 = "<ShipBlueprint xsi:type=""MyObjectBuilder_ShipBlueprintDefinition"">"
$Header5 = "<Id Type=""MyObjectBuilder_ShipBlueprintDefinition"" Subtype="""
$Header5_2 = """ />"
$Header6 = "<CubeGrids>"
$Header7 = "<CubeGrid>"
$Footer1 = "</CubeGrid>"
$Footer2 = "</CubeGrids>"
$Footer3 = "</ShipBlueprint>"
$Footer4 = "</ShipBlueprints>"
$Footer5 = "</Definitions>"

#Инициализируем переменные
$EntityBaseLevel = 0        #Указывает уровень вложенности EntityBase. Работаем только с первым уровнем.
$CubeGridExtracting = 0     #Флаг извлечения CubeGrid. Используется из-за наличия вложенных CubeGrid.
$CubeGridFile = 0           #Используется как имя файла для извлеченных CubeGrid
$Index = -1                 #Используется для подсчета строк в файле Sandbox
$StartIndex = 0             #Используется для отметки начала блока CubeGrid


#Получаем данные из Sandbox
Write-Host "Читаем файл Sandbox"

$Sandbox = Get-Content SANDBOX_0_0_0_.sbs -Encoding UTF8NoBOM

#Создаем папки
New-Item "extracted" -ItemType Directory -ErrorAction SilentlyContinue | Out-Null

#Обрабатываем файл Sandbox.
Write-Host "Выгрызаем из Sandbox CubeGrid"

foreach($SandboxLine in $Sandbox){
#Считаем строки.
    $Index +=1
#Ищем объекты EntityBase. При нахождении - увеличиваем количество дочерних объектов из-за того, что объекты могут быть вложенными.
    if ($SandboxLine.Contains("<MyObjectBuilder_EntityBase")) {
        $EntityBaseLevel += 1
    }
#Если объект - CubeGrid, это первый уровень вложенности и флаг извлечения не установлен, то сохраняем номер текущей строки, увеличиваем номер файла и включаем флаг извлечения.
    if (($SandboxLine.Contains("MyObjectBuilder_CubeGrid")) -and ($EntityBaseLevel -eq 1) -and ($CubeGridExtracting -eq 0)) {
        $CubeGridExtracting = 1
        $CubeGridFile += 1
        $StartIndex = $Index
    }
#Если найден конец обрабатываемого объекта CubeGrid, то сохраняем объект в отдельный файл без тэгов самого объекта.
    if (($SandboxLine.Contains("</MyObjectBuilder_EntityBase")) -and ($EntityBaseLevel -eq 1) -and ($CubeGridExtracting -eq 1)) {
        $CubeGridExtracting = 0
        $Path = "extracted\"+$CubeGridFile
        Set-Content $Path $Sandbox[($StartIndex+1)..($Index-1)] -Encoding UTF8NoBOM
    }
#Уменьшаем количество вложенности, если найден конец объекта.
    if ($SandboxLine.Contains("</MyObjectBuilder_EntityBase")) {
        $EntityBaseLevel -= 1
    }

}

#Обрабатываем полученные объекты CubeGrid
Write-Host "Создаем чертежи"

$Extracted = Get-ChildItem "extracted"

foreach ($File in $Extracted){
#Забираем либо полностью весь файл, либо вычищаем теги Owner и BuiltBy
    if ($ClearOwner) {
        $Text = (Select-String $File.FullName -Pattern "<Owner>","<BuiltBy>" -NotMatch -Encoding UTF8NoBOM).Line
    }else{
        $Text = Get-Content $File.FullName -Encoding UTF8NoBOM
    }
#Ищем строки с тегом DisplayName и из последнего получаем название для чертежа
    $DisplayName = (Select-String $File.FullName -Pattern "DisplayName")[-1] -match "<DisplayName>(.*)</DisplayName>"
    $Name = $matches[1] -replace '["?]','_'    #Заменяем символы, которые не подходят для имени файла
#Выводим название чертежа и, при наличии тега AutomaticBehaviour, предупреждаем
    $AutomaticBehaviour = (Select-String $File.FullName -Pattern "AutomaticBehaviour").Length
    if ($AutomaticBehaviour -eq 0) {
        Write-Host $Name
    } else {
        Write-Host $Name -NoNewline
        Write-Host " (присутствует AutomaticBehaviour)" -ForegroundColor Red
    }
#Создаем папку чертежа и сохраняем в нее чертеж, добавляя необходимые теги
    $Path = $Name+"_"+$File.Name
    $BPFile = $Path+"\bp.sbc"
    New-Item $Path -ItemType Directory -ErrorAction SilentlyContinue | Out-Null
    Set-Content $BPFile $Header1,$Header2,$Header3,$Header4 -Encoding UTF8NoBOM
    Add-Content $BPFile $Header5$Name$Header5_2 -Encoding UTF8NoBOM
    Add-Content $BPFile $Header6,$Header7 -Encoding UTF8NoBOM
    Add-Content $BPFile $Text -Encoding UTF8NoBOM
    Add-Content $BPFile $Footer1,$Footer2,$Footer3,$Footer4,$Footer5 -Encoding UTF8NoBOM
}

#Удаляем временные файлы
Remove-Item "extracted" -Recurse

Write-Host "Готово. Нажмите что-нибудь."

$x = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")