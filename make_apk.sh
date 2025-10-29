#!/usr/bin/env bash
set -e
set -u
# 'pipefail' puede no existir en algunos shells, lo activamos si está disponible:
(set -o pipefail) 2>/dev/null || true

# ===============================
#  Mi Novia - Builder Script
#  - Crea el proyecto Android (Compose + Room + DataStore + PIN + contador + fotos internas)
#  - Instala Java 17, Android SDK
#  - Compila APK y lo deja en ./mi_novia_app.apk
# ===============================

WORKDIR="$(pwd)"
PROJ="mi_novia_app"
SDK_DIR="$WORKDIR/android-sdk"
JDK_DIR="$WORKDIR/jdk17"
GRADLE_VER="8.2.1"
GRADLE_DIR="$WORKDIR/gradle-$GRADLE_VER"
GRADLE_BIN="$GRADLE_DIR/bin/gradle"

echo "🔧 Preparando carpetas…"
rm -rf "$PROJ" || true
mkdir -p "$PROJ"

# -----------------------------------------
# 1) ESCRIBIR ARCHIVOS DEL PROYECTO
# -----------------------------------------

echo "🗂️  Generando estructura del proyecto…"
mkdir -p "$PROJ/app/src/main/java/com/minovia/app/ui/screens"
mkdir -p "$PROJ/app/src/main/java/com/minovia/app/ui/theme"
mkdir -p "$PROJ/app/src/main/java/com/minovia/app/data"
mkdir -p "$PROJ/app/src/main/java/com/minovia/app/repo"
mkdir -p "$PROJ/app/src/main/java/com/minovia/app/util"
mkdir -p "$PROJ/app/src/main/res/values"
mkdir -p "$PROJ/app/src/main/res/mipmap-anydpi-v26"
mkdir -p "$PROJ/app/src/main/res/drawable"

# settings.gradle.kts
cat > "$PROJ/settings.gradle.kts" <<'EOF'
import org.gradle.api.initialization.resolve.RepositoriesMode

pluginManagement {
    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}
dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS)
    repositories {
        google()
        mavenCentral()
    }
}
rootProject.name = "MiNovia"
include(":app")
EOF

# build.gradle.kts (top-level)
cat > "$PROJ/build.gradle.kts" <<'EOF'
plugins {
    id("com.android.application") version "8.1.0" apply false
    id("org.jetbrains.kotlin.android") version "1.9.10" apply false
    id("org.jetbrains.kotlin.kapt") version "1.9.10" apply false
}
EOF

# app/build.gradle.kts
cat > "$PROJ/app/build.gradle.kts" <<'EOF'
plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("org.jetbrains.kotlin.kapt")
}

android {
    namespace = "com.minovia.app"
    compileSdk = 34

    defaultConfig {
        applicationId = "com.minovia.app"
        minSdk = 24
        targetSdk = 34
        versionCode = 1
        versionName = "1.0"
    }

    buildFeatures { compose = true }
    composeOptions { kotlinCompilerExtensionVersion = "1.5.3" }

    kotlinOptions { jvmTarget = "17" }
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    packaging {
        resources {
            excludes += "/META-INF/{AL2.0,LGPL2.1}"
        }
    }
}

dependencies {
    val composeBom = platform("androidx.compose:compose-bom:2024.06.00")
    implementation(composeBom)
    androidTestImplementation(composeBom)

    implementation("androidx.core:core-ktx:1.13.1")
    implementation("androidx.activity:activity-compose:1.9.2")
    implementation("androidx.compose.ui:ui")
    implementation("androidx.compose.ui:ui-tooling-preview")
    debugImplementation("androidx.compose.ui:ui-tooling")
    implementation("androidx.compose.material3:material3:1.2.1")
    implementation("androidx.lifecycle:lifecycle-runtime-ktx:2.8.6")
    implementation("androidx.lifecycle:viewmodel-compose:2.8.6")
    implementation("androidx.navigation:navigation-compose:2.8.2")

    // Room
    implementation("androidx.room:room-runtime:2.6.1")
    implementation("androidx.room:room-ktx:2.6.1")
    kapt("androidx.room:room-compiler:2.6.1")

    // DataStore
    implementation("androidx.datastore:datastore-preferences:1.1.1")

    // Coil (imágenes)
    implementation("io.coil-kt:coil-compose:2.6.0")

    // Desugaring (java.time)
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")
}
EOF

