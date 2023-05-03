#Настройки
$ClearOwner = $false        #Удалять теги Owner и BuiltBy?
$CreateMultiGrid = $true    #Создавать чертежи объединенных объектов?
$RemoveDeformation = $true  #Удалять деформации объектов?

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

#Переменные для работы c Select-Xml
$SENamespace = @{xsi = "http://www.w3.org/2001/XMLSchema-instance"}
$XPathCubeGrid = '/MyObjectBuilder_Sector/SectorObjects/MyObjectBuilder_EntityBase[@xsi:type="MyObjectBuilder_CubeGrid"]'

#Объекты для выбора файлов и папок
Add-Type -AssemblyName System.Windows.Forms
$FileBrowser = New-Object System.Windows.Forms.OpenFileDialog -Property @{ Filter = "Файл мира|SANDBOX_0_0_0_.sbs" ; Title = "Выберите файл мира" }
$FolderBrowserRead = New-Object System.Windows.Forms.FolderBrowserDialog -Property @{ Description = "Выберите папку с файлами мира";
                                                                                      UseDescriptionForTitle = $True}
$FolderBrowserSave = New-Object System.Windows.Forms.FolderBrowserDialog -Property @{ InitialDirectory = $env:APPDATA+"\SpaceEngineers\Blueprints\local\";
                                                                                      Description = "Выберите папку для сохранения чертежей";
                                                                                      UseDescriptionForTitle = $True}

