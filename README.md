# SeniCare

Aplicativo de lembretes de medicamentos pensado para o **público sênior**:
alarme na hora exata (inclusive com o celular bloqueado), resposta com um
toque ("Tomei" direto na notificação), histórico das doses e relatório de
adesão para levar ao médico. Funciona **100% offline**: os dados de saúde
ficam só no aparelho.

> Trabalho de Conclusão de Curso. Flutter (Dart) · Android 7+ (API 24) ·
> estrutura preparada para iOS.

## Funcionalidades

| Área | O que faz |
|---|---|
| **Início** | Agenda do dia dose a dose, com status em texto e ícone (tomada, não tomada, atrasada, hora de tomar, a tomar), progresso do dia e próxima dose. Tocar numa dose permite registrar, corrigir ou desfazer a resposta. |
| **Cadastro** | Nome com **sugestões de um catálogo offline** (~1.960 princípios ativos e ~7.500 nomes buscáveis: 521 curados + a base oficial da **ANVISA**; busca sem acento e por nome comercial — escolher "Microvlar" mantém "Microvlar" no cadastro e mostra o princípio ativo para conferência); **gramatura, quantidade, forma farmacêutica e motivo escolhidos em listas** (padronização para o alarme); horários fixos em dias da semana ou de X em X horas; duração; foto da caixa; estoque. |
| **Alarme** | Tela cheia com o remédio padronizado ("Losartana · 50 mg · 1 comprimido · Para: Pressão alta") e as respostas Tomei / Adiar 10 min / Não vou tomar. Botões **Tomei** e **Adiar** também na própria notificação. Lembrete 30 min antes (opcional). |
| **Histórico** | Calendário com marcação por dia, doses de cada dia (inclusive de remédios removidos) e **remédios já utilizados** — remover um remédio não apaga o passado. |
| **Relatório** | Adesão dos últimos 7 dias, dia a dia, compartilhável em texto (WhatsApp, e-mail...). |
| **Ajustes** | Tema (Padrão azul, Claro, Escuro), tamanho do texto até 160% (somado à acessibilidade do Android), modo de aviso, som, vibração, painel "Saúde do alarme" com cada permissão necessária, estoque, compartilhamento da lista de remédios e **"Indicar o SeniCare"** (envia o próprio arquivo do app pelo WhatsApp, Drive, Quick Share...). |

## Como rodar

Pré-requisitos: Flutter 3.41+, JDK 21 (o Gradle procura um JDK 21 instalado —
ver `android/gradle/gradle-daemon-jvm.properties`) e Android SDK.

```bash
flutter pub get
flutter run
```

Testes e análise:

```bash
flutter test
flutter analyze
```

Após mudar as tabelas em `lib/data/database.dart`, regenere o código do
banco:

```bash
dart run build_runner build
```

## Documentação

- [`docs/ARQUITETURA.md`](docs/ARQUITETURA.md) — camadas, modelo de dados,
  motor de alarmes e as decisões técnicas com suas justificativas.
- [`docs/PUBLICACAO.md`](docs/PUBLICACAO.md) — assinatura de release, políticas
  da Play Store para as permissões usadas e notas para a versão iOS.

## Estrutura

```
lib/
  domain/     regras de negócio em Dart puro (horários, agenda, posologia, catálogo)
  data/       banco local (Drift/SQLite) e repositório
  services/   notificações e alarmes, fotos, sincronização em segundo plano
  core/       tema, componentes visuais, preferências e estado (Riverpod)
  features/   telas (início, remédios, alarme, histórico, ajustes)
test/         testes de domínio, banco (migração real) e widgets
assets/       fonte embutida, catálogo de medicamentos e identidade visual
tool/         gerador da logo (python tool/gerar_logo.py)
```

## Catálogo de medicamentos

`assets/data/medicamentos_br.json` é gerado — não edite à mão:

```bash
# 1. (opcional, para atualizar) baixar a base da ANVISA e resumir
python tool/importar_anvisa.py DADOS_ABERTOS_MEDICAMENTOS.csv
# 2. juntar curadoria + ANVISA e validar
python tool/gerar_catalogo.py
```

* Fonte oficial: [dados abertos da ANVISA — medicamentos registrados](https://dados.anvisa.gov.br/dados/DADOS_ABERTOS_MEDICAMENTOS.csv) (só registros **ativos**, sem vacinas, soros e uso hospitalar). O resumo fica em `tool/dados/anvisa_resumo.json`.
* Curadoria (`tool/catalogo_*.py`): formas, gramaturas e usos dos remédios mais comuns; a classe terapêutica da ANVISA sugere o "Para que serve?" dos demais (`tool/classes_anvisa.py`).

