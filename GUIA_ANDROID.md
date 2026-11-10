# Cómo probar Cafetería Tycoon en tu celular Android

Se hace una sola vez. Después, cada vez que quieras probar, es un solo clic.

## 1. Plantillas de exportación de Godot
1. En Godot: menú **Editor → Administrar plantillas de exportación**.
2. Pulsá **Descargar e instalar** y esperá a que termine.

## 2. Java y el SDK de Android
Godot necesita dos programas de Google y Java para armar la app:

1. Instalá **Java JDK 17** (por ejemplo, "Temurin 17" de adoptium.net).
2. Instalá **Android Studio** (developer.android.com/studio).
3. Abrí Android Studio → **More Actions → SDK Manager** y en la pestaña **SDK Tools** marcá:
   - Android SDK Platform-Tools
   - Android SDK Build-Tools
   - Android SDK Command-line Tools (latest)
   Y en **SDK Platforms**, la versión de Android más nueva. Pulsá **Apply**.
4. Copiá la ruta que aparece arriba como **Android SDK Location**.

## 3. Decirle a Godot dónde están
1. En Godot: **Editor → Configuración del Editor → Exportar → Android**.
2. **Java SDK Path**: la carpeta donde se instaló el JDK 17.
3. **Android SDK Path**: la ruta que copiaste en el paso anterior.

## 4. Configurar el proyecto
1. **Proyecto → Configuración del Proyecto → Display → Window** (activá "Avanzado"):
   - **Handheld → Orientation**: `Portrait` (vertical).
2. **Proyecto → Exportar → Añadir... → Android**.
3. En **Permisos**, marcá **Vibrate** (para que el celular vibre cuando se rompe una máquina).
4. En **Package → Unique Name** poné algo como `com.tunombre.cafeteria`.
5. Si aparece un aviso en rojo sobre el *keystore* de depuración, Godot suele crearlo solo
   la primera vez que exportás. Si no, en Configuración del Editor → Exportar → Android
   está la opción para generarlo.

## 5. Preparar el celular
1. En el celular: **Ajustes → Acerca del teléfono** y tocá **7 veces** "Número de compilación"
   (se activan las *Opciones de desarrollador*).
2. En **Ajustes → Sistema → Opciones de desarrollador**, activá **Depuración por USB**.
3. Conectá el celular a la compu con el cable USB y aceptá el cartel de "¿Permitir depuración?".

## 6. ¡Jugar!
**Opción rápida:** arriba a la derecha en Godot aparece un ícono de Android (al lado del ▶).
Pulsalo y el juego se instala y se abre solo en el celular.

**Opción con archivo:** **Proyecto → Exportar → Android → Exportar proyecto**, guardá el `.apk`,
pasalo al celular e instalalo (te va a pedir permitir "instalar apps de orígenes desconocidos").

> Para subirlo a Google Play hace falta un *keystore* de "release" y exportar en formato `.aab`.
> Eso se hace al final, cuando el juego esté listo para publicar.
