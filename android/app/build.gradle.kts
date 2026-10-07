import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Assinatura de release: lida de android/key.properties (fora do git — ver
// docs/PUBLICACAO.md). Sem o arquivo, o release é assinado com a chave de
// debug, só para testes locais; a Play Store recusa esse APK.
val propriedadesDaChave = Properties().apply {
    val arquivo = rootProject.file("key.properties")
    if (arquivo.exists()) arquivo.inputStream().use { load(it) }
}
val temChaveDeRelease = propriedadesDaChave.getProperty("storeFile") != null

android {
    namespace = "br.com.senicare"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // Identificador definitivo na Play Store (não pode mudar depois de
        // publicado). Substitui o provisório com.example.senicare.
        applicationId = "br.com.senicare"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        multiDexEnabled = true
    }

    signingConfigs {
        if (temChaveDeRelease) {
            create("release") {
                storeFile = file(propriedadesDaChave.getProperty("storeFile"))
                storePassword = propriedadesDaChave.getProperty("storePassword")
                keyAlias = propriedadesDaChave.getProperty("keyAlias")
                keyPassword = propriedadesDaChave.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName(
                if (temChaveDeRelease) "release" else "debug",
            )
            // R8 minifica/ofusca o release: sem isso, 'proguardFiles' abaixo não
            // tem efeito nenhum (o encolhimento de código só roda se isto for
            // true). É exatamente essa ofuscação que estava quebrando o Gson
            // do flutter_local_notifications (TypeToken perdia o parâmetro de
            // tipo genérico) — daí a necessidade das regras em proguard-rules.pro.
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }
}

// Bytecode Java/Kotlin fixado em 17 (o mesmo alvo do template atual do
// Flutter), independente da versão do JDK que roda o Gradle.
kotlin {
    compilerOptions {
        jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