function ExtractGrid {
    param ([string]$PathToSandbox, [string]$BPPath)

    #Проверяем наличие файла SANDBOX_0_0_0_.sbs
    if (-not (Test-Path $PathToSandbox -PathType Leaf)) {
        Write-Host "Файл SANDBOX_0_0_0_.sbs отсутствует, обработка не может быть произведена."
        return
    }
    
    #Инициализируем переменные
    $CubeGridFile = 0           #Используется как имя файла для извлеченных CubeGrid
    $CountEntity = 0            #Используется для отображения процесса при проверке связей. Процесс иногда слишком долгий...
    $PathToExtracted = $BPPath+"\extracted\"
    
    #Создаем папки
    New-Item -Path $PathToExtracted -ItemType Directory -ErrorAction SilentlyContinue | Out-Null

    #Обрабатываем файл Sandbox.
    Write-Host "Выгрызаем CubeGrid из Sandbox"
    Write-Host

    Select-Xml -Path $PathToSandbox -XPath $XPathCubeGrid -Namespace $SENamespace | ForEach-Object {
        $CubeGridFile +=1
    #Если включено удаление деформаций и есть деформации, то удаляем
        if ($RemoveDeformation -and $_.Node.Skeleton) {
            $_.Node.RemoveChild($_.Node.Skeleton) | Out-Null
        }
        $CubeGrid = (($_.Node.OuterXml).Split("`r`n").Split("`r").Split("`n"))
        Set-Content -Path ($PathToExtracted+$CubeGridFile.ToString().PadLeft(4,"0")) -Value $CubeGrid[1..($CubeGrid.Length-2)]
    }

    #Обрабатываем полученные объекты CubeGrid
    Write-Host "Создаем чертежи"

    $ExtractedFiles = Get-ChildItem -Path $PathToExtracted

    foreach ($File in $ExtractedFiles){
    #Забираем либо полностью весь файл, либо вычищаем теги Owner и BuiltBy
        if ($ClearOwner) {
            $CubeGridText = (Select-String -Path $File.FullName -Pattern "<Owner>","<BuiltBy>" -NotMatch -Encoding UTF8NoBOM).Line
        }else{
            $CubeGridText = Get-Content -Path $File.FullName -Encoding UTF8NoBOM
        }
    #Ищем строки с тегом DisplayName и из последнего получаем название для чертежа
        (Select-String -Path $File.FullName -Pattern "DisplayName")[-1] -match "<DisplayName>(.*)</DisplayName>" | Out-Null
        $DisplayName = $matches[1] -replace '["?]','_'    #Заменяем символы, которые не подходят для имени файла
    #Выводим название чертежа и, при наличии тега AutomaticBehaviour, предупреждаем
        $AutomaticBehaviour = (Select-String -Path $File.FullName -Pattern "AutomaticBehaviour").Length
        if ($AutomaticBehaviour -eq 0) {
            Write-Host $DisplayName
        } else {
            Write-Host $DisplayName -NoNewline
            Write-Host " (присутствует AutomaticBehaviour)" -ForegroundColor Red
        }
    #Создаем папку чертежа и сохраняем в нее чертеж, добавляя необходимые теги
        $Path = $BPPath+"\"+$File.Name+"_"+$DisplayName
        $BPFile = $Path+"\bp.sbc"
        New-Item -Path $Path -ItemType Directory -ErrorAction SilentlyContinue | Out-Null
        Set-Content -Path $BPFile -Value $Header1,$Header2,$Header3,$Header4 -Encoding UTF8NoBOM
        Add-Content -Path $BPFile -Value $Header5$DisplayName$Header5_2 -Encoding UTF8NoBOM
        Add-Content -Path $BPFile -Value $Header6,$Header7 -Encoding UTF8NoBOM
        Add-Content -Path $BPFile -Value $CubeGridText -Encoding UTF8NoBOM
        Add-Content -Path $BPFile -Value $Footer1,$Footer2,$Footer3,$Footer4,$Footer5 -Encoding UTF8NoBOM
    }
    Write-Host

    #Обработка связанных объектов
    if ($CreateMultiGrid) {
    #Создаем список для хранения связей объектов
        $Links = [System.Collections.Generic.List[pscustomobject]]::new()
    #Собираем все строки, содержащие строки с ID для связываемых объектов, а также ID всех объектов
        $LinkedEntities = Select-String -Path ($PathToExtracted+"*") -Pattern "<ParentEntityId>","<TopBlockId>"
        $Entities = Select-String -Path ($PathToExtracted+"*") -Pattern "<EntityId>"
    #Собираем связи между файлами, на основании которых они будут собираться в единый файл чертежа
        Write-Host "Начинается проверка", $LinkedEntities.Count, "связей"
        foreach ($LinkedEntity in $LinkedEntities) {
            $CountEntity += 1
            if (($CountEntity % 50) -eq 0) {
                Write-Host "Проверено", $CountEntity, "связей"
            }
            $LinkedEntity -match "(<ParentEntityId>|<TopBlockId>)(.*)(<\/ParentEntityId>|<\/TopBlockId>)" | Out-Null
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
                    $Links.Remove($Temp) | Out-Null
                }
                $CubeGridFileList += $TempFileList.out
                $LinksIn = $TempFileList.Count

                $TempFileList = $Links | Where-Object {$_.out -in $CubeGridFileList}
                foreach ($Temp in $TempFileList) {
                    $Links.Remove($Temp) | Out-Null
                }
                $CubeGridFileList += $TempFileList.in
                $LinksOut = $TempFileList.Count
            } until (($LinksIn -eq 0) -and ($LinksOut -eq 0))
    #Очищаем полученный список от дублей
            $CubeGridFileList = $CubeGridFileList | Sort-Object -Unique
    #Вычисляем наиболее объемный (в блоках) объект и берем его имя для чертежа
            $CountCubeBlocks = 0
            $MaxCubeBlockFile = ""

            foreach ($CubeGridFile in $CubeGridFileList) {
                $CurrentCount = (Select-String -Path ($PathToExtracted+$CubeGridFile) -Pattern "<MyObjectBuilder_CubeBlock").Count
                if ($CountCubeBlocks -lt $CurrentCount) {
                    $CountCubeBlocks = $CurrentCount
                    $MaxCubeBlockFile = $CubeGridFile
                }
            }

            (Select-String ($PathToExtracted+$MaxCubeBlockFile) -Pattern "DisplayName")[-1] -match "<DisplayName>(.*)</DisplayName>" | Out-Null
            $DisplayName = ($matches[1] -replace '["?]','_') + " Multi"         #Заменяем символы, которые не подходят для имени файла
            $DirName = $matches[1] -replace '["?]','_'                          #Заменяем символы, которые не подходят для имени файла

    #Создаем папку чертежа и сохраняем в нее чертеж, добавляя необходимые теги заголовка
            $MultiName = $MaxCubeBlockFile+"_"+$DirName+" Multi"
            $Path = $BPPath+"\"+$MultiName
            $BPFile = $Path+"\bp.sbc"
            New-Item -Path $Path -ItemType Directory -ErrorAction SilentlyContinue | Out-Null
            Set-Content -Path $BPFile -Value $Header1,$Header2,$Header3,$Header4 -Encoding UTF8NoBOM
            Add-Content -Path $BPFile -Value $Header5$DisplayName$Header5_2 -Encoding UTF8NoBOM
            Add-Content -Path $BPFile -Value $Header6 -Encoding UTF8NoBOM
    #Добавляем все гриды из полученного списка
            foreach ($CubeGridFile in $CubeGridFileList) {
    #Добавляем тег CubeGrid
                Add-Content -Path $BPFile -Value $Header7 -Encoding UTF8NoBOM
    #Забираем либо полностью весь файл, либо вычищаем теги Owner и BuiltBy
                if ($ClearOwner) {
                    $Text = (Select-String -Path ($PathToExtracted+$CubeGridFile) -Pattern "<Owner>","<BuiltBy>" -NotMatch -Encoding UTF8NoBOM).Line
                }else{
                    $Text = Get-Content -Path ($PathToExtracted+$CubeGridFile) -Encoding UTF8NoBOM
                }
    #Сохраняем чертеж этого грида
                Add-Content -Path $BPFile -Value $Text -Encoding UTF8NoBOM
    #Закрываем тег CubeGrid
                Add-Content -Path $BPFile -Value $Footer1 -Encoding UTF8NoBOM
            }
    #Добавляем закрывающие теги для чертежа
            Add-Content -Path $BPFile -Value $Footer2,$Footer3,$Footer4,$Footer5 -Encoding UTF8NoBOM
    #Выводим название чертежа и, при наличии тега AutomaticBehaviour, предупреждаем
            $AutomaticBehaviour = (Select-String -Path $BPFile -Pattern "AutomaticBehaviour").Length
            if ($AutomaticBehaviour -eq 0) {
                Write-Host $DisplayName
            } else {
                Write-Host $DisplayName -NoNewline
                Write-Host " (присутствует AutomaticBehaviour)" -ForegroundColor Red
            }
            Add-Content -Path ($BPPath+"\MultiList.txt") -Value ($MultiName+" - "+$CubeGridFileList -join " ")
        }
    }
    Write-Host

    #Удаляем временные файлы
    Remove-Item -Path $PathToExtracted -Recurse
}

