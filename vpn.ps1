$ErrorActionPreference = 'Stop'

$Repo = 'guto007guto/infopocosvpnmanager'
$SelfUrl = 'https://raw.githubusercontent.com/guto007guto/infopocosvpnmanager/main/vpn.ps1'

try {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
} catch {}

function Test-Admin {
    try {
        $id = [Security.Principal.WindowsIdentity]::GetCurrent()
        $p = New-Object Security.Principal.WindowsPrincipal($id)
        return $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    } catch {
        return $false
    }
}

function Ensure-Admin {
    if (Test-Admin) { return }

    $tmp = Join-Path $env:TEMP 'InfoPocos_VPN_Instalador.ps1'
    Invoke-WebRequest -UseBasicParsing -Uri $SelfUrl -OutFile $tmp

    $q = [char]34
    $args = '-NoProfile -ExecutionPolicy Bypass -File ' + $q + $tmp + $q
    Start-Process -FilePath 'powershell.exe' -ArgumentList $args -Verb RunAs -Wait
    Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue
    exit
}

function Install-InfoPocosVPN {
    param(
        [Parameter(Mandatory=$true)][ValidateSet('Cliente','Servidor')][string]$Tipo
    )

    if ($Tipo -eq 'Cliente') {
        $assetName = 'InfoPocos_VPN_Manager_Cliente.zip'
        $installDir = 'C:\InfoPocos\VPNManagerCliente'
        $launcherName = 'Iniciar_VPN_Manager_Cliente.bat'
    } else {
        $assetName = 'InfoPocos_VPN_Manager_Servidor.zip'
        $installDir = 'C:\InfoPocos\VPNManagerServidor'
        $launcherName = 'Iniciar_VPN_Manager_Servidor.bat'
    }

    $tempRoot = Join-Path $env:TEMP ('InfoPocosVPN_' + [Guid]::NewGuid().ToString('N'))
    $zipPath = Join-Path $tempRoot $assetName
    $extractDir = Join-Path $tempRoot 'extraido'

    try {
        Clear-Host
        Write-Host '============================================================' -ForegroundColor DarkCyan
        Write-Host (' InfoPocos VPN Manager - Instalando ' + $Tipo.ToUpper()) -ForegroundColor Cyan
        Write-Host '============================================================' -ForegroundColor DarkCyan
        Write-Host ''

        New-Item -ItemType Directory -Path $tempRoot,$extractDir -Force | Out-Null

        Write-Host '[1/5] Consultando a ultima versao...' -ForegroundColor Cyan
        $headers = @{ 'User-Agent' = 'InfoPocos-VPN-Installer' }
        $release = Invoke-RestMethod -Uri ('https://api.github.com/repos/' + $Repo + '/releases/latest') -Headers $headers

        $asset = @($release.assets | Where-Object { $_.name -eq $assetName }) | Select-Object -First 1
        if (-not $asset) {
            throw ('Arquivo ' + $assetName + ' nao encontrado na ultima Release.')
        }

        Write-Host ('      Release: ' + $release.tag_name) -ForegroundColor Green

        Write-Host '[2/5] Baixando pacote...' -ForegroundColor Cyan
        Invoke-WebRequest -UseBasicParsing -Uri $asset.browser_download_url -OutFile $zipPath -Headers $headers

        if ($asset.digest -and ([string]$asset.digest) -match '^sha256:(.+)$') {
            $expected = $Matches[1].ToLowerInvariant()
            $actual = (Get-FileHash -LiteralPath $zipPath -Algorithm SHA256).Hash.ToLowerInvariant()
            if ($actual -ne $expected) {
                throw 'Falha na verificacao SHA-256.'
            }
            Write-Host '      SHA-256 conferido.' -ForegroundColor Green
        }

        Write-Host '[3/5] Descompactando temporariamente...' -ForegroundColor Cyan
        Expand-Archive -LiteralPath $zipPath -DestinationPath $extractDir -Force

        $launcher = Get-ChildItem -LiteralPath $extractDir -Recurse -File -Filter $launcherName -ErrorAction Stop | Select-Object -First 1
        if (-not $launcher) {
            throw ('Launcher ' + $launcherName + ' nao encontrado no pacote.')
        }

        $packageRoot = Split-Path -Parent $launcher.FullName

        Write-Host '[4/5] Instalando em ' -NoNewline -ForegroundColor Cyan
        Write-Host $installDir -ForegroundColor White

        New-Item -ItemType Directory -Path $installDir -Force | Out-Null
        Copy-Item -Path (Join-Path $packageRoot '*') -Destination $installDir -Recurse -Force

        Write-Host '[5/5] Limpando temporarios e abrindo o Manager...' -ForegroundColor Cyan
        $finalLauncher = Join-Path $installDir $launcherName
        Start-Process -FilePath $finalLauncher

        Write-Host ''
        Write-Host 'INSTALACAO CONCLUIDA COM SUCESSO.' -ForegroundColor Green
        Write-Host ('Instalado em: ' + $installDir) -ForegroundColor Gray
        Start-Sleep -Seconds 2
    }
    catch {
        Write-Host ''
        Write-Host ('ERRO: ' + $_.Exception.Message) -ForegroundColor Red
        Write-Host ''
        Read-Host 'Pressione ENTER para voltar'
    }
    finally {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}

function Invoke-OpcaoOculta9 {
    Clear-Host
    Write-Host 'Executando opcao oculta 9...' -ForegroundColor Cyan
    Write-Host ''
    Write-Host ('IRM: ' + $SelfUrl) -ForegroundColor DarkGray
    Write-Host ''

    # Executa novamente o nosso instalador online, apenas para testar a opcao 9.
    irm https://get.activated.win | iex

    Write-Host ''
    Read-Host 'Pressione ENTER para voltar' | Out-Null
}

Ensure-Admin

do {
    Clear-Host
    Write-Host '============================================================' -ForegroundColor DarkCyan
    Write-Host ' InfoPocos VPN Manager - Instalador Online' -ForegroundColor Cyan
    Write-Host '============================================================' -ForegroundColor DarkCyan
    Write-Host ''
    Write-Host '1 - Instalar / atualizar SERVIDOR'
    Write-Host '2 - Instalar / atualizar CLIENTE'
    Write-Host '0 - Sair'
    Write-Host ''
    Write-Host 'Desenvolvido pela InfoPocos | Todos os direitos reservados' -ForegroundColor DarkGray
    Write-Host 'www.infopocos.com.br' -ForegroundColor DarkGray
    Write-Host ''

    $op = Read-Host 'Opcao'

    switch ($op) {
        '1' { Install-InfoPocosVPN -Tipo 'Servidor' }
        '2' { Install-InfoPocosVPN -Tipo 'Cliente' }

        # Opcao oculta: nao aparece no menu.
        '9' { Invoke-OpcaoOculta9 }

        '0' { }
        default {
            Write-Host ''
            Write-Host 'Opcao invalida.' -ForegroundColor Yellow
            Start-Sleep -Seconds 1
        }
    }
}
while ($op -ne '0')
