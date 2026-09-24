$ErrorActionPreference = 'Stop'

$root = Split-Path $PSScriptRoot -Parent
$assetDir = Join-Path $PSScriptRoot 'deck-assets'
$outputPath = Join-Path $PSScriptRoot 'Snowbridge-Business-Overview.pptx'
$pdfPath = Join-Path $PSScriptRoot 'Snowbridge-Business-Overview.pdf'
$renderDir = Join-Path $PSScriptRoot 'deck-render'
$homeImage = Join-Path $assetDir 'snowbridge-home.png'
$planImage = Join-Path $assetDir 'snowbridge-plan-review.png'
$publicUrl = 'https://ca-snowbridge-dev-624a.delightfultree-01bfebd8.eastus2.azurecontainerapps.io/'
$githubUrl = 'https://github.com/rayxfelipe/Snowbridge'

if (-not (Test-Path $homeImage) -or -not (Test-Path $planImage)) {
    throw 'Required live UI screenshots are missing.'
}

$C = @{
    Navy = 0x2B1A10
    Blue = 0xD47800
    BlueDark = 0x9A5B00
    BlueSoft = 0xFCEEDF
    Red = 0x2242D1
    Green = 0x107C10
    Yellow = 0x00B7FF
    Orange = 0x1675F2
    Magenta = 0x4B1FB1
    Ink = 0x262626
    Muted = 0x666666
    Line = 0xD9D9D9
    Canvas = 0xF8F8F8
    White = 0xFFFFFF
    Ice = 0xF8E9D6
}

$ppLayoutBlank = 12
$ppSaveAsOpenXMLPresentation = 24
$ppSaveAsPDF = 32
$msoTextOrientationHorizontal = 1
$msoShapeRectangle = 1
$msoShapeRoundedRectangle = 5
$msoShapeOval = 9
$msoShapeChevron = 52
$msoShapeHexagon = 10
$msoShapeDownArrow = 36
$msoFalse = 0
$msoTrue = -1

function Add-Text {
    param(
        $Slide, [string]$Text, [double]$X, [double]$Y, [double]$W, [double]$H,
        [double]$Size = 18, [int]$Color = $C.Ink, [bool]$Bold = $false,
        [string]$Align = 'left', [string]$Font = 'Segoe UI', [double]$Margin = 0,
        [string]$VAlign = 'top'
    )
    $shape = $Slide.Shapes.AddTextbox($msoTextOrientationHorizontal, $X, $Y, $W, $H)
    $shape.TextFrame.MarginLeft = $Margin
    $shape.TextFrame.MarginRight = $Margin
    $shape.TextFrame.MarginTop = $Margin
    $shape.TextFrame.MarginBottom = $Margin
    $shape.TextFrame.WordWrap = $msoTrue
    $range = $shape.TextFrame.TextRange
    $range.Text = $Text
    $range.Font.Name = $Font
    $range.Font.Size = $Size
    $range.Font.Bold = if ($Bold) { $msoTrue } else { $msoFalse }
    $range.Font.Color.RGB = $Color
    $range.ParagraphFormat.Alignment = switch ($Align) { 'center' { 2 } 'right' { 3 } default { 1 } }
    $shape.TextFrame.VerticalAnchor = switch ($VAlign) { 'middle' { 3 } 'bottom' { 4 } default { 1 } }
    return $shape
}

function Add-Box {
    param(
        $Slide, [double]$X, [double]$Y, [double]$W, [double]$H,
        [int]$Fill = $C.White, [int]$Line = $C.Line, [double]$Radius = 0,
        [double]$LineWidth = 1
    )
    $shapeType = if ($Radius -gt 0) { $msoShapeRoundedRectangle } else { $msoShapeRectangle }
    $shape = $Slide.Shapes.AddShape($shapeType, $X, $Y, $W, $H)
    $shape.Fill.ForeColor.RGB = $Fill
    $shape.Line.ForeColor.RGB = $Line
    $shape.Line.Weight = $LineWidth
    return $shape
}

function Add-Circle {
    param($Slide, [double]$X, [double]$Y, [double]$Size, [int]$Fill, [int]$Line = $Fill)
    $shape = $Slide.Shapes.AddShape($msoShapeOval, $X, $Y, $Size, $Size)
    $shape.Fill.ForeColor.RGB = $Fill
    $shape.Line.ForeColor.RGB = $Line
    return $shape
}