# AndroidManifest.xml
cat > "$PROJ/app/src/main/AndroidManifest.xml" <<'EOF'
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    package="com.minovia.app">

    <application
        android:allowBackup="true"
        android:label="Mi Novia"
        android:icon="@mipmap/ic_launcher"
        android:roundIcon="@mipmap/ic_launcher_round"
        android:supportsRtl="true"
        android:theme="@style/Theme.MiNovia">
        <activity android:name=".MainActivity"
            android:exported="true">
            <intent-filter>
                <action android:name="android.intent.action.MAIN" />
                <category android:name="android.intent.category.LAUNCHER" />
            </intent-filter>
        </activity>
    </application>
</manifest>
EOF

# MainActivity.kt
cat > "$PROJ/app/src/main/java/com/minovia/app/MainActivity.kt" <<'EOF'
package com.minovia.app

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.navigation.NavHostController
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController
import com.minovia.app.ui.AppVM
import com.minovia.app.ui.screens.*
import com.minovia.app.ui.theme.AppTheme

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent {
            AppTheme {
                val nav = rememberNavController()
                AppNavHost(nav)
            }
        }
    }
}

@Composable
fun AppNavHost(nav: NavHostController) {
    val vm: AppVM = viewModel()
    val profile = vm.profileState()
    val start = if (!profile.pin.isNullOrBlank()) "lock" else "home"
    NavHost(navController = nav, startDestination = start) {
        composable("lock") { EnterPinScreen(onUnlocked = {
            nav.navigate("home") { popUpTo("lock") { inclusive = true } }
        }) }
        composable("home") {
            HomeScreen(
                onAdd = { nav.navigate("edit") },
                onProfile = { nav.navigate("profile") },
                onEdit = { id -> nav.navigate("edit?id=$id") }
            )
        }
        composable("profile") { ProfileScreen(onBack = { nav.popBackStack() }) }
        composable("edit") { EditMemoryScreen(onDone = { nav.popBackStack() }) }
        composable("edit?id={id}") { back ->
            val id = back.arguments?.getString("id")?.toLongOrNull()
            EditMemoryScreen(entryId = id, onDone = { nav.popBackStack() })
        }
    }
}
EOF

# Theme.kt
cat > "$PROJ/app/src/main/java/com/minovia/app/ui/theme/Theme.kt" <<'EOF'
package com.minovia.app.ui.theme

import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.runtime.Composable

private val ColorScheme = darkColorScheme()

@Composable
fun AppTheme(content: @Composable () -> Unit) {
    MaterialTheme(colorScheme = ColorScheme, content = content)
}
EOF

# values/themes.xml
cat > "$PROJ/app/src/main/res/values/themes.xml" <<'EOF'
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <style name="Theme.MiNovia" parent="Theme.Material3.Dark.NoActionBar">
        <item name="colorPrimary">#C2185B</item>
        <item name="colorSecondary">#FF4081</item>
    </style>
</resources>
EOF

# values/strings.xml
cat > "$PROJ/app/src/main/res/values/strings.xml" <<'EOF'
<resources>
    <string name="app_name">Mi Novia</string>
</resources>
EOF

# mipmap & drawable (iconos)
cat > "$PROJ/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml" <<'EOF'
<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@color/ic_launcher_background"/>
    <foreground android:drawable="@drawable/ic_launcher_foreground"/>
</adaptive-icon>
EOF

cat > "$PROJ/app/src/main/res/mipmap-anydpi-v26/ic_launcher_round.xml" <<'EOF'
<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@color/ic_launcher_background"/>
    <foreground android:drawable="@drawable/ic_launcher_foreground"/>
</adaptive-icon>
EOF

cat > "$PROJ/app/src/main/res/values/ic_launcher_background.xml" <<'EOF'
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <color name="ic_launcher_background">#C2185B</color>
</resources>
EOF

