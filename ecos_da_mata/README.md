# Ecos da Mata

Demo de jogo 2D autoral feita em Python com pygame-ce. A jogadora explora uma floresta,
resgata seis vaga-lumes e evita javalis antes que o tempo termine. Não há combate: o foco é
movimentação, exploração e interação.

## Requisitos atendidos

- jogo gráfico 2D, sem uso do console como interface;
- demo completa e jogável, com vitória, derrota e reinício;
- interação por teclado e mouse;
- sprites, cenário, interface, música e efeitos sonoros originais;
- menu principal, tela de instruções, pausa e tela de resultado;
- executável sem janela de console e assets incluídos na build Windows;
- arquivo `IDENTIFICACAO.txt` incluído no pacote de entrega.

## Controles

| Ação | Teclas |
|---|---|
| Mover | WASD ou setas |
| Resgatar vaga-lume próximo | E |
| Corrida curta | Shift ou Espaço |
| Pausar/continuar | P ou Esc |
| Ativar/desativar áudio | M |
| Tela cheia | F11 |

Os menus também aceitam mouse. Na tela inicial: `Enter` inicia, `H` abre a ajuda e `Esc` sai.

## Executar pelo código-fonte

Python 3.10 ou superior é recomendado.

### Windows

```bat
py -3 -m venv .venv
.venv\Scripts\python -m pip install -r requirements.txt
.venv\Scripts\python main.py
```

### macOS/Linux

```bash
python3 -m venv .venv
.venv/bin/python -m pip install -r requirements.txt
.venv/bin/python main.py
```

## Testar

```bash
python -m pip install -r requirements-dev.txt
python -m pytest -q
python main.py --smoke-test
```

## Compilar e criar o ZIP para entrega no Windows

1. Preencha nome completo e RU em `IDENTIFICACAO.txt`.
2. Em um computador Windows com Python instalado, execute `build_windows.bat`.
3. O script instala dependências em `.venv`, testa o jogo, gera o executável e cria:
   `dist\EcosDaMata_Entrega_Windows.zip`.
4. Extraia o ZIP e execute `EcosDaMata.exe` uma vez antes de enviar.

O PyInstaller não faz compilação cruzada. Por isso, a build `.exe` precisa ser gerada no
Windows; executar o mesmo comando no macOS produz um aplicativo para macOS, não para Windows.

## Estrutura

```text
ecos_da_mata/
├── main.py                 # ponto de entrada
├── game/                   # regras, entidades, cenas e recursos
├── assets/images/          # sprites e texturas PNG
├── assets/sounds/          # música e efeitos WAV
├── tests/                  # testes automatizados
├── tools/generate_assets.py
├── EcosDaMata.spec         # configuração PyInstaller
├── build_windows.bat       # build e ZIP automatizados
└── IDENTIFICACAO.txt       # nome e RU do aluno
```

## Autoria dos assets

Os PNGs e WAVs foram criados para este projeto por `tools/generate_assets.py`. Veja
`ASSETS_E_LICENCAS.md`.