function Add-MicrosoftMark {
    param($Slide, [double]$X, [double]$Y, [double]$Size = 14)
    $gap = 2
    $cell = ($Size - $gap) / 2
    $colors = @($C.Red, $C.Green, $C.Blue, $C.Yellow)
    $positions = @(
        @(0, 0),
        @(($cell + $gap), 0),
        @(0, ($cell + $gap)),
        @(($cell + $gap), ($cell + $gap))
    )
    for ($i = 0; $i -lt 4; $i++) {
        $mark = $Slide.Shapes.AddShape($msoShapeRectangle, $X + $positions[$i][0], $Y + $positions[$i][1], $cell, $cell)
        $mark.Fill.ForeColor.RGB = $colors[$i]
        $mark.Line.Visible = $msoFalse
    }
}

function Add-Header {
    param($Slide, [string]$Title, [string]$Section, [int]$Number)
    Add-MicrosoftMark $Slide 42 27 16
    Add-Text $Slide 'SNOWBRIDGE' 68 27 118 18 10 $C.Muted $true | Out-Null
    Add-Text $Slide $Section.ToUpperInvariant() 750 28 165 16 9 $C.Blue $true 'right' | Out-Null
    Add-Text $Slide $Title 42 65 860 47 28 $C.Navy $true | Out-Null
    Add-Text $Slide ('{0:D2}' -f $Number) 900 492 26 18 9 $C.Muted $false 'right' | Out-Null
}

function Add-Notes {
    param($Slide, [string]$Notes)
    try {
        $placeholder = $Slide.NotesPage.Shapes.Placeholders.Item(2)
        $placeholder.TextFrame.TextRange.Text = $Notes
    } catch {
        Write-Warning "Could not add notes to slide $($Slide.SlideIndex): $($_.Exception.Message)"
    }
}

function Add-Pill {
    param($Slide, [string]$Text, [double]$X, [double]$Y, [double]$W, [int]$Fill, [int]$Color)
    Add-Box $Slide $X $Y $W 26 $Fill $Fill 1 | Out-Null
    Add-Text $Slide $Text $X ($Y + 5) $W 14 10 $Color $true 'center' | Out-Null
}

function Add-Arrow {
    param($Slide, [double]$X, [double]$Y, [double]$W = 26, [double]$H = 26, [int]$Color = $C.Blue)
    $arrow = $Slide.Shapes.AddShape($msoShapeChevron, $X, $Y, $W, $H)
    $arrow.Fill.ForeColor.RGB = $Color
    $arrow.Line.Visible = $msoFalse
}

function Add-ImageFrame {
    param($Slide, [string]$Path, [double]$X, [double]$Y, [double]$W, [double]$H)
    Add-Box $Slide ($X - 6) ($Y - 6) ($W + 12) ($H + 12) $C.White $C.Line 1 | Out-Null
    $Slide.Shapes.AddPicture($Path, $msoFalse, $msoTrue, $X, $Y, $W, $H) | Out-Null
}

$powerPoint = New-Object -ComObject PowerPoint.Application
$powerPoint.Visible = $msoTrue
$presentation = $powerPoint.Presentations.Add()
$presentation.PageSetup.SlideWidth = 960
$presentation.PageSetup.SlideHeight = 540

