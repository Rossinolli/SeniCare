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
| **Cadastro** | Nome com **sugestões de um catálogo offline** (~170 medicamentos, busca sem acento e por nome comercial — "Aradois" leva à Losartana); **gramatura, quantidade, forma farmacêutica e motivo escolhidos em listas** (padronização para o alarme); horários fixos em dias da semana ou de X em X horas; duração; foto da caixa; estoque. |
| **Alarme** | Tela cheia com o remédio padronizado ("Losartana · 50 mg · 1 comprimido · Para: Pressão alta") e as respostas Tomei / Adiar 10 min / Não vou tomar. Botões **Tomei** e **Adiar** também na própria notificação. Lembrete 30 min antes (opcional). |
| **Histórico** | Calendário com marcação por dia, doses de cada dia (inclusive de remédios removidos) e **remédios já utilizados** — remover um remédio não apaga o passado. |
| **Relatório** | Adesão dos últimos 7 dias, dia a dia, compartilhável em texto (WhatsApp, e-mail...). |
| **Ajustes** | Tema (Padrão azul, Claro, Escuro), tamanho do texto até 160% (somado à acessibilidade do Android), modo de aviso, som, vibração, **testar alarme**, painel "Saúde do alarme" com cada permissão necessária, estoque e compartilhamento da lista de remédios. |

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
