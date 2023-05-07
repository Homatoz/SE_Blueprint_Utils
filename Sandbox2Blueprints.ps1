#Настройки
$ClearOwner = $false        #Удалять теги Owner и BuiltBy?
$CreateMultiGrid = $true    #Создавать чертежи объединенных объектов?
$RemoveDeformation = $true  #Удалять деформации объектов?
$RemoveAI = $true			#Удалять автоматическое поведение?

#Шаблон XML для чертежей
$BPTemplate = 
'<?xml version="1.0"?>'+
'<Definitions xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">'+
'<ShipBlueprints>'+
'<ShipBlueprint xsi:type="MyObjectBuilder_ShipBlueprintDefinition">'+
'<Id Type="MyObjectBuilder_ShipBlueprintDefinition" />'+
'<CubeGrids>'+
'</CubeGrids>'+
'</ShipBlueprint>'+
'</ShipBlueprints>'+
'</Definitions>'

#Переменные для работы c Select-Xml
$SENamespace = @{xsi = "http://www.w3.org/2001/XMLSchema-instance"}
$XPathCubeGrid = '/MyObjectBuilder_Sector/SectorObjects/MyObjectBuilder_EntityBase[@xsi:type="MyObjectBuilder_CubeGrid"] | /MyObjectBuilder_Sector/SectorObjects/MyObjectBuilder_EntityBase[@xsi:type="MyObjectBuilder_ProxyAntenna"]/ComponentContainer/Components/ComponentData/Component[@xsi:type="MyObjectBuilder_UpdateTrigger"]/SerializedPirateStation'

#Объекты для выбора файлов и папок
Add-Type -AssemblyName System.Windows.Forms
$FileBrowser = New-Object System.Windows.Forms.OpenFileDialog -Property @{ Filter = "Файл мира|SANDBOX_0_0_0_.sbs" ; Title = "Выберите файл мира" }
$FolderBrowserRead = New-Object System.Windows.Forms.FolderBrowserDialog -Property @{ Description = "Выберите папку с файлами мира";
                                                                                      UseDescriptionForTitle = $True}
$FolderBrowserSave = New-Object System.Windows.Forms.FolderBrowserDialog -Property @{ InitialDirectory = $env:APPDATA+"\SpaceEngineers\Blueprints\local\";
                                                                                      Description = "Выберите папку для сохранения чертежей";
                                                                                      UseDescriptionForTitle = $True}

#Объекты для работы с XML
$XMLSandbox = New-Object -TypeName 'System.Xml.XmlDocument'
$XMLSave = New-Object -TypeName 'System.Xml.XmlDocument'
$XMLExtracted = New-Object -TypeName 'System.Xml.XmlDocument'

#Функция для удаления всякого трэша
function RemoveNodes {
    param (
        [System.Xml.XmlDocument]$XML,
        [string]$Name
    )
    $XML.SelectNodes("//$Name") | ForEach-Object {
        $_.ParentNode.RemoveChild($_) | Out-Null
    }
}

