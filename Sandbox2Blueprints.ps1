#Настройки
$ClearOwner = $false         #Удалять теги Owner и BuiltBy?
$CreateMultiGrid = $true    #Создавать чертежи объединенных объектов?

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
$CubeGridFile = 0           #Используется как имя файла для извлеченных CubeGrid
$CountEntity = 0            #Используется для отображения процесса при проверке связей. Процесс иногда слишком долгий...

#Переменные для работы c Select-Xml
$SENamespace = @{xsi = "http://www.w3.org/2001/XMLSchema-instance"}
$XPathCubeGrid = '/MyObjectBuilder_Sector/SectorObjects/MyObjectBuilder_EntityBase[@xsi:type="MyObjectBuilder_CubeGrid"]'

#Создаем папки
New-Item "extracted" -ItemType Directory -ErrorAction SilentlyContinue | Out-Null

#Обрабатываем файл Sandbox.
Write-Host "Выгрызаем CubeGrid из Sandbox"
Write-Host

Select-Xml -Path SANDBOX_0_0_0_.sbs -XPath $XPathCubeGrid -Namespace $SENamespace | ForEach-Object {
    $CubeGridFile +=1
    $CubeGrid = (($_.Node.OuterXml).Split("`r`n").Split("`r").Split("`n"))
    Set-Content ("extracted\"+$CubeGridFile) $CubeGrid[1..($CubeGrid.Length-2)]
}

#Обрабатываем полученные объекты CubeGrid
Write-Host "Создаем чертежи"

$Extracted = Get-ChildItem "extracted"

foreach ($File in $Extracted){
#Забираем либо полностью весь файл, либо вычищаем теги Owner и BuiltBy
    if ($ClearOwner) {
        $CubeGridText = (Select-String $File.FullName -Pattern "<Owner>","<BuiltBy>" -NotMatch -Encoding UTF8NoBOM).Line
    }else{
        $CubeGridText = Get-Content $File.FullName -Encoding UTF8NoBOM
    }
#Ищем строки с тегом DisplayName и из последнего получаем название для чертежа
    [void]((Select-String $File.FullName -Pattern "DisplayName")[-1] -match "<DisplayName>(.*)</DisplayName>")
    $DisplayName = $matches[1] -replace '["?]','_'    #Заменяем символы, которые не подходят для имени файла
#Выводим название чертежа и, при наличии тега AutomaticBehaviour, предупреждаем
    $AutomaticBehaviour = (Select-String $File.FullName -Pattern "AutomaticBehaviour").Length
    if ($AutomaticBehaviour -eq 0) {
        Write-Host $DisplayName
    } else {
        Write-Host $DisplayName -NoNewline
        Write-Host " (присутствует AutomaticBehaviour)" -ForegroundColor Red
    }
#Создаем папку чертежа и сохраняем в нее чертеж, добавляя необходимые теги
    $Path = $DisplayName+"_"+$File.Name
    $BPFile = $Path+"\bp.sbc"
    New-Item $Path -ItemType Directory -ErrorAction SilentlyContinue | Out-Null
    Set-Content $BPFile $Header1,$Header2,$Header3,$Header4 -Encoding UTF8NoBOM
    Add-Content $BPFile $Header5$DisplayName$Header5_2 -Encoding UTF8NoBOM
    Add-Content $BPFile $Header6,$Header7 -Encoding UTF8NoBOM
    Add-Content $BPFile $CubeGridText -Encoding UTF8NoBOM
    Add-Content $BPFile $Footer1,$Footer2,$Footer3,$Footer4,$Footer5 -Encoding UTF8NoBOM
}
Write-Host

#Обработка связанных объектов
if ($CreateMultiGrid) {
#Создаем список для хранения связей объектов
    $Links = [System.Collections.Generic.List[pscustomobject]]::new()
#Собираем все строки, содержащие строки с ID для связываемых объектов, а также ID всех объектов
    $LinkedEntities = Select-String -Path "extracted\*" -Pattern "<ParentEntityId>","<TopBlockId>"
    $Entities = Select-String -Path "extracted\*" -Pattern "<EntityId>"
#Собираем связи между файлами, на основании которых они будут собираться в единый файл чертежа
    Write-Host "Начинается проверка", $LinkedEntities.Count, "связей"
    foreach ($LinkedEntity in $LinkedEntities) {
        $CountEntity += 1
        if (($CountEntity % 50) -eq 0) {
            Write-Host "Проверено", $CountEntity, "связей"
        }
        [void]($LinkedEntity -match "(<ParentEntityId>|<TopBlockId>)(.*)(<\/ParentEntityId>|<\/TopBlockId>)")
        if ($matches[2] -ne "0") {
            $Entity = $Entities | Select-String -Pattern $matches[2]
            if ($Entity.count -ne 0) {
                $Links.Add([pscustomobject]@{in=$LinkedEntity.Filename;out=$Entity.Filename})
            }
        }    
    }
    Write-Host "Проверка связей завершена"
    Write-Host

#Создаем мультиобъекты, пока список связей не опустеет
    Write-Host "Создание мультиобъектов"
    while ($Links.Count -ne 0){
#Начиная с первой доступной записи начинаем пополнять список связанных файлов, удаляя обработанные записи
        $CubeGridFileList = [string[]] $Links[0].in
        do {
            $TempFileList = $Links | Where-Object {$_.in -in $CubeGridFileList}
            foreach ($Temp in $TempFileList) {
                [void]($Links.Remove($Temp))
            }
            $CubeGridFileList += $TempFileList.out
            $LinksIn = $TempFileList.Count

            $TempFileList = $Links | Where-Object {$_.out -in $CubeGridFileList}
            foreach ($Temp in $TempFileList) {
                [void]($Links.Remove($Temp))
            }
            $CubeGridFileList += $TempFileList.in
            $LinksOut = $TempFileList.Count
        } until (($LinksIn -eq 0) -and ($LinksOut -eq 0))
#Очищаем полученный список от дублей
        $CubeGridFileList = $CubeGridFileList | Select-Object -Unique
#Вычисляем наиболее объемный (в блоках) объект и берем его имя для чертежа
        $CountCubeBlocks = 0
        $MaxCubeBlockFile = ""

        foreach ($CubeGridFile in $CubeGridFileList) {
            $CurrentCount = (Select-String -Path ("extracted\"+$CubeGridFile) -Pattern "<MyObjectBuilder_CubeBlock").Count
            if ($CountCubeBlocks -lt $CurrentCount) {
                $CountCubeBlocks = $CurrentCount
                $MaxCubeBlockFile = $CubeGridFile
            }
        }

        [void]((Select-String ("extracted\"+$MaxCubeBlockFile) -Pattern "DisplayName")[-1] -match "<DisplayName>(.*)</DisplayName>")
        $DisplayName = ($matches[1] -replace '["?]','_') + " Multi"         #Заменяем символы, которые не подходят для имени файла
        $DirName = $matches[1] -replace '["?]','_'                          #Заменяем символы, которые не подходят для имени файла

#Создаем папку чертежа и сохраняем в нее чертеж, добавляя необходимые теги заголовка
        $Path = $DirName+"_"+$MaxCubeBlockFile+" Multi"
        $BPFile = $Path+"\bp.sbc"
        New-Item $Path -ItemType Directory -ErrorAction SilentlyContinue | Out-Null
        Set-Content $BPFile $Header1,$Header2,$Header3,$Header4 -Encoding UTF8NoBOM
        Add-Content $BPFile $Header5$DisplayName$Header5_2 -Encoding UTF8NoBOM
        Add-Content $BPFile $Header6 -Encoding UTF8NoBOM
#Добавляем все гриды из полученного списка
        foreach ($CubeGridFile in $CubeGridFileList) {
#Добавляем тег CubeGrid
            Add-Content $BPFile $Header7 -Encoding UTF8NoBOM
#Забираем либо полностью весь файл, либо вычищаем теги Owner и BuiltBy
            if ($ClearOwner) {
                $Text = (Select-String ("extracted\"+$CubeGridFile) -Pattern "<Owner>","<BuiltBy>" -NotMatch -Encoding UTF8NoBOM).Line
            }else{
                $Text = Get-Content ("extracted\"+$CubeGridFile) -Encoding UTF8NoBOM
            }
#Сохраняем чертеж этого грида
            Add-Content $BPFile $Text -Encoding UTF8NoBOM
#Закрываем тег CubeGrid
            Add-Content $BPFile $Footer1 -Encoding UTF8NoBOM
        }
#Добавляем закрывающие теги для чертежа
        Add-Content $BPFile $Footer2,$Footer3,$Footer4,$Footer5 -Encoding UTF8NoBOM
#Выводим название чертежа и, при наличии тега AutomaticBehaviour, предупреждаем
        $AutomaticBehaviour = (Select-String $BPFile -Pattern "AutomaticBehaviour").Length
        if ($AutomaticBehaviour -eq 0) {
            Write-Host $DisplayName
        } else {
            Write-Host $DisplayName -NoNewline
            Write-Host " (присутствует AutomaticBehaviour)" -ForegroundColor Red
        }
    }
}
Write-Host

#Удаляем временные файлы
Remove-Item "extracted" -Recurse

Write-Host "Готово. Нажмите что-нибудь."

[void]$host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")