cat > "$PROJ/app/src/main/res/drawable/ic_launcher_foreground.xml" <<'EOF'
<vector xmlns:android="http://schemas.android.com/apk/res/android"
    android:width="108dp" android:height="108dp"
    android:viewportWidth="108" android:viewportHeight="108">
    <group android:scaleX="0.45" android:scaleY="0.45" android:translateX="29.7" android:translateY="29.7">
        <path android:fillColor="#FFFFFF"
            android:pathData="M24,44c13.255,0 24,-10.745 24,-24S37.255,-4 24,-4 0,6.745 0,20s10.745,24 24,24z"/>
        <path android:fillColor="#C2185B"
            android:pathData="M24,34c-6.627,0 -12,-5.373 -12,-12S17.373,10 24,10s12,5.373 12,12 -5.373,12 -12,12z"/>
    </group>
</vector>
EOF

# data layer
cat > "$PROJ/app/src/main/java/com/minovia/app/data/Memory.kt" <<'EOF'
package com.minovia.app.data

import androidx.room.Entity
import androidx.room.PrimaryKey

@Entity(tableName = "memories")
data class Memory(
    @PrimaryKey(autoGenerate = true) val id: Long = 0,
    val dateEpoch: Long,
    val title: String,
    val note: String,
    val mood: Int,
    val photoUri: String? = null
)
EOF

cat > "$PROJ/app/src/main/java/com/minovia/app/data/MemoryDao.kt" <<'EOF'
package com.minovia.app.data

import androidx.room.*
import kotlinx.coroutines.flow.Flow

@Dao
interface MemoryDao {
    @Query("SELECT * FROM memories ORDER BY dateEpoch DESC")
    fun streamAll(): Flow<List<Memory>>

    @Query("SELECT * FROM memories WHERE id = :id")
    suspend fun getById(id: Long): Memory?

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun upsert(memory: Memory): Long

    @Delete
    suspend fun delete(memory: Memory)
}
EOF

cat > "$PROJ/app/src/main/java/com/minovia/app/data/AppDatabase.kt" <<'EOF'
package com.minovia.app.data

import android.content.Context
import androidx.room.Database
import androidx.room.Room
import androidx.room.RoomDatabase

@Database(entities = [Memory::class], version = 1, exportSchema = false)
abstract class AppDatabase : RoomDatabase() {
    abstract fun memoryDao(): MemoryDao

    companion object {
        @Volatile private var INSTANCE: AppDatabase? = null
        fun get(context: Context): AppDatabase =
            INSTANCE ?: synchronized(this) {
                INSTANCE ?: Room.databaseBuilder(
                    context.applicationContext, AppDatabase::class.java, "mi_novia.db"
                ).build().also { INSTANCE = it }
            }
    }
}
EOF

cat > "$PROJ/app/src/main/java/com/minovia/app/data/ProfileStore.kt" <<'EOF'
package com.minovia.app.data

import android.content.Context
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.remove
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.datastore.preferences.preferencesDataStore
import kotlinx.coroutines.flow.map

private val Context.dataStore by preferencesDataStore("profile")

object ProfileKeys {
    val NAME = stringPreferencesKey("name")
    val INFO = stringPreferencesKey("info")
    val PHOTO_URI = stringPreferencesKey("photo_uri")
    val IMPORTANT_DATE = stringPreferencesKey("important_date")
    val PIN = stringPreferencesKey("pin")
}

class ProfileStore(private val context: Context) {
    val data = context.dataStore.data.map { prefs ->
        ProfileData(
            name = prefs[ProfileKeys.NAME].orEmpty(),
            info = prefs[ProfileKeys.INFO].orEmpty(),
            photoUri = prefs[ProfileKeys.PHOTO_URI],
            importantDate = prefs[ProfileKeys.IMPORTANT_DATE],
            pin = prefs[ProfileKeys.PIN]
        )
    }