do {
    Clear-Host
    Write-Host "================================== Настройки =================================="
    if ($ClearOwner) {
        Write-Host "[X]" -NoNewline
    } else {
        Write-Host "[ ]" -NoNewline
    }
    Write-Host " Q: Удалять информацию об изначальном владении объектом?"
    if ($CreateMultiGrid) {
        Write-Host "[X]" -NoNewline
    } else {
        Write-Host "[ ]" -NoNewline
    }
    Write-Host " W: Создавать чертежи объединенных объектов?"
    if ($RemoveDeformation) {
        Write-Host "[X]" -NoNewline
    } else {
        Write-Host "[ ]" -NoNewline
    }
    Write-Host " E: Удалять деформации объектов?"
    Write-Host
    Write-Host "================================== Действия ==================================="
    if (Test-Path ".\SANDBOX_0_0_0_.sbs" -PathType Leaf) {
        Write-Host "1: Обработать файл мира в папке со скриптом"
    } else {
        Write-Host "1: Обработать файл мира в папке со скриптом" -ForegroundColor DarkRed
    }
    Write-Host "2: Выбрать файл мира для обработки"
    Write-Host "3: Выбрать папку для обработки файлов мира во вложенных папках"
    Write-Host "0: Выход"
    $MenuItem = Read-Host "Сделайте выбор"
    switch ($MenuItem) {
        {@("q","Q","й","Й") -contains $_ } {
            $ClearOwner = -not $ClearOwner
        }
        {@("w","W","ц","Ц") -contains $_ } {
            $CreateMultiGrid = -not $CreateMultiGrid
        }
        {@("e","E","у","У") -contains $_ } {
            $RemoveDeformation = -not $RemoveDeformation
        }
        "1" { #Обработать файл мира в папке со скриптом
            Clear-Host
            ExtractGrid ".\SANDBOX_0_0_0_.sbs" "."
            Write-Host "Нажмите что-нибудь."
            $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown") | Out-Null
        }
        "2" { #Выбрать файл мира для обработки и папку для сохранения
            Clear-Host
            if ($FileBrowser.ShowDialog() -eq "OK") {
                $FileBrowser.InitialDirectory = ([System.IO.FileInfo]$FileBrowser.FileName).Directory
                $FolderBrowserSave.SelectedPath = ""
                if ($FolderBrowserSave.ShowDialog() -eq "OK") {
                    ExtractGrid $FileBrowser.FileName $FolderBrowserSave.SelectedPath
                } else {
                    Write-Host "Не выбрана папка для сохранения чертежа"
                }
            } else {
                Write-Host "Не выбран файл мира"
            }
            Write-Host "Нажмите что-нибудь."
            $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown") | Out-Null
        }
        "3" { #Выбрать папку для обработки файлов мира во вложенных папках
            Clear-Host
            $FolderBrowserRead.SelectedPath = ""
            $FolderBrowserSave.SelectedPath = ""
            if ($FolderBrowserRead.ShowDialog() -eq "OK") {
                $FolderBrowserRead.InitialDirectory = $FolderBrowserRead.SelectedPath
                if ($FolderBrowserSave.ShowDialog() -eq "OK") {
                    $ReadPath = $FolderBrowserRead.SelectedPath
                    $SavePath = $FolderBrowserSave.SelectedPath
                    $SandboxAllFiles = (Get-ChildItem -Path $ReadPath -Filter "SANDBOX_0_0_0_.sbs" -Recurse).FullName
                    foreach ($SandboxFile in $SandboxAllFiles) {
                        $BPSavePath = (([System.IO.FileInfo]$SandboxFile).DirectoryName) -replace [regex]::escape($ReadPath),$SavePath
                        ExtractGrid $SandboxFile $BPSavePath
                    }
                } else {
                    Write-Host "Не выбрана папка для сохранения чертежа"
                }
            } else {
                Write-Host "Не выбрана папка с файлами мира"
            }
            Write-Host "Нажмите что-нибудь."
            $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown") | Out-Null
        }
        "0" {
            return
        }
    }
} until ($input -eq '0')
