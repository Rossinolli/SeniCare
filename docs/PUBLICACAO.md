# Publicação do SeniCare

## 1. Identificador do app

`br.com.senicare` (Android `applicationId` e iOS `PRODUCT_BUNDLE_IDENTIFIER`).
Substituiu o provisório `com.example.senicare`, que a Play Store não aceita.
**Não pode mudar depois da primeira publicação.** Se a instituição tiver um
domínio próprio, troque antes de publicar (em `android/app/build.gradle.kts`
e no projeto do Xcode).

## 2. Assinatura de release (Android)

1. Gere a chave (uma única vez — guarde o arquivo e as senhas em local
   seguro; perder a chave impede atualizar o app):

   ```bash
   keytool -genkey -v -keystore senicare-release.jks -keyalg RSA -keysize 2048 -validity 10000 -alias senicare
   ```

2. Crie `android/key.properties` (já está no `.gitignore` — nunca envie ao
   GitHub):

   ```properties
   storeFile=C:/caminho/para/senicare-release.jks
   storePassword=...
   keyAlias=senicare
   keyPassword=...
   ```

3. Gere o pacote para a loja (o App Bundle já separa por arquitetura — o APK
   universal de testes tem ~60 MB, o download real fica bem menor):

   ```bash
   flutter build appbundle --release
   ```

Sem o `key.properties`, o build de release é assinado com a chave de debug —
serve para testar, não para a loja.

## 3. Permissões sensíveis e políticas da Play Store

| Permissão | Por que o app precisa | Atenção na Play Store |
|---|---|---|
| `USE_EXACT_ALARM` (Android 13+) / `SCHEDULE_EXACT_ALARM` (Android 12) | Alarme no minuto exato | `USE_EXACT_ALARM` só é aceita para apps cuja função principal é alarme/lembrete — é o caso; declarar no formulário de permissões. |
| `USE_FULL_SCREEN_INTENT` | Alarme em tela cheia sobre o bloqueio | Desde 2024 a Play concede automaticamente só a apps de alarme e chamadas; justificar como app de alarme de medicamentos. O app funciona sem ela (cai para notificação de alta prioridade) e o painel "Saúde do alarme" orienta o usuário. |
| `SYSTEM_ALERT_WINDOW` | Abrir o alarme sobre outros apps | Opcional: o usuário concede manualmente em Ajustes. Pode ser removida se a revisão questionar. |
| `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` | Evitar que fabricantes atrasem os alarmes | Permitida para apps cuja função principal seria prejudicada (alarme de saúde); justificar no formulário. |
| `POST_NOTIFICATIONS` | Mostrar lembretes | Pedida na primeira abertura. |

**Segurança dos dados (formulário "Data safety")**: o app não coleta nem
compartilha dados — tudo fica no aparelho; o compartilhamento (lista de
remédios, relatório) é iniciado pelo usuário pelo menu do sistema.

## 4. iOS

O código já trata o iOS (inicialização Darwin, pedido de permissão,
notificações *time-sensitive* e o limite de 64 notificações pendentes). Para
publicar:

1. Num Mac com Xcode, abra `ios/Runner.xcworkspace`, escolha o time de
   desenvolvimento e confirme o bundle `br.com.senicare`.
2. Ative a capability **Time Sensitive Notifications**.
3. Ative **Background Modes > Background fetch** se quiser a sincronização
   periódica (o WorkManager do Android tem equivalente no
   `BGTaskScheduler`).
4. Não existe alarme em tela cheia nem overlay no iOS: o alarme é uma
   notificação de alta prioridade com som; os botões Tomei/Adiar funcionam
   como ações da notificação.
5. Alertas *críticos* (que tocam mesmo no silencioso) exigem autorização
   especial da Apple (entitlement `com.apple.developer.usernotifications.critical-alerts`),
   concedida a apps de saúde mediante solicitação.

## 5. Ícone e splash

Gerados a partir de `assets/branding/` (o "S" caligráfico da fonte Great
Vibes sobre o azul da marca):

```bash
python tool/gerar_logo.py
dart run flutter_launcher_icons
dart run flutter_native_splash:create
```