    suspend fun save(d: ProfileData) {
        context.dataStore.edit { prefs ->
            prefs[ProfileKeys.NAME] = d.name
            prefs[ProfileKeys.INFO] = d.info
            if (d.photoUri != null) prefs[ProfileKeys.PHOTO_URI] = d.photoUri else prefs.remove(ProfileKeys.PHOTO_URI)
            if (d.importantDate != null) prefs[ProfileKeys.IMPORTANT_DATE] = d.importantDate else prefs.remove(ProfileKeys.IMPORTANT_DATE)
            if (d.pin != null) prefs[ProfileKeys.PIN] = d.pin else prefs.remove(ProfileKeys.PIN)
        }
    }
}

data class ProfileData(
    val name: String = "",
    val info: String = "",
    val photoUri: String? = null,
    val importantDate: String? = null,
    val pin: String? = null
)
EOF

# repo & VM
cat > "$PROJ/app/src/main/java/com/minovia/app/repo/Repository.kt" <<'EOF'
package com.minovia.app.repo

import android.content.Context
import com.minovia.app.data.*
import kotlinx.coroutines.flow.Flow

class Repository(context: Context) {
    private val db = AppDatabase.get(context)
    private val dao = db.memoryDao()
    val profile = ProfileStore(context)

    fun memories(): Flow<List<Memory>> = dao.streamAll()
    suspend fun memory(id: Long) = dao.getById(id)
    suspend fun save(memory: Memory) = dao.upsert(memory)
    suspend fun delete(memory: Memory) = dao.delete(memory)
}
EOF

cat > "$PROJ/app/src/main/java/com/minovia/app/ui/VMS.kt" <<'EOF'
package com.minovia.app.ui

import android.app.Application
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import com.minovia.app.data.Memory
import com.minovia.app.data.ProfileData
import com.minovia.app.repo.Repository
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch

class AppVM(app: Application) : AndroidViewModel(app) {
    private val repo = Repository(app)

    val memories = repo.memories().stateIn(viewModelScope, SharingStarted.Lazily, emptyList())
    val profile = repo.profile.data.stateIn(viewModelScope, SharingStarted.Lazily, ProfileData())

    fun profileState(): ProfileData = profile.value

    fun saveMemory(m: Memory) = viewModelScope.launch { repo.save(m) }
    fun deleteMemory(m: Memory) = viewModelScope.launch { repo.delete(m) }
    fun saveProfile(p: ProfileData) = viewModelScope.launch { repo.profile.save(p) }
}
EOF

# util (copiar imágenes a almacenamiento interno)
cat > "$PROJ/app/src/main/java/com/minovia/app/util/FileUtil.kt" <<'EOF'
package com.minovia.app.util

import android.content.ContentResolver
import android.content.Context
import android.net.Uri
import java.io.File
import java.io.FileOutputStream
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

object FileUtil {
    fun copyIntoApp(context: Context, uri: Uri, prefix: String): String? {
        return try {
            val resolver: ContentResolver = context.contentResolver
            resolver.openInputStream(uri)?.use { input ->
                val dir = File(context.filesDir, "images")
                if (!dir.exists()) dir.mkdirs()
                val name = "${prefix}_" + SimpleDateFormat("yyyyMMdd_HHmmss", Locale.US).format(Date()) + ".jpg"
                val outFile = File(dir, name)
                FileOutputStream(outFile).use { output -> input.copyTo(output) }
                outFile.absolutePath
            }
        } catch (e: Exception) {
            e.printStackTrace()
            null
        }
    }
}
EOF

# UI: Home con contador humanizado
cat > "$PROJ/app/src/main/java/com/minovia/app/ui/screens/HomeScreen.kt" <<'EOF'
package com.minovia.app.ui.screens

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.lifecycle.viewmodel.compose.viewModel
import com.minovia.app.data.Memory
import com.minovia.app.ui.AppVM
import java.text.SimpleDateFormat
import java.time.LocalDate
import java.time.Period
import java.time.temporal.ChronoUnit
import java.util.*

