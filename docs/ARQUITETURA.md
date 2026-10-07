# Arquitetura do SeniCare

Este documento descreve como o aplicativo está organizado e, principalmente,
**por que** cada decisão foi tomada. As decisões foram guiadas por três
requisitos não funcionais do domínio: o alarme **não pode falhar** (saúde),
o público é **idoso** (acessibilidade) e os dados são **sensíveis**
(privacidade / LGPD).

## 1. Camadas

```
features/  (telas)  ──observa──▶  core/estado.dart (Riverpod)
                                        │
                                        ▼
services/ (alarmes, fotos) ──▶ data/repositorio.dart ──▶ data/database.dart (Drift/SQLite)
        │                               │
        └──────────────▶ domain/ (Dart puro: horários, agenda, posologia)
```

- **domain/** não importa Flutter nem banco. Toda regra de "quando tomar" está
  em `DoseSchedule` e toda regra de "qual o status de cada dose" em
  `montarAgenda`. Home, Relatório, alarmes e alerta de estoque usam as mesmas
  funções — antes, cada tela tinha sua própria cópia da regra e elas
  divergiam (ex.: a Home mostrava 3 doses de 8 em 8 h, mas só 1 alarme por
  dia era agendado).
- **data/** é a única camada que fala SQL. O repositório expõe consultas
  observáveis (`Stream`), de modo que as telas se atualizam sozinhas quando
  qualquer dado muda.
- **services/** concentra efeitos colaterais do sistema operacional.
- **core/estado.dart** liga tudo com Riverpod: as telas apenas observam
  provedores, sem receber tema/tamanho de fonte por parâmetro.

## 2. Modelo de dados (Drift, schema v8)

| Tabela | Colunas principais |
|---|---|
| `medicamentos` | nome, horário(s), dias da semana, frequência (horários fixos / intervalo), intervalo em horas, início, fim, **dosagem**, **quantidade por dose**, **forma**, **motivo**, foto, estoque, **arquivado_em** |
| `historico` | medicamento, momento da resposta, tomado (sim/não), **nome do remédio na época**, **dia de referência**, **horário da dose** |

Decisões:

- **Remoção lógica (`arquivado_em`)**: remover um remédio tira-o da agenda e
  dos alarmes, mas preserva o histórico (pedido dos orientadores) e mantém o
  relatório correto para os dias em que ele estava em uso.
- **`horario_dose`** em cada resposta: permite atribuir "Tomei" à dose exata
  (08:00 ou 20:00), desfazer/corrigir uma resposta e registrar no dia certo
  uma dose adiada que passou da meia-noite.
- **`nome_medicamento`** (instantâneo): o histórico continua legível mesmo
  após editar ou remover o remédio.
- **Compatibilidade**: o arquivo e o formato das colunas são os mesmos da
  versão com sqflite. As migrações v1→v7 foram preservadas e a v7→v8 é
  testada em `test/data/banco_test.dart` com o SQL exato do app antigo.
- **WAL + busy_timeout**: os botões da notificação e a sincronização em
  segundo plano gravam a partir de outro motor Flutter (outra conexão).

## 3. Motor de alarmes

`NotificationService.sincronizarAlarmes()` é uma **reconciliação
idempotente**:

1. calcula o conjunto desejado de avisos (lembrete, alarme, estoque) para a
   janela das próximas semanas, a partir do banco e das preferências;
2. lista o que está pendente no sistema;
3. cancela o que não deveria existir e agenda só o que falta.

Cada aviso tem um **ID estável** (hash FNV-1a de tipo + remédio + instante) e
um payload com uma **assinatura** do conteúdo; se o nome, a dose ou o modo de
aviso mudarem, a assinatura muda e o aviso é recriado. Por ser idempotente,
a reconciliação roda sempre que algo muda, ao abrir o app e **a cada 6 horas
em segundo plano (WorkManager)**, mantendo a janela deslizante mesmo se o
usuário passar dias sem abrir o app.

Orçamento: o Android aceita até 500 alarmes por app; o iOS, 64 notificações
pendentes. O limite de ocorrências por remédio é calculado dividindo o
orçamento pelo número de remédios.

Camadas de entrega do alarme (da mais forte para a mais simples):

1. **Overlay** (permissão "Exibir sobre outros apps"): o alarme abre a tela
   cheia mesmo com o celular desbloqueado e em uso;
2. **Notificação de tela cheia** (`fullScreenIntent`): liga a tela e mostra o
   alarme sobre a tela de bloqueio;
3. **Notificação de alta prioridade** com os botões Tomei / Adiar.

O som usa o canal de **alarme** do Android (não o de notificação), em loop
até a resposta. O painel "Saúde do alarme" em Ajustes mostra o estado de cada
permissão e leva à tela do sistema que a resolve.

## 4. Interface e acessibilidade

- **Tema** (`core/tema.dart`): três temas com cores semânticas
  (`CoresSeniCare`) acessadas por `context.cores`. Contrastes calculados
  pelo WCAG 2.1: texto principal ≥ 7:1, secundário ≥ 4,5:1, contorno de
  campos ≥ 3:1. No tema Claro os cards são superfícies brancas sólidas com
  borda definida.
- **Texto**: corpo de 17 px (o padrão do Material é 14), multiplicado pela
  escala escolhida no app (90–160%) **e** pela acessibilidade do Android, com
  teto de 2x. Testes de widget montam os componentes em 2x.
- **Status nunca só por cor**: cada estado da dose tem ícone e texto
  (daltonismo).
- **Fontes embutidas**: a fonte caligráfica (Great Vibes, licença OFL) vai
  dentro do app. Antes ela era baixada da internet pelo pacote google_fonts —
  sem conexão aparecia a fonte padrão. O corpo do texto usa a fonte do
  sistema (Roboto no Android, como o app do Facebook).
- **Padronização da posologia**: forma, gramatura, quantidade e motivo vêm
  de listas fechadas (`domain/posologia.dart`), com plural correto
  ("½ comprimido", "2 comprimidos") — o alarme sempre exibe o mesmo formato.
- **Responsividade**: conteúdo limitado a 640 dp e centralizado em tablets.

## 5. Privacidade (Privacy by Design)

- Nenhum dado sai do aparelho sem ação explícita do usuário (compartilhar).
- Sem internet em tempo de execução (fontes e catálogo embutidos).
- O app só aparece sobre a tela de bloqueio **enquanto um alarme está
  aberto**; antes ficava sempre visível, expondo a lista de remédios.
- Logs com nomes de remédio só em modo debug.
- Backup automático do Android desativado (`allowBackup=false`).

## 6. Testes

| Arquivo | Cobre |
|---|---|
| `test/domain/dose_schedule_test.dart` | horários fixos, intervalos (inclusive "paradoxo da meia-noite"), início/fim/remoção do tratamento, próximas doses, descrição da frequência |
| `test/domain/agenda_e_posologia_test.dart` | status das doses, atribuição por horário, correção de resposta, plural da posologia, busca no catálogo |
| `test/data/banco_test.dart` | migração real v7→v8, remoção sem perda de histórico, dose após a meia-noite, resumo do calendário |
| `test/widget/temas_test.dart` | os três temas sem asserções do Material, texto em 2x |

A CI (`.github/workflows/ci.yml`) roda formatação, análise estática com
`--fatal-infos`, testes, verifica o código gerado do banco e compila o APK.

## 7. Limitações conhecidas e próximos passos

- **Alarme de overlay em segundo plano**: o canal nativo só existe no motor
  da Activity; a sincronização feita pelo WorkManager agenda a notificação de
  tela cheia, mas não o overlay (ele volta a ser agendado na próxima
  abertura do app).
- **iOS**: a estrutura está pronta (bundle `br.com.senicare`, permissões e
  limite de 64 notificações), mas não há tela cheia nem overlay no iOS; o
  alarme usa notificação *time-sensitive* (ver `docs/PUBLICACAO.md`).
- **Catálogo**: as dosagens sugeridas são atalhos; o usuário deve conferir a
  embalagem. Uma evolução natural é usar a base oficial da ANVISA.
