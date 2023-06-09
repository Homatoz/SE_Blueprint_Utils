# Утилиты для работы с чертежами в Space Engineers

Не найдя на просторах интернета ничего (может быть плохо искал?), что помогло бы мне выдрать из сценариев все чертежи, решил набросать эти скрипты. Ну и поделиться, вдруг пригодятся кому.

Хочу предупредить, что работают они только с PowerShell 7. Скачать его можно здесь:
<https://github.com/PowerShell/PowerShell/releases/tag/v7.3.4>

## Sandbox2Blueprints

Выдирает из файла мира все находящиеся в нем объекты и превращает их в файлы чертежа.

### Подготовка к запуску

Перед запуском скрипта при необходмости можно внести изменения в настройки, отредактировав первые строки файла `Sandbox2Blueprints.ps1`:

`$ClearOwner = $false` - оставлять (`$false`) или удалять (`$true`) информацию об изначальном владении объектом?

`$CreateMultiGrid = $true` - создавать (`$true`) или нет (`$false`) чертежи объединенных объектов?

`$RemoveDeformation = $true` - оставлять (`$false`) или удалять (`$true`) деформации объектов?

`$RemoveAI = $true` - оставлять (`$false`) или удалять (`$true`) автоматическое поведение?

`$ExtractProjectorBP = $true` - извлекать (`$true`) или нет (`$false`) чертежи из проектора?

Также, настройки можно будет изменить в меню скрипта, но только для текущей сессии. Настройки, измененные через меню, не сохраняются.

### Запуск скрипта

Для запуска скрипта требуется выполнить команду

```text
pwsh Sandbox2Blueprints.ps1
```

### Меню

В открывшемся окне терминала PowerShell появится следующее меню. Недоступные пункты будут выделены красным цветом.

```text
================================== Настройки ==================================
[ ] Q: Удалять информацию об изначальном владении объектом?
[X] W: Создавать чертежи объединенных объектов?
[X] E: Удалять деформации объектов?
[X] R: Удалять автоматическое поведение?
[X] T: Извлекать чертежи из проектора?

================================== Действия ===================================
1: Обработать файл мира в папке со скриптом
2: Выбрать файл мира для обработки
3: Выбрать папку для обработки файлов мира во вложенных папках
0: Выход
Сделайте выбор:
```

Для выбора пункта требуется ввести соответствующий пункту символ и нажать Enter.

Вводом Q, W, E, R или T можно переключить значение соответствующей настройки. `[ ]` - настройка выключена, `[X]` - настройка включена.

Вводом от 1 до 3 можно выбрать способ обработки файла мира.

#### 1: Обработать файл мира в папке со скриптом

Для возможности выбора данного пункта требуется, чтобы файл `SANDBOX_0_0_0_.sbs` был размещен в папке со скриптом. Результат также будет размещен в папке со скриптом.

#### 2: Выбрать файл мира для обработки

При выборе данного пункта появятся окна, в которых надо будет выбрать файл `SANDBOX_0_0_0_.sbs`, который планируется превратить в чертежи, и папку, в которую эти чертежи будут сохранены. По умолчанию для сохранения предлагается папка, в которой игра хранит локальные чертежи - `%AppData%\SpaceEngineers\Blueprints\local`.

#### 3: Выбрать папку для обработки файлов мира во вложенных папках

При выборе данного пункта появятся окна, в которых надо будет папку, в которой хранятся файлы миров, которые планируется превратить в чертежи, и папку, в которую эти чертежи будут сохранены. По умолчанию для сохранения предлагается папка, в которой игра хранит локальные чертежи - `%AppData%\SpaceEngineers\Blueprints\local`. Чертежи будут размещаться с сохранением структуры исходной папки.

> **Совет:** Данным способом можно получить все чертежи из сценариев и миров игры. Для этого в качестве папки, в которой хранятся файлы миров, указать папку с игрой.

### Результаты выполнения

После выполнения скрипта в папке, выбранной для сохранения, появятся множество подпапок с чертежами со следующим именованием

```text
XXXXpX_Name Multi
```