@Composable
fun HomeScreen(onAdd: () -> Unit, onProfile: () -> Unit, onEdit: (Long) -> Unit, vm: AppVM = viewModel()) {
    val memories = vm.memories.collectAsState().value
    Scaffold(
        topBar = {
            TopAppBar(title = {
                val prof = vm.profile.collectAsState().value
                val titleText = run {
                    val d = prof.importantDate
                    if (!d.isNullOrBlank()) try {
                        val start = LocalDate.parse(d) // yyyy-MM-dd
                        val today = LocalDate.now()
                        val totalDays = ChronoUnit.DAYS.between(start, today).toInt().coerceAtLeast(0)
                        val p: Period = Period.between(start, today)
                        val years = p.years
                        val months = p.months
                        val days = p.days
                        val detail = when {
                            years > 0 -> {
                                val y = "$years " + if (years==1) "año" else "años"
                                val m = "$months " + if (months==1) "mes" else "meses"
                                val d2 = "$days " + if (days==1) "día" else "días"
                                " ($y, $m y $d2.)"
                            }
                            months > 0 -> {
                                val m = "$months " + if (months==1) "mes" else "meses"
                                val d2 = "$days " + if (days==1) "día" else "días"
                                " ($m y $d2.)"
                            }
                            else -> ""
                        }
                        if (detail.isNotEmpty()) "$totalDays días juntos$detail" else "$totalDays días juntos"
                    } catch (e: Exception) { "Mi Novia" } else "Mi Novia"
                }
                Text(titleText)
            }, actions = {
                TextButton(onClick = onProfile) { Text("Perfil") }
            })
        },
        floatingActionButton = {
            FloatingActionButton(onClick = onAdd) { Text("+") }
        }
    ) { padding ->
        if (memories.isEmpty()) {
            Box(Modifier.fillMaxSize().padding(padding), contentAlignment = Alignment.Center) {
                Text("Sin recuerdos aún. Toca + para agregar.")
            }
        } else {
            LazyColumn(Modifier.fillMaxSize().padding(padding)) {
                items(memories) { m -> MemoryRow(m, onClick = { onEdit(m.id) }) }
            }
        }
    }
}

@Composable
private fun MemoryRow(m: Memory, onClick: () -> Unit) {
    val df = SimpleDateFormat("yyyy-MM-dd", Locale.getDefault())
    ElevatedCard(
        Modifier.fillMaxWidth().padding(12.dp).clickable { onClick() }
    ) {
        Column(Modifier.padding(16.dp)) {
            Text(df.format(Date(m.dateEpoch)), style = MaterialTheme.typography.labelMedium)
            Spacer(Modifier.height(4.dp))
            Text(m.title, style = MaterialTheme.typography.titleMedium, maxLines = 1, overflow = TextOverflow.Ellipsis)
            if (m.note.isNotBlank()) {
                Spacer(Modifier.height(4.dp))
                Text(m.note, maxLines = 2, overflow = TextOverflow.Ellipsis)
            }
        }
    }
}
EOF

# UI: Perfil con PIN y foto interna
cat > "$PROJ/app/src/main/java/com/minovia/app/ui/screens/ProfileScreen.kt" <<'EOF'
package com.minovia.app.ui.screens

import android.net.Uri
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.Image
import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.text.input.TextFieldValue
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.unit.dp
import androidx.lifecycle.viewmodel.compose.viewModel
import coil.compose.rememberAsyncImagePainter
import com.minovia.app.data.ProfileData
import com.minovia.app.ui.AppVM

