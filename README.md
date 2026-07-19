# StacyDash V4

Dashboard leve e direto para helicópteros no EdgeTX. O StacyDash reúne, em uma única tela, as informações essenciais de voo e telemetria sem a complexidade de uma interface mais carregada.

O widget foi feito para rádios coloridos com tela **800 × 480** e utiliza a interface LVGL do EdgeTX. Ele oferece perfis específicos para helicópteros elétricos, nitro e modelos OMPHOBBY.

**Download da versão mais recente:** [GitHub Releases](https://github.com/vhuzalo/StacyDash/releases/latest)

> **Aviso de segurança:** use por sua conta e risco. O StacyDash apenas lê e exibe a telemetria; ele não envia comandos MSP nem altera a controladora de voo. A única gravação feita pelo widget é o contador de voos em `/flights-count.csv`. Não use o dashboard como substituto para alarmes e verificações de segurança configurados no rádio, ESC ou flight controller.

## Funcionalidades

- headspeed atual e máximo da sessão;
- RPM de cauda, quando disponível;
- estado do governor do Rotorflight, com fallback pelo percentual de throttle;
- estado `ARMED`/`DISARMED` e flags que impedem o arm;
- perfil PID ativo junto ao contador de voos;
- corrente atual e máxima;
- tensão por célula atual e mínima;
- tensão do BEC e mínima;
- temperatura do ESC atual e máxima;
- barra de bateria com percentual e capacidade consumida;
- suporte à estimativa Smart Fuel do Rotorflight (`Bat%`);
- detecção automática de LiPo/LiHV pela tensão por célula;
- perfil de bateria do Rotorflight (`BAT#`);
- qualidade do link e nível da bateria do transmissor;
- imagem personalizada e nome do modelo;
- contador de voos separado por modelo;
- alertas por voz e vibração para a bateria;
- alertas por vibração para temperatura do ESC e baixa tensão do BEC;
- controle opcional dos LEDs RGB do rádio conforme o estado de arm;
- perfil Nitro com barra e alerta próprios para a bateria do receptor;
- 18 opções de tema, incluindo fundo transparente;
- atualização da telemetria e das estatísticas em segundo plano.

## Sensores de telemetria

Os sensores são detectados automaticamente. Não é necessário selecioná-los nas opções do widget, mas os nomes abaixo devem chegar ao EdgeTX **exatamente como escritos** (inclusive maiúsculas e minúsculas).

O dashboard continua funcionando parcialmente quando sensores opcionais não estão disponíveis; nesses campos ele mostra `--` ou `NO DATA`.

### Rotorflight — perfis Electric e Nitro

| Sensor | Informação exibida ou uso |
| --- | --- |
| `Hspd` | headspeed, máximo da sessão e validação do estado do motor |
| `Tspd` | RPM da cauda |
| `Vbec` | tensão do BEC; no perfil Nitro, tensão da bateria 2S do receptor |
| `Vcel` | tensão por célula e mínimo da sessão |
| `Cel#` | quantidade de células do pack |
| `Curr` | corrente e máximo da sessão |
| `Capa` | capacidade consumida em mAh |
| `Bat%` | percentual calculado pelo Rotorflight/Smart Fuel |
| `Tesc` | temperatura do ESC e máximo da sessão |
| `Gov` | estado do governor e validação do estado do motor |
| `Thr` | percentual de throttle usado como fallback visual quando `Gov` não está disponível |
| `ARM` | estado armado/desarmado (`1` e `3` são tratados como armado) |
| `ARMD` | máscara das flags que impedem o arm |
| `PID#` | número do perfil PID selecionado |
| `BAT#` | número do perfil de bateria |
| `Vbat` | tensão total do pack e validação da presença da bateria |

No perfil Electric, `Bat%` é a fonte preferencial do indicador de carga. Se ele não estiver disponível, o widget estima o percentual a partir de `Vcel`. Por isso, para uma barra funcional, disponibilize `Bat%` **ou** `Vcel`; `Vbat` ajuda a confirmar que há um pack conectado quando `Bat%` é zero.

### Estado do governor sem `Gov`

Quando o sensor `Gov` fornece um estado válido, ele sempre tem prioridade e o dashboard mostra os estados completos do Rotorflight, como `OFF`, `IDLE`, `SPOOLUP`, `ACTIVE`, `AUTOROT` e `BAILOUT`.

Se o modelo não utiliza governor — por exemplo, com o modo Electric Governor desativado no Rotorflight — e `Gov` não está disponível, o componente passa a inferir o estado pelo sensor `Thr`:

| Percentual de `Thr` | Estado exibido |
| --- | --- |
| 0% | `OFF` |
| acima de 0% até 50% | `SPOOLUP` |
| acima de 50% | `ACTIVE` |

Se nem `Gov` nem `Thr` estiverem disponíveis, o componente mostra `--`. Um valor presente, porém desconhecido ou inválido em `Gov`, também mostra `--` em vez de ocultar uma possível mudança futura do protocolo com a inferência de throttle.

### Arm, flags e perfil PID

A topbar mostra `ARMED` ou `DISARMED` a partir de `ARM`. Quando houver flags publicadas por `ARMD`, como `THROTTLE`, `ARM SWITCH`, `NO PREARM`, `FAIL SAFE` e `CALIBRATING`, elas têm prioridade e substituem o estado no mesmo componente. Se `ARMD` não for encontrado, o widget também tenta a fonte `Arming Disable`.

O sensor `PID#` é exibido junto ao contador de voos; por exemplo, `10 Flights · P2`. Alterações de arm, governor e perfil são anunciadas pelos mesmos áudios utilizados no DBK. O primeiro valor recebido apenas inicializa o estado, evitando anúncios indevidos ao abrir ou recarregar o widget.

No perfil Nitro, `Vbec` é tratado como a tensão total de uma bateria de receptor 2S. Os limites mínimo e máximo são configuráveis no widget.

### OMPHOBBY

| Sensor | Informação exibida ou uso |
| --- | --- |
| `NR` | RPM do rotor, máximo da sessão e validação do estado do motor |
| `RxBt` | tensão total do pack |
| `Curr` | corrente e máximo da sessão |
| `Capa` | capacidade consumida em mAh |
| `Bat%` | percentual da bateria |
| `Tmp` | temperatura do ESC e máximo da sessão |

Os receptores OMPHOBBY não fornecem a contagem de células usada pelo widget. O StacyDash deduz esse valor pelo nome do modelo:

- nomes contendo `M1` são tratados como 2S;
- nomes contendo `M2` são tratados como 3S.

Sem `M1` ou `M2` no nome, a tensão por célula e a barra de bateria não podem ser calculadas. O perfil OMPHOBBY não possui fonte para RPM de cauda, tensão de BEC ou estado do governor; esses campos aparecem sem dados.

### Link e transmissor

- Qualidade do link: tenta, nesta ordem, `RQly`, `RQLY` e `LQ`; se nenhum existir, usa `RSSI`/`getRSSI()`.
- Bateria do rádio: usa a fonte interna `tx-voltage`. Nas opções do widget, selecione se o pack do transmissor é LiPo ou Li-Ion para ajustar a escala do indicador.

## Instalação

Copie o conteúdo desta pasta para a raiz do cartão SD do rádio, preservando esta estrutura:

```text
/
├── flights-count.csv
├── IMAGES/
└── WIDGETS/
    └── StacyDashV4/
        ├── main.lua
        ├── flights.lua
        ├── status.lua
        ├── themes.lua
        ├── ui.lua
        ├── leds.lua
        ├── default.png
        ├── audio/
        │   ├── armed.wav
        │   ├── disarmed.wav
        │   ├── profile.wav
        │   ├── gov/
        │   └── profile/
        └── BatterySounds/
            ├── 50%.wav
            ├── 40%.wav
            ├── 30%.wav
            ├── 20%.wav
            ├── 10%.wav
            ├── 0%.wav
            └── dead.wav
```

Depois:

1. Reinicie o rádio ou recarregue os scripts Lua.
2. Crie uma tela de telemetria de página inteira.
3. Adicione o widget `StacyDashV4`.
4. Selecione o tipo correto em **Heli Type**.
5. Configure **Motor Switch** com o controle físico usado para ligar/desligar o motor.

O layout exige uma tela 800 × 480 e uma zona praticamente cheia (mínimo de 760 × 420). Em outra resolução, o widget exibe uma mensagem de incompatibilidade.

### Organização do código

O widget é dividido em módulos carregados uma única vez na inicialização:

| Arquivo | Responsabilidade |
| --- | --- |
| `main.lua` | ciclo do widget, telemetria, alertas de bateria e composição da tela |
| `flights.lua` | contador por modelo e persistência segura de `flights-count.csv` |
| `status.lua` | `ARM`, `ARMD`, `PID#` e áudios de transição de arm/governor/perfil |
| `themes.lua` | nomes e paletas dos temas |
| `ui.lua` | criação, cache e atualização eficiente das primitivas LVGL |
| `leds.lua` | animações e cores dos LEDs RGB conforme arm e disable flags |

Essa separação reduz a quantidade de variáveis locais no módulo principal — limitada a 200 pelo Lua do EdgeTX — e permite acrescentar funcionalidades sem concentrar toda a implementação em `main.lua`.

### Deploy pelo computador

Em Linux, o script `deploy.sh` copia os arquivos para um cartão SD ou rádio montado no sistema. Informe a raiz do cartão, isto é, a pasta dentro da qual ficam `WIDGETS` e `IMAGES`:

```bash
./deploy.sh --dry-run /run/media/$USER/EDGETX
./deploy.sh /run/media/$USER/EDGETX
```

O modo `--dry-run` apenas lista as operações necessárias. O script compara o conteúdo local com o destino e copia somente arquivos ausentes ou diferentes; arquivos já atualizados são ignorados. Se `/flights-count.csv` já existir no rádio, ele é sempre preservado para não apagar o histórico de voos.

### Releases no GitHub

O workflow `.github/workflows/release.yml` gera automaticamente um pacote pronto para o cartão SD. Para publicar uma versão, crie e envie uma tag iniciada por `v`:

```bash
git tag v1.0.0
git push origin v1.0.0
```

O GitHub Actions criará o release e anexará:

- `StacyDash-v1.0.0.zip`, com `WIDGETS/`, `IMAGES/` e este README na raiz;
- `StacyDash-v1.0.0.zip.sha256`, para conferir a integridade do download.

O pacote não inclui `flights-count.csv`, evitando que uma atualização extraída sobre o cartão apague o histórico. Em uma instalação nova, o widget cria esse arquivo automaticamente ao registrar o primeiro voo. Também é possível copiar o arquivo inicial do repositório ou usar `deploy.sh`, que só o instala quando ainda não existe.

O workflow pode ser executado manualmente na aba **Actions** para testar e baixar o artefato sem criar um GitHub Release. Se existir um arquivo `release-notes/<tag>.md`, ele será usado como descrição; caso contrário, o GitHub gera as notas automaticamente.

## Configuração do widget

| Opção | Função | Padrão |
| --- | --- | --- |
| **Theme** | tema de cores ou fundo transparente | Dark |
| **TX Battery** | química da bateria 2S do transmissor | LiPo |
| **Min. Flight Time (sec)** | duração mínima para registrar um voo | 60 s |
| **Heli Type** | Electric, Nitro ou OMPHOBBY | Electric |
| **Batt Reserve %** | reserva removida da escala útil da bateria | 20% |
| **Battery Voice** | ativa anúncios de bateria | desligado |
| **Display LEDs** | ativa o controle dos LEDs RGB do rádio | desligado |
| **Rx Pack Minimum** | tensão considerada vazia no perfil Nitro | 6,60 V |
| **Rx Pack Maximum** | tensão considerada cheia no perfil Nitro | 8,40 V |
| **Motor Switch** | chave física do motor | não definida |

### Motor Switch

Escolha a chave física completa, por exemplo `SG`, e não uma condição de posição como “SG para cima”. O widget detecta o movimento da chave e só pausa alertas da bateria de voo quando a telemetria confirma motor parado:

- Rotorflight: pelos estados reconhecidos de `Gov` ou por `Hspd` igual a zero;
- OMPHOBBY: por `NR` igual a zero.

Essa validação evita que um simples movimento de chave silencie um alerta com o motor ainda em funcionamento. Depois que o aviso crítico `dead.wav` começa, mover a chave também reconhece e encerra suas repetições.

## Alertas

Com **Battery Voice** ativado, o widget anuncia os níveis de 50%, 40%, 30%, 20%, 10% e 0%. Ao chegar a 0%, reproduz `dead.wav` repetidamente até o reconhecimento pela chave do motor. Se um arquivo de percentual estiver ausente, tenta usar a voz numérica do EdgeTX.

As vibrações de segurança funcionam independentemente dos arquivos de áudio:

- bateria de voo: dois pulsos ao cruzar 10% e vibração contínua por alguns segundos ao chegar a 0%;
- temperatura do ESC: um alerta após permanecer acima de 110 °C por 0,5 s; rearma abaixo de 100 °C;
- tensão do BEC: um alerta após permanecer abaixo de 4,8 V por 0,5 s; rearma acima de 5,0 V;
- perfil Nitro: após a bateria do receptor permanecer no mínimo configurado ou abaixo dele por 2 s, vibra repetidamente e, se a voz estiver ativa, repete `dead.wav`.

Alertas dependentes de telemetria não são disparados quando o link foi confirmado como perdido.

Além dos alertas de bateria, a pasta `/WIDGETS/StacyDashV4/audio` contém anúncios de transição para:

- `ARMED` e `DISARMED`;
- governor `OFF`, `IDLE`, `SPOOLUP` e `ACTIVE`;
- troca dos perfis PID 1 a 6.

## LEDs RGB

Com **Display LEDs** ativado, o StacyDash controla a faixa RGB do rádio seguindo o mesmo padrão do DBK:

- disable flags presentes: animação vermelha circulante;
- `ARMED`: azul sólido;
- `DISARMED`: vermelho sólido;
- opção desativada: LEDs apagados.

O recurso só atua quando o rádio e a versão do EdgeTX expõem `LED_STRIP_LENGTH`, `setRGBLedColor()` e `applyRGBLedColors()`. Em rádios sem essa API, o módulo não executa nenhuma operação.

## Contador de voos

O widget usa o **Timer 1** do modelo (o primeiro timer do EdgeTX). Um voo é acrescentado quando o tempo decorrido cruza o valor configurado em **Min. Flight Time (sec)**. Portanto, configure esse timer para iniciar durante o voo — normalmente associado à chave ou à condição de motor ativo.

Os totais são armazenados por nome de modelo em `/flights-count.csv`, na raiz do cartão. O mesmo arquivo pode ser compartilhado com outros dashboards compatíveis. Mantenha o cabeçalho e uma linha por modelo:

```csv
model_name,flight_count
# api_ver=1
Goblin,10
```

## Imagem do modelo

Coloque uma imagem PNG ou BMP em `/IMAGES` usando exatamente o nome do modelo configurado no EdgeTX:

```text
/IMAGES/Nimbus 550 V2.png
```

Se não houver uma imagem correspondente, o widget usa `/WIDGETS/StacyDashV4/default.png`. Caracteres inválidos em nomes de arquivo (`\ / : * ? " < > |`) são substituídos por `_` ao procurar a imagem.

## Observações

- O estado e os máximos/mínimos são mantidos apenas durante a sessão atual do widget.
- A telemetria é processada a 10 Hz, inclusive quando outra página do rádio está aberta.
- A reserva de bateria altera a escala mostrada. Com a reserva padrão de 20%, os 20% reais passam a representar 0% utilizável no dashboard.
- Para segurança, mantenha também os alarmes essenciais configurados diretamente no EdgeTX e nos demais componentes do modelo.
