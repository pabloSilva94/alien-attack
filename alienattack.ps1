Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Carregar imagens
$naveImagePath = "https://github.com/pabloSilva94/alien-attack/blob/main/ace.png"
$naveUfoPath = "https://github.com/pabloSilva94/alien-attack/blob/main/ufo.png"
$explosionImagePath = "C:\Users\pablo.almeida\Pictures\fire.png"
try {
    $naveImage = [System.Drawing.Image]::FromFile($naveImagePath)
} catch {
    Write-Warning "Não foi possível carregar a imagem da nave. Usando retângulo azul."
    $naveImage = $null
}

try {
    $naveUfo = [System.Drawing.Image]::FromFile($naveUfoPath)
} catch {
    Write-Warning "Não foi possível carregar a imagem do UFO. Usando retângulo verde."
    $naveUfo = $null
}
try {
    $explosionImage = [System.Drawing.Image]::FromFile($explosionImagePath)
} catch {
    Write-Warning "Não foi possível carregar a imagem de explosão. Usando efeito visual simples."
    $explosionImage = $null
}

# Criar janela do jogo
$form = New-Object Windows.Forms.Form
$form.Text = "Alien Attack"
$form.Size = '600,800'
$form.BackColor = 'Black'
$form.KeyPreview = $true

# Inicializar os timers
$gameTimer = New-Object Windows.Forms.Timer
$alienTimer = New-Object Windows.Forms.Timer
$autoShootTimer = New-Object Windows.Forms.Timer

# Configurar intervalos dos timers
$gameTimer.Interval = 20  # Atualização do jogo
$alienTimer.Interval = 1000  # Criação de aliens
$autoShootTimer.Interval = 500  # Disparo automático

# Jogador
$player = New-Object Windows.Forms.PictureBox
$player.Size = '50,50'
if ($naveImage -ne $null) {
    $player.Image = $naveImage
    $player.SizeMode = [System.Windows.Forms.PictureBoxSizeMode]::StretchImage
} else {
    $player.BackColor = 'Blue'
}
$player.Location = '275,700'
$form.Controls.Add($player)

# Label de pontuação
$scoreLabel = New-Object Windows.Forms.Label
$scoreLabel.ForeColor = 'White'
$scoreLabel.Font = 'Arial,16'
$scoreLabel.AutoSize = $true
$scoreLabel.Location = '10,10'
$scoreLabel.Text = "Pontuação: 0"
$form.Controls.Add($scoreLabel)

# Variáveis do jogo
$bullets = New-Object System.Collections.Generic.List[object]
$aliens = New-Object System.Collections.Generic.List[object]
$score = 0
$gameOver = $false
$lastShotTime = [DateTime]::Now

# Função para criar inimigos
function New-Alien {
    $alien = New-Object Windows.Forms.PictureBox
    $alien.Size = '40,40'
    if ($naveUfo -ne $null) {
        $alien.Image = $naveUfo
        $alien.SizeMode = [System.Windows.Forms.PictureBoxSizeMode]::StretchImage
    } else {
        $alien.BackColor = 'Green'
    }
    $alien.Location = New-Object Drawing.Point((Get-Random -Minimum 0 -Maximum 550), 0)
    $form.Controls.Add($alien)
    $aliens.Add($alien)
}