@Composable
fun ProfileScreen(onBack: () -> Unit, vm: AppVM = viewModel()) {
    val context = androidx.compose.ui.platform.LocalContext.current
    val profile = vm.profile.collectAsState().value
    var name by remember { mutableStateOf(TextFieldValue(profile.name)) }
    var info by remember { mutableStateOf(TextFieldValue(profile.info)) }
    var date by remember { mutableStateOf(TextFieldValue(profile.importantDate ?: "")) }
    var photo by remember { mutableStateOf(profile.photoUri?.let(Uri::parse)) }
    var pin by remember { mutableStateOf(TextFieldValue(profile.pin ?: "")) }

    val picker = rememberLauncherForActivityResult(ActivityResultContracts.GetContent()) { uri ->
        if (uri != null) {
            val path = com.minovia.app.util.FileUtil.copyIntoApp(context, uri, "profile")
            if (path != null) photo = Uri.parse("file://$path")
        }
    }

    Scaffold(topBar = {
        TopAppBar(title = { Text("Perfil") }, navigationIcon = {
            TextButton(onClick = onBack) { Text("Atrás") }
        })
    }) { padding ->
        Column(Modifier.fillMaxSize().padding(padding).padding(16.dp), horizontalAlignment = Alignment.CenterHorizontally) {

            if (photo != null) {
                Image(painter = rememberAsyncImagePainter(photo), contentDescription = null, modifier = Modifier.size(128.dp), contentScale = ContentScale.Crop)
            } else {
                Box(Modifier.size(128.dp), contentAlignment = Alignment.Center) { Text("Sin foto") }
            }
            Spacer(Modifier.height(8.dp))
            Button(onClick = { picker.launch("image/*") }) { Text("Cambiar foto") }

            Spacer(Modifier.height(16.dp))
            OutlinedTextField(value = name, onValueChange = { name = it }, label = { Text("Nombre") }, modifier = Modifier.fillMaxWidth())
            Spacer(Modifier.height(8.dp))
            OutlinedTextField(value = date, onValueChange = { date = it }, label = { Text("Fecha importante (yyyy-MM-dd)") }, modifier = Modifier.fillMaxWidth())
            Spacer(Modifier.height(8.dp))
            OutlinedTextField(value = info, onValueChange = { info = it }, label = { Text("Información / notas") }, modifier = Modifier.fillMaxWidth(), minLines = 3)

            Spacer(Modifier.height(16.dp))
            OutlinedTextField(
                value = pin, onValueChange = { if (it.text.length <= 6) pin = TextFieldValue(it.text.filter(Char::isDigit)) },
                label = { Text("PIN (3–6 dígitos)") }, modifier = Modifier.fillMaxWidth(),
                visualTransformation = PasswordVisualTransformation(),
                keyboardOptions = androidx.compose.ui.text.input.KeyboardOptions(keyboardType = androidx.compose.ui.text.input.KeyboardType.NumberPassword)
            )
            Text("Si configuras un PIN, la app lo pedirá al abrir.", style = MaterialTheme.typography.labelSmall)

            Spacer(Modifier.height(16.dp))
            Button(onClick = {
                vm.saveProfile(ProfileData(name.text, info.text, photo?.toString(), date.text.ifBlank { null }, pin.text.ifBlank { null }))
                onBack()
            }, modifier = Modifier.fillMaxWidth()) { Text("Guardar") }
        }
    }
}
EOF

# UI: Lock (PIN)
cat > "$PROJ/app/src/main/java/com/minovia/app/ui/screens/LockScreens.kt" <<'EOF'
package com.minovia.app.ui.screens

import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.unit.dp
import androidx.lifecycle.viewmodel.compose.viewModel
import com.minovia.app.ui.AppVM

@Composable
fun EnterPinScreen(onUnlocked: () -> Unit, vm: AppVM = viewModel()) {
    val profile = vm.profile.collectAsState().value
    var pin by remember { mutableStateOf("") }
    var error by remember { mutableStateOf<String?>(null) }

    Scaffold(topBar = { TopAppBar(title = { Text("Bloqueado") }) }) { padding ->
        Column(Modifier.fillMaxSize().padding(padding).padding(16.dp)) {
            Text("Introduce tu PIN para entrar", style = MaterialTheme.typography.bodyLarge)
            Spacer(Modifier.height(12.dp))
            OutlinedTextField(
                value = pin, onValueChange = { if (it.length <= 6) pin = it.filter(Char::isDigit) },
                label = { Text("PIN (3–6 dígitos)") },
                visualTransformation = PasswordVisualTransformation(),
                keyboardOptions = androidx.compose.ui.text.input.KeyboardOptions(keyboardType = KeyboardType.NumberPassword),
                modifier = Modifier.fillMaxWidth()
            )
            if (error != null) { Spacer(Modifier.height(8.dp)); Text(error!!, color = MaterialTheme.colorScheme.error) }
            Spacer(Modifier.height(16.dp))
            Button(onClick = {
                if (pin.length in 3..6 && pin == (profile.pin ?: "")) onUnlocked() else error = "PIN incorrecto"
            }, modifier = Modifier.fillMaxWidth()) { Text("Desbloquear") }
        }
    }
}
EOF