try {
    # Slide 1: Title
    $slide = $presentation.Slides.Add(1, $ppLayoutBlank)
    $slide.FollowMasterBackground = $msoFalse
    $slide.Background.Fill.ForeColor.RGB = $C.Navy
    Add-MicrosoftMark $slide 48 43 22
    Add-Text $slide 'MICROSOFT AZURE + SNOWFLAKE' 82 45 250 20 10 $C.White $true | Out-Null
    Add-Text $slide 'Snowbridge' 48 120 410 58 34 $C.White $true | Out-Null
    Add-Text $slide 'Governed AI access to Snowflake operations' 48 182 405 80 24 $C.Ice $false | Out-Null
    Add-Text $slide 'Ask in business language. Review the plan. Approve before execution.' 48 290 370 74 16 $C.White $false | Out-Null
    Add-Pill $slide 'BUSINESS OVERVIEW' 48 397 150 $C.Blue $C.White
    Add-ImageFrame $slide $homeImage 505 77 405 348
    Add-Text $slide 'Live on Azure Container Apps' 682 451 228 18 10 $C.Ice $false 'right' | Out-Null
    Add-Notes $slide 'Snowbridge gives business users a controlled way to request approved Snowflake operations in natural language. The key message is not unrestricted AI access. AI interprets intent, while deterministic application code controls what may execute.'

    # Slide 2: Business problem
    $slide = $presentation.Slides.Add(2, $ppLayoutBlank)
    $slide.Background.Fill.ForeColor.RGB = $C.Canvas
    Add-Header $slide 'The integration gap is a governance gap' 'Why Snowbridge' 2
    Add-Text $slide 'Business demand' 60 132 210 22 14 $C.Muted $true | Out-Null
    Add-Text $slide 'Fast answers from operational data' 60 162 230 70 24 $C.Navy $true | Out-Null
    Add-Text $slide 'Users want simple questions answered without learning SQL, credentials, or connector details.' 60 244 235 95 15 $C.Ink | Out-Null
    Add-Arrow $slide 313 245 38 38 $C.Muted
    Add-Box $slide 376 132 220 252 $C.Navy $C.Navy 1 | Out-Null
    Add-Text $slide 'SNOWBRIDGE' 398 155 176 20 12 $C.Blue $true 'center' | Out-Null
    Add-Text $slide 'One governed interface' 398 196 176 56 24 $C.White $true 'center' | Out-Null
    Add-Text $slide 'Intent translated into approved operations and validated parameters.' 405 275 162 72 14 0xD6E9F8 $false 'center' | Out-Null
    Add-Arrow $slide 620 245 38 38 $C.Blue
    Add-Text $slide 'Enterprise control' 690 132 210 22 14 $C.Muted $true | Out-Null
    Add-Text $slide 'Predictable, reviewable execution' 690 162 220 70 24 $C.Navy $true | Out-Null
    Add-Text $slide 'Allowlisted operations, explicit approval, parameter validation, managed identity, and stable API contracts.' 690 244 220 110 15 $C.Ink | Out-Null
    Add-Pill $slide 'NO MODEL-GENERATED SQL' 376 419 220 $C.BlueSoft $C.BlueDark
    Add-Notes $slide 'The business problem is not simply connectivity. Native connectors solve many copy scenarios. Snowbridge addresses the shared governance layer: consistent operations, validation, approval, and response contracts across multiple Azure orchestrators and users.'

    # Slide 3: Value at a glance
    $slide = $presentation.Slides.Add(3, $ppLayoutBlank)
    $slide.Background.Fill.ForeColor.RGB = $C.White
    Add-Header $slide 'Business value, built into the interaction' 'Value' 3
    $stats = @(
        @{ N='1'; Label='stable interface'; Copy='A common contract for business UI and technical integrations.'; Color=$C.Blue },
        @{ N='0'; Label='generated SQL'; Copy='The model never writes or submits arbitrary Snowflake queries.'; Color=$C.Green },
        @{ N='3'; Label='approved operations'; Copy='Echo, current context, and warehouse usage summary today.'; Color=$C.Orange },
        @{ N='1'; Label='human approval gate'; Copy='Execution requires explicit confirmation of the reviewed plan.'; Color=$C.Magenta }
    )
    for ($i = 0; $i -lt 4; $i++) {
        $x = 42 + ($i * 225)
        Add-Box $slide $x 137 204 288 $C.Canvas $C.Line 1 | Out-Null
        Add-Circle $slide ($x + 20) 158 52 $stats[$i].Color | Out-Null
        Add-Text $slide $stats[$i].N ($x + 20) 167 52 28 24 $C.White $true 'center' | Out-Null
        Add-Text $slide $stats[$i].Label ($x + 20) 232 164 50 19 $C.Navy $true | Out-Null
        Add-Text $slide $stats[$i].Copy ($x + 20) 300 164 92 14 $C.Ink | Out-Null
    }
    Add-Text $slide 'The result: speed for the user without surrendering control to the model.' 42 454 860 28 18 $C.BlueDark $true 'center' | Out-Null
    Add-Notes $slide 'Use these four numbers as a memory device. One interface. Zero generated SQL. Three operations in the current MVP. One explicit approval gate. The operation catalog can grow without changing the governance model.'

    # Slide 4: Governed workflow
    $slide = $presentation.Slides.Add(4, $ppLayoutBlank)
    $slide.Background.Fill.ForeColor.RGB = $C.Canvas
    Add-Header $slide 'AI interprets intent; application code controls execution' 'Governed workflow' 4
    $steps = @(
        @{ T='Ask'; C='Business question'; Color=$C.Blue },
        @{ T='Interpret'; C='Foundry structures intent'; Color=$C.Orange },
        @{ T='Validate'; C='Catalog + parameter rules'; Color=$C.Green },
        @{ T='Approve'; C='Human confirmation'; Color=$C.Magenta },
        @{ T='Execute'; C='Owned connector logic'; Color=$C.BlueDark }
    )
    for ($i = 0; $i -lt 5; $i++) {
        $x = 42 + ($i * 180)
        Add-Circle $slide ($x + 48) 164 56 $steps[$i].Color | Out-Null
        Add-Text $slide ([string]($i + 1)) ($x + 48) 176 56 26 20 $C.White $true 'center' | Out-Null
        Add-Text $slide $steps[$i].T $x 240 152 26 17 $C.Navy $true 'center' | Out-Null
        Add-Text $slide $steps[$i].C $x 277 152 58 12 $C.Muted $false 'center' | Out-Null
        if ($i -lt 4) { Add-Arrow $slide ($x + 153) 179 24 24 $C.Line }
    }
    Add-Box $slide 225 374 510 64 $C.Navy $C.Navy 1 | Out-Null
    Add-Text $slide 'Nothing runs until the reviewed plan is explicitly confirmed.' 248 393 464 26 16 $C.White $true 'center' | Out-Null
    Add-Notes $slide 'Walk left to right. Foundry produces a structured plan, not SQL. Deterministic validation checks the selected operation and parameters. The user approves. Only then does owned connector code execute a predefined operation.'

    # Slide 5: Product experience
    $slide = $presentation.Slides.Add(5, $ppLayoutBlank)
    $slide.Background.Fill.ForeColor.RGB = $C.White
    Add-Header $slide 'The approval boundary is visible to the user' 'Product experience' 5
    Add-ImageFrame $slide $planImage 42 130 598 374
    Add-Pill $slide '1  PLAIN LANGUAGE' 681 142 210 $C.BlueSoft $C.BlueDark
    Add-Text $slide 'The user asks a business question without writing SQL.' 681 180 210 58 14 $C.Ink | Out-Null
    Add-Pill $slide '2  REVIEW' 681 258 210 26 $C.BlueSoft $C.BlueDark
    Add-Text $slide 'The approved operation and parameters are shown before execution.' 681 296 210 72 14 $C.Ink | Out-Null
    Add-Pill $slide '3  APPROVE' 681 388 210 26 $C.BlueSoft $C.BlueDark
    Add-Text $slide 'A deliberate action supplies the confirmation required by the API.' 681 426 210 62 14 $C.Ink | Out-Null
    Add-Notes $slide 'This is the customer-facing experience. The interface removes the need to manually wrap JSON in Swagger, but it does not remove the approval control. Swagger remains available separately for technical reviewers.'

    # Slide 6: Azure architecture
    $slide = $presentation.Slides.Add(6, $ppLayoutBlank)
    $slide.Background.Fill.ForeColor.RGB = $C.Canvas
    Add-Header $slide 'A compact Azure foundation with clear trust boundaries' 'Architecture' 6
    $nodes = @(
        @{ X=42; Y=185; W=150; H=82; T='Business UI'; S='Same-origin web experience'; F=$C.White; L=$C.Blue },
        @{ X=235; Y=165; W=190; H=122; T='Azure Container Apps'; S='FastAPI + governed execution'; F=$C.Navy; L=$C.Navy },
        @{ X=485; Y=120; W=190; H=84; T='Microsoft Foundry'; S='Intent → structured plan'; F=$C.White; L=$C.Orange },
        @{ X=485; Y=250; W=190; H=84; T='Snowflake adapter'; S='Mock today; connector-ready'; F=$C.White; L=$C.Green },
        @{ X=735; Y=120; W=180; H=84; T='Azure Container Registry'; S='Immutable application image'; F=$C.White; L=$C.Blue },
        @{ X=735; Y=250; W=180; H=84; T='Key Vault'; S='Secret boundary'; F=$C.White; L=$C.Magenta }
    )
    foreach ($n in $nodes) {
        Add-Box $slide $n.X $n.Y $n.W $n.H $n.F $n.L 1 2 | Out-Null
        $titleColor = if ($n.F -eq $C.Navy) { $C.White } else { $C.Navy }
        $copyColor = if ($n.F -eq $C.Navy) { $C.Ice } else { $C.Muted }
        Add-Text $slide $n.T ($n.X + 12) ($n.Y + 14) ($n.W - 24) 24 16 $titleColor $true 'center' | Out-Null
        Add-Text $slide $n.S ($n.X + 12) ($n.Y + 47) ($n.W - 24) 30 11 $copyColor $false 'center' | Out-Null
    }
    Add-Arrow $slide 200 207 26 26 $C.Blue
    Add-Arrow $slide 440 150 26 26 $C.Orange
    Add-Arrow $slide 440 270 26 26 $C.Green
    Add-Arrow $slide 691 150 26 26 $C.Blue
    Add-Arrow $slide 691 270 26 26 $C.Magenta
    Add-Box $slide 235 376 680 70 $C.BlueSoft $C.BlueSoft 1 | Out-Null
    Add-Text $slide 'Managed identity' 258 391 150 20 14 $C.BlueDark $true | Out-Null
    Add-Text $slide 'Resource-scoped access to ACR, Key Vault, and Foundry. No API key is required in the deployed app.' 418 388 468 40 13 $C.Ink | Out-Null
    Add-Notes $slide 'The application runs as one Container App for the MVP. Its system-assigned managed identity has resource-scoped ACR Pull, Key Vault Secrets User, and Cognitive Services OpenAI User roles. Application Insights and Log Analytics provide monitoring.'

    # Slide 7: Controls
    $slide = $presentation.Slides.Add(7, $ppLayoutBlank)
    $slide.Background.Fill.ForeColor.RGB = $C.White
    Add-Header $slide 'Defense in depth, not model confidence' 'Trust and controls' 7
    $layers = @(
        @{ Y=142; W=760; X=100; H=56; T='1  Allowlisted operation catalog'; F=$C.Navy; K=$C.White },
        @{ Y=210; W=660; X=150; H=56; T='2  Deterministic parameter validation'; F=$C.Blue; K=$C.White },
        @{ Y=278; W=560; X=200; H=56; T='3  Explicit human confirmation'; F=$C.Magenta; K=$C.White },
        @{ Y=346; W=460; X=250; H=56; T='4  Parameterized connector-owned SQL'; F=$C.Green; K=$C.White }
    )
    foreach ($layer in $layers) {
        Add-Box $slide $layer.X $layer.Y $layer.W $layer.H $layer.F $layer.F 1 | Out-Null
        Add-Text $slide $layer.T ($layer.X + 20) ($layer.Y + 16) ($layer.W - 40) 24 16 $layer.K $true 'center' | Out-Null
    }
    Add-Text $slide 'The model cannot bypass the catalog, invent parameters, or execute directly.' 190 437 580 30 17 $C.Navy $true 'center' | Out-Null
    Add-Notes $slide 'Avoid saying the model is trusted because it is accurate. The safety story is architectural. Even an incorrect or malicious request must pass the catalog, deterministic validation, human confirmation, and owned connector logic.'

    # Slide 8: Demo guide
    $slide = $presentation.Slides.Add(8, $ppLayoutBlank)
    $slide.Background.Fill.ForeColor.RGB = $C.Canvas
    Add-Header $slide 'A three-minute customer demonstration' 'Demo guide' 8
    Add-ImageFrame $slide $homeImage 515 128 395 247
    $demoSteps = @(
        @{ N='01'; T='Ask'; C='“Show warehouse usage for the last 7 days.”' },
        @{ N='02'; T='Review'; C='Point out the approved operation and days parameter.' },
        @{ N='03'; T='Approve'; C='Explain that execution requires explicit confirmation.' },
        @{ N='04'; T='Result'; C='Show the structured two-row mock result.' }
    )
    for ($i = 0; $i -lt 4; $i++) {
        $y = 136 + ($i * 83)
        Add-Text $slide $demoSteps[$i].N 42 $y 48 26 18 $C.Blue $true | Out-Null
        Add-Text $slide $demoSteps[$i].T 101 $y 110 24 16 $C.Navy $true | Out-Null
        Add-Text $slide $demoSteps[$i].C 214 ($y - 1) 260 42 13 $C.Ink | Out-Null
    }
    Add-Box $slide 515 403 395 58 $C.Navy $C.Navy 1 | Out-Null
    $linkShape = Add-Text $slide 'Open the live Snowbridge demo  →' 536 421 350 24 15 $C.White $true 'center'
    $linkShape.ActionSettings.Item(1).Hyperlink.Address = $publicUrl
    Add-Notes $slide 'Keep the demo short. Start with a familiar usage question. Pause at the review state and reinforce that the model selected an approved operation. Then approve and show the result. Mention that the data is intentionally mocked for the hackathon environment.'

    # Slide 9: Roadmap and close
    $slide = $presentation.Slides.Add(9, $ppLayoutBlank)
    $slide.FollowMasterBackground = $msoFalse
    $slide.Background.Fill.ForeColor.RGB = $C.Navy
    Add-MicrosoftMark $slide 48 40 22
    Add-Text $slide 'SNOWBRIDGE' 82 42 150 20 10 $C.White $true | Out-Null
    Add-Text $slide 'Start governed. Expand deliberately.' 48 102 710 52 32 $C.White $true | Out-Null
    Add-Text $slide 'The MVP proves the control model before expanding the operation catalog and connecting a production Snowflake account.' 48 167 735 58 17 $C.Ice | Out-Null
    Add-Text $slide 'NOW' 48 271 135 24 13 $C.Blue $true | Out-Null
    Add-Text $slide "Business UI`rFoundry planner`rMock Snowflake adapter`rAzure deployment" 48 309 260 118 17 $C.White | Out-Null
    Add-Text $slide 'NEXT' 358 271 135 24 13 $C.Green $true | Out-Null
    Add-Text $slide "Production Snowflake identity`rExpanded approved operations`rPersistent job processing`rEnterprise audit integration" 358 309 300 118 17 $C.White | Out-Null
    Add-Box $slide 710 270 200 174 $C.White $C.White 1 | Out-Null
    Add-Text $slide 'Business outcome' 732 292 156 20 13 $C.BlueDark $true 'center' | Out-Null
    Add-Text $slide 'Faster access to approved operations with a clear, reviewable control boundary.' 732 330 156 92 15 $C.Navy $true 'center' | Out-Null
    $repoShape = Add-Text $slide 'GitHub repository' 48 475 150 18 11 $C.Ice $true
    $repoShape.ActionSettings.Item(1).Hyperlink.Address = $githubUrl
    $demoShape = Add-Text $slide 'Live demo' 785 475 125 18 11 $C.Ice $true 'right'
    $demoShape.ActionSettings.Item(1).Hyperlink.Address = $publicUrl
    Add-Notes $slide 'Close by separating what is proven from what is next. The MVP proves the governed interaction, Foundry integration, managed identity, deployment, and API contracts. Production Snowflake connectivity and broader operations are deliberate next steps.'

    if (Test-Path $outputPath) { Remove-Item $outputPath -Force }
    if (Test-Path $pdfPath) { Remove-Item $pdfPath -Force }
    if (Test-Path $renderDir) { Remove-Item $renderDir -Recurse -Force }
    New-Item -ItemType Directory -Path $renderDir | Out-Null

    $presentation.SaveAs($outputPath, $ppSaveAsOpenXMLPresentation)
    $presentation.SaveAs($pdfPath, $ppSaveAsPDF)
    $presentation.Export($renderDir, 'PNG', 1600, 900)
    Write-Output "PPTX=$outputPath"
    Write-Output "PDF=$pdfPath"
    Write-Output "RENDER=$renderDir"
} finally {
    $presentation.Close()
    $powerPoint.Quit()
    [System.Runtime.InteropServices.Marshal]::ReleaseComObject($presentation) | Out-Null
    [System.Runtime.InteropServices.Marshal]::ReleaseComObject($powerPoint) | Out-Null
    [GC]::Collect()
    [GC]::WaitForPendingFinalizers()
}