#Функция выгрызания и формирования чертежей
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
    
    #Создаем папку для выгрызенных объектов
    New-Item -Path $PathToExtracted -ItemType Directory -ErrorAction SilentlyContinue | Out-Null

    #Обрабатываем файл Sandbox.
    Write-Host "Загружаем и чистим Sandbox"
    Write-Host
    
    $XMLSandbox.Load($PathToSandbox)

    if ($ClearOwner) {
        RemoveNodes -XML $XMLSandbox -Name 'Owner'
        RemoveNodes -XML $XMLSandbox -Name 'BuiltBy'
    }

    if ($RemoveDeformation) {
        RemoveNodes -XML $XMLSandbox -Name 'Skeleton'
    }

    if ($RemoveAI) {
        RemoveNodes -XML $XMLSandbox -Name 'AutomaticBehaviour'
    }

    Write-Host "Выгрызаем CubeGrid из Sandbox"
    Write-Host

    Select-Xml -Xml $XMLSandbox -XPath $XPathCubeGrid -Namespace $SENamespace | ForEach-Object {
        $CubeGridFile +=1
        $XMLSave.LoadXml($_.Node.OuterXml)
        $XMLSave.Save($PathToExtracted+$CubeGridFile.ToString().PadLeft(4,"0"))
    }

    #Обрабатываем полученные объекты CubeGrid
    Write-Host "Создаем чертежи"

    $ExtractedFiles = Get-ChildItem -Path $PathToExtracted

    foreach ($File in $ExtractedFiles){
        #Забираем файл
        $XMLExtracted.Load($File.FullName)
        #Получаем название для чертежа из DisplayName
        $DisplayName = $XMLExtracted.SelectSingleNode('*/DisplayName').InnerText
        $DisplayName = $DisplayName -replace '["?]','_'    #Заменяем символы, которые не подходят для имени файла
        #Создаем чертеж
        $XMLSave.LoadXml($BPTemplate)
        $CubeGridsNode = $XMLSave.SelectSingleNode('//CubeGrids')
        $CubeGridNewNode = $XMLSave.CreateElement('CubeGrid')
        $CubeGridsNode.AppendChild($CubeGridNewNode) | Out-Null
        $CubeGridNewNode.InnerXml = $XMLExtracted.FirstChild.InnerXml
        $XMLSave.SelectSingleNode('//Id[@Type="MyObjectBuilder_ShipBlueprintDefinition"]').SetAttribute('Subtype',$DisplayName)
        #Создаем папку чертежа и сохраняем в нее чертеж
        $Path = $BPPath+"\"+$File.Name+"_"+$DisplayName
        $BPFile = $Path+"\bp.sbc"
        New-Item -Path $Path -ItemType Directory -ErrorAction SilentlyContinue | Out-Null
        $XMLSave.Save($BPFile)
        #Выводим название чертежа и, при наличии тега AutomaticBehaviour, предупреждаем
        $AutomaticBehaviour = $XMLSave.SelectSingleNode('//AutomaticBehaviour')
        if ($AutomaticBehaviour) {
            Write-Host $DisplayName -NoNewline
            Write-Host " (присутствует AutomaticBehaviour)" -ForegroundColor Red
        } else {
            Write-Host $DisplayName
        }
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
            #Инициализируем переменные для поиска самого большого объекта
            $CountCubeBlocks = 0
            $MaxCubeBlockFile = ""
            #Создаем чертеж
            $XMLSave.LoadXml($BPTemplate)
            $CubeGridsNode = $XMLSave.SelectSingleNode('//CubeGrids')
            #Добавляем все объекты из полученного списка
            foreach ($CubeGridFile in $CubeGridFileList) {
                $XMLExtracted.Load($PathToExtracted+$CubeGridFile)
                $CubeBlocks = $XMLExtracted.SelectNodes('*/CubeBlocks/MyObjectBuilder_CubeBlock')
                #Ищем самый большой (в блоках) объект и берем его имя для чертежа
                if ($CountCubeBlocks -lt $CubeBlocks.Count) {
                    $CountCubeBlocks = $CubeBlocks.Count
                    $MaxCubeBlockFile = $CubeGridFile
                    $DisplayName = $XMLExtracted.SelectSingleNode('*/DisplayName').InnerText
                }
                $CubeGridNewNode = $XMLSave.CreateElement('CubeGrid')
                $CubeGridsNode.AppendChild($CubeGridNewNode) | Out-Null
                $CubeGridNewNode.InnerXml = $XMLExtracted.FirstChild.InnerXml
            }
            $DisplayName = ($DisplayName -replace '["?]','_') + " Multi"    #Заменяем символы, которые не подходят для имени файла
            $XMLSave.SelectSingleNode('//Id[@Type="MyObjectBuilder_ShipBlueprintDefinition"]').SetAttribute('Subtype',$DisplayName)
            #Создаем папку чертежа и сохраняем в нее чертеж
            $MultiName = $MaxCubeBlockFile+"_"+$DisplayName
            $Path = $BPPath+"\"+$MultiName
            $BPFile = $Path+"\bp.sbc"
            New-Item -Path $Path -ItemType Directory -ErrorAction SilentlyContinue | Out-Null
            $XMLSave.Save($BPFile)
            #Выводим название чертежа и, при наличии тега AutomaticBehaviour, предупреждаем
            $AutomaticBehaviour = $XMLSave.SelectSingleNode('//AutomaticBehaviour')
            if ($AutomaticBehaviour) {
                Write-Host $DisplayName -NoNewline
                Write-Host " (присутствует AutomaticBehaviour)" -ForegroundColor Red
            } else {
                Write-Host $DisplayName
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
    if ($RemoveAI) {
        Write-Host "[X]" -NoNewline
    } else {
        Write-Host "[ ]" -NoNewline
    }
    Write-Host " R: Удалять автоматическое поведение?"
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
        {@("r","R","к","К") -contains $_ } {
            $RemoveAI = -not $RemoveAI
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