# README
cat > "$PROJ/README.txt" <<'EOF'
Mi Novia — App nativa Android (Jetpack Compose)
-----------------------------------------------
- Home (lista de recuerdos) con Room
- Perfil (nombre, fecha importante, info, foto) con DataStore
- Nuevo recuerdo con título, nota, ánimo y foto
- PIN de bloqueo (3–6 dígitos)
- Contador de días humanizado
- Fotos copiadas a almacenamiento interno de la app
- Material 3 (oscuro)
EOF

# -----------------------------------------
# 2) INSTALAR JDK 17, ANDROID SDK, GRADLE
# -----------------------------------------

echo "☕ Comprobando Java 17…"
if ! java -version 2>&1 | grep -q 'version "17'; then
  echo "Instalando Temurin OpenJDK 17…"
  mkdir -p "$JDK_DIR"
  cd "$JDK_DIR"
  curl -L -o jdk17.tar.gz "https://github.com/adoptium/temurin17-binaries/releases/download/jdk-17.0.12%2B7/OpenJDK17U-jdk_x64_linux_hotspot_17.0.12_7.tar.gz"
  tar -xzf jdk17.tar.gz --strip-components=1
  export JAVA_HOME="$JDK_DIR"
  export PATH="$JAVA_HOME/bin:$PATH"
  java -version
else
  echo "Java 17 detectado."
fi

echo "📦 Instalando Gradle $GRADLE_VER…"
if [ ! -x "$GRADLE_BIN" ]; then
  cd "$WORKDIR"
  curl -L -o gradle.zip "https://services.gradle.org/distributions/gradle-$GRADLE_VER-bin.zip"
  rm -rf "$GRADLE_DIR" || true
  mkdir -p "$GRADLE_DIR"
  unzip -q gradle.zip -d "$WORKDIR"
  rm -f gradle.zip
fi
export PATH="$GRADLE_DIR/bin:$PATH"
gradle -v

echo "📱 Instalando Android SDK cmdline-tools…"
export ANDROID_HOME="$SDK_DIR"
export ANDROID_SDK_ROOT="$SDK_DIR"
mkdir -p "$SDK_DIR"
cd "$SDK_DIR"
CMD_TOOLS_ZIP="commandlinetools-linux-11076708_latest.zip"
if [ ! -f "$CMD_TOOLS_ZIP" ]; then
  curl -L -o "$CMD_TOOLS_ZIP" "https://dl.google.com/android/repository/$CMD_TOOLS_ZIP"
fi
rm -rf cmdline-tools || true
mkdir -p cmdline-tools
unzip -q "$CMD_TOOLS_ZIP" -d cmdline-tools
mkdir -p cmdline-tools/latest
mv cmdline-tools/cmdline-tools/* cmdline-tools/latest/ 2>/dev/null || true
export PATH="$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:$PATH"

echo "📄 Aceptando licencias…"
yes | sdkmanager --licenses >/dev/null

echo "⬇️ Instalando plataformas/build-tools…"
sdkmanager "platform-tools" "platforms;android-34" "build-tools;34.0.0" >/dev/null

# -----------------------------------------
# 3) COMPILAR APK
# -----------------------------------------
echo "🏗️ Compilando APK…"
cd "$WORKDIR/$PROJ"
gradle --no-daemon assembleDebug

APK_PATH="app/build/outputs/apk/debug/app-debug.apk"
if [ ! -f "$APK_PATH" ]; then
  echo "❌ No se generó el APK. Revisa los logs."
  exit 1
fi

cp "$APK_PATH" "$WORKDIR/mi_novia_app.apk"
echo "✅ ¡Listo! APK en: $WORKDIR/mi_novia_app.apk"
echo "Descárgalo desde los Artifacts del workflow."