# FUNÇÃO DE EXPLOSÃO CORRIGIDA E TESTADA
function New-Explosion {
    param($location)
    
    $explosion = New-Object Windows.Forms.PictureBox
    $explosion.Size = '50,50'
    $explosion.BackColor = 'Transparent'
    
    if ($explosionImage -ne $null) {
        $explosion.Image = $explosionImage
        $explosion.SizeMode = [System.Windows.Forms.PictureBoxSizeMode]::StretchImage
    } else {
        $bmp = New-Object System.Drawing.Bitmap(50, 50)
        $graphics = [System.Drawing.Graphics]::FromImage($bmp)
        $graphics.FillEllipse([System.Drawing.Brushes]::Orange, 0, 0, 50, 50)
        $explosion.Image = $bmp
    }
    
    $explosion.Location = $location
    $form.Controls.Add($explosion)
    $form.Controls.SetChildIndex($explosion, 0) # Deixar explosão na frente

    # Agora criamos o timer
    $timer = New-Object Windows.Forms.Timer
    $timer.Interval = 300 # milissegundos

    # Capturamos a referência da explosão
    $thisExplosion = $explosion

    # Evento do timer
    $timer.Add_Tick({
        param($sender, $e) # <-- Aqui é OBRIGATÓRIO!

        # Parar e destruir o timer
        $sender.Stop()
        $sender.Dispose()

        # Remover a explosão da tela
        if ($thisExplosion -ne $null -and -not $thisExplosion.IsDisposed) {
            $form.Controls.Remove($thisExplosion)
            $thisExplosion.Dispose()
        }
    })

    $timer.Start()
}


# Configurar eventos dos timers
$gameTimer.Add_Tick({
    if ($gameOver) { return }
    
    # Mover balas
    for ($i = $bullets.Count - 1; $i -ge 0; $i--) {
        $bullets[$i].Top -= 10
        if ($bullets[$i].Top -lt 0) {
            $form.Controls.Remove($bullets[$i])
            $bullets.RemoveAt($i)
        }
    }
    
    # Mover aliens
    for ($i = $aliens.Count - 1; $i -ge 0; $i--) {
        $aliens[$i].Top += 5
        if ($aliens[$i].Bounds.IntersectsWith($player.Bounds)) {
            $gameOver = $true
            $gameTimer.Stop()
            $alienTimer.Stop()
            $autoShootTimer.Stop()
            [System.Windows.Forms.MessageBox]::Show("Game Over! Pontuação: $score")
            $form.Close()
            return
        }
        if ($aliens[$i].Top -gt $form.ClientSize.Height) {
            $form.Controls.Remove($aliens[$i])
            $aliens.RemoveAt($i)
        }
    }
    
    # Verificar colisões com explosão
    for ($i = $bullets.Count - 1; $i -ge 0; $i--) {
        for ($j = $aliens.Count - 1; $j -ge 0; $j--) {
            if ($bullets[$i].Bounds.IntersectsWith($aliens[$j].Bounds)) {
                # Criar explosão centralizada
                $explosionX = $aliens[$j].Left + ($aliens[$j].Width / 2) - 25
                $explosionY = $aliens[$j].Top + ($aliens[$j].Height / 2) - 25
                $explosionLocation = New-Object Drawing.Point($explosionX, $explosionY)
                New-Explosion -location $explosionLocation
                $form.Controls.Remove($bullets[$i])
                $form.Controls.Remove($aliens[$j])
                $bullets.RemoveAt($i)
                $aliens.RemoveAt($j)
                $score += 10
                $scoreLabel.Text = "Pontuação: $score"
                break
            }
        }
    }
})

$alienTimer.Add_Tick({
    if (-not $gameOver) {
        New-Alien
    }
})

$autoShootTimer.Add_Tick({
    if (-not $gameOver) {
        # Criar nova bala
        $bullet = New-Object Windows.Forms.PictureBox
        $bullet.Size = '5,15'
        $bullet.BackColor = 'Yellow'
        $bullet.Location = New-Object Drawing.Point(($player.Left + ($player.Width / 2) - 2), $player.Top)
        $form.Controls.Add($bullet)
        $bullets.Add($bullet)
    }
})

# Configurar controles do teclado
$form.Add_KeyDown({
    param($sender, $e)
    
    if ($gameOver) { return }
    
    $speed = 10
    switch ($e.KeyCode) {
        'Left' {
            if ($player.Left - $speed -ge 0) {
                $player.Left -= $speed
            }
        }
        'Right' {
            if ($player.Left + $player.Width + $speed -le $form.ClientSize.Width) {
                $player.Left += $speed
            }
        }
    }
})

# Iniciar o jogo
$form.Show()
$gameTimer.Start()
$alienTimer.Start()
$autoShootTimer.Start()
[System.Windows.Forms.Application]::Run($form)