`XXXX` - это порядковый номер расположения объекта в файле мира.
`pX` - добавляется только при наличии у объекта проекторов с чертежами. При наличии вложенных проекторов это значение будет указано в имени папки несколько раз.
`Name` - название объекта, взятое из параметра DisplayName.
`Multi` - добавляется только для объединенных объектов.

Также в случае если были сформированы объединенные объекты, в папке будет находиться файл `MultiList.txt`, в котором будет указано название чертежа с мультиобъектами и номера одиночных объектов, из которых он состоит.

```text
0063_PV-4-SV3 Multi - 0060 0061 0062 0063 0064
```

## CheckIntegrity

Формирует для чертежа файл с послойной схемой объекта и списком недостроенных блоков.

Для запуска надо разместить файл bp.sbc в папку со скриптом и запустить скрипт командой

```text
pwsh CheckIntegrity.ps1
```

После выполнения скрипта в папке появятся файл `GridIntegrity`, в котором будет послойная схема объекта. Обозначения для схемы следующие: `.` - пустое место, `O` - место с блоком, `X` - место с недостроенным блоком. Также после схемы будут указаны координаты, тип блока и, если есть, название недостроеннного объекта.

```text
Уровень -1

.........................
.........................
.........................
....OO..OO...............
....O...OO...............
....O...OO...............
.........................
....OOOOO....OOOXOOO.....
....OOO.OOOOOOOXOOOOXXX..
....OOOOOO.O.OOO...O.XX..
....OOO.OOOOOOOOOOOOOXX..
....OOOOO....OOOXOOO.....
.........................
....OO..OO...............
....O...OO...............
....O...OO...............
.........................
.........................
.........................

-8 7 LargeSteelCatwalk 
-7 6 LargeSteelCatwalkPlate 
-7 11 ButtonPanelLarge Button Panel 6
-7 12 LargeSteelCatwalk 
-7 13 LargeSteelCatwalk 
-6 12 LargeSteelCatwalkPlate 
-6 13 LargeSteelCatwalkPlate 
-5 12 LargeSteelCatwalk 
-5 13 LargeSteelCatwalk 
-4 7 LargeSteelCatwalk 
```

## GetBlocksList

Формирует для чертежа файл с послойной схемой объекта и списком блоков.

Для запуска надо разместить файл bp.sbc в папку со скриптом и запустить скрипт командой

```text
pwsh CheckIntegrity.ps1
```

После выполнения скрипта в папке появятся файл `CheckList`, в котором будет послойная схема объекта. Обозначения для схемы следующие: `.` - пустое место, `O` - место с блоком. Также после схемы будут указаны тип блока и, если есть, его название. Названия блоков располагаются в порядке их появления на схеме.

```text
Уровень -1

.........................
.........................
.........................
....OO..OO...............
....O...OO...............
....O...OO...............
.........................
....OOOOO....OOOOOOO.....
....OOO.OOOOOOOOOOOOOOO..
....OOOOOO.O.OOO...O.OO..
....OOO.OOOOOOOOOOOOOOO..
....OOOOO....OOOOOOO.....
.........................
....OO..OO...............
....O...OO...............
....O...OO...............
.........................
.........................
.........................

LargeBlockArmorCorner2Base 
LargeHydrogenTank Hydrogen Tank 2
LargeBlockArmorInvCorner2Tip 
LargeBlockArmorCorner2Base 
LargeBlockArmorSlope2Base 
LargeBlockArmorBlock 
LargeBlockArmorSlope2Base 
LargeBlockArmorCorner2Base 
LargeBlockArmorInvCorner2Tip 
...
```

## Планы по развитию

- [x] Выбор обрабатываемого файла.
- [x] Обработка всех файлов мира во вложенных папках.
- [x] ~~Обработка всех файлов мира из папки игры.~~
- [x] Получение чертежей, встроенных в проекторы.
  - [x] Получение чертежей из проекторов, встроенных в чертежи из проекторов.
- [x] Удаление деформаций блоков.
- [x] Удаление поведения ИИ.
- [x] Меню для настройки параметров перед запуском основной части скрипта.
- [ ] Обработка файлов Prefab.
- [ ] Сравнение чертежей.
- [ ] Сделать CheckIntegrity и GetBlocksList более полезными и информативными. Сейчас это просто наброски для чего-то большего.
