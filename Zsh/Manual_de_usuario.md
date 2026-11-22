# MarkitdownRecursive — Manual de usuario de Zsh

[![Shell](https://img.shields.io/badge/Shell-Zsh-4EAA25?style=flat-square)](https://www.zsh.org/)
[![Python](https://img.shields.io/badge/Python-3.10--3.14-3776AB?style=flat-square)](https://www.python.org/)
[![Descarga](https://img.shields.io/badge/Descarga-Un%20solo%20archivo-blue?style=flat-square)](https://github.com/LionnyRdguez/markitdown-recursive/releases/latest/download/MarkitdownRecursive.zsh)

**Instala las dependencias, descarga un archivo y ejecuta el script.**

No necesitas clonar el repositorio, instalar Git ni descargar el proyecto completo. Solo necesitas el script independiente y sus dependencias externas.

---

## Primeros pasos

1. Instala las dependencias del sistema operativo que utilizas.
2. Instala Python y MarkItDown.
3. Descarga `MarkitdownRecursive.zsh` en `~/scripts/`.
4. Ejecuta el script sobre una carpeta.

> **Entorno recomendado:** Ubuntu en WSL2 o una distribución Linux nativa con GNU Findutils y GNU Coreutils. También se incluyen instrucciones para macOS.

## 1. Instalar las dependencias del sistema

Selecciona las instrucciones correspondientes a tu sistema operativo.

<details>
<summary><strong>Windows — WSL2 con Ubuntu (recomendado)</strong></summary>

### Paso 1 — Instalar WSL2

Abre PowerShell como administrador:

```powershell
wsl --install
```

Reinicia Windows si se solicita. Abre Ubuntu desde el menú Inicio y completa la configuración inicial.

Si WSL ya está instalado, comprueba la distribución y la versión de WSL:

```powershell
wsl --list --verbose
```

Asegúrate de que Ubuntu utilice la versión 2 de WSL.

### Paso 2 — Instalar los paquetes

En la terminal de Ubuntu:

```bash
sudo apt update

sudo apt install -y \
    zsh \
    findutils \
    coreutils \
    python3 \
    python3-venv \
    curl
```

### Paso 3 — Comprobar Python

```bash
python3 --version
```

MarkItDown admite actualmente Python **desde la versión 3.10 hasta la 3.14**. Python 3.15 no es compatible. Si la versión de Python predeterminada de Ubuntu está fuera del rango admitido, instala una versión compatible antes de continuar.

Continúa en [Instalar Python y MarkItDown](#2-instalar-python-y-markitdown).

[Microsoft: Instalar WSL](https://learn.microsoft.com/windows/wsl/install/)

</details>

<details>
<summary><strong>Linux — Ubuntu / Debian</strong></summary>

```bash
sudo apt update

sudo apt install -y \
    zsh \
    findutils \
    coreutils \
    python3 \
    python3-venv \
    curl
```

Comprueba la versión de Python:

```bash
python3 --version
```

Debe ser **Python 3.10–3.14**. La versión actual de MarkItDown no admite Python 3.15.

</details>

<details>
<summary><strong>Linux — Fedora</strong></summary>

```bash
sudo dnf install -y \
    zsh \
    findutils \
    coreutils \
    python3 \
    curl
```

Comprueba la versión de Python del sistema:

```bash
python3 --version
```

Si muestra Python **3.10–3.14**, puedes utilizar `python3` en las instrucciones para crear el entorno virtual que aparecen más adelante.

**Usuarios de Fedora 45:** Fedora 45 utiliza Python 3.15 como versión predeterminada de `python3`, que está fuera del rango admitido por MarkItDown. Instala el intérprete compatible Python 3.14:

```bash
sudo dnf install -y python3.14
python3.14 --version
```

Utiliza `python3.14` al crear el entorno virtual. No cambies el comando `python3` de todo el sistema.

Para más información, consulta el [paquete Python 3.14 de Fedora](https://packages.fedoraproject.org/pkgs/python3.14/python3.14/) y el [paquete Python 3.15 de Fedora 45](https://packages.fedoraproject.org/pkgs/python3.15/python3/).

</details>

<details>
<summary><strong>Linux — Arch Linux</strong></summary>

```bash
sudo pacman -Syu --needed \
    zsh \
    findutils \
    coreutils \
    python \
    python-pip \
    curl
```

Comprueba que Python sea compatible:

```bash
python --version
```

Debe ser **Python 3.10–3.14**. La versión actual de MarkItDown no admite Python 3.15.

</details>

<details>
<summary><strong>macOS — Homebrew</strong></summary>

### Paso 1 — Instalar Homebrew

Si no tienes Homebrew instalado, sigue sus instrucciones oficiales: [brew.sh](https://brew.sh/).

### Paso 2 — Instalar Python y las utilidades GNU

```bash
brew update

brew install \
    zsh \
    python@3.14 \
    findutils \
    coreutils
```

### Paso 3 — Dar prioridad a las utilidades GNU en PATH

macOS incluye versiones BSD de algunos comandos. MarkitdownRecursive necesita las versiones GNU de `find`, `sort`, `mv` y otras utilidades.

Añade los directorios de comandos GNU de Homebrew a la configuración de Zsh:

```bash
echo 'export PATH="$(brew --prefix findutils)/libexec/gnubin:$(brew --prefix coreutils)/libexec/gnubin:$PATH"' >> "$HOME/.zshrc"
```

Vuelve a cargar la configuración:

```bash
source "$HOME/.zshrc"
```

Si ejecutas el script desde Bash u otro intérprete de comandos, asegúrate de que los mismos directorios GNU también estén en su `PATH`. El script hereda el entorno del intérprete desde el que se inicia.

### Paso 4 — Verificar las utilidades GNU

```bash
find --version
sort --version
mv --version
```

Deben indicar que son implementaciones GNU.

Referencias: [Homebrew Findutils](https://formulae.brew.sh/formula/findutils) · [Homebrew Coreutils](https://formulae.brew.sh/formula/coreutils).

</details>

### Características necesarias de las utilidades

El script utiliza opciones específicas de GNU:

| Comando | Opciones necesarias |
|---|---|
| `find` | `-samefile`, `-print0` |
| `sort` | `-z` |
| `mv` | `-nT` |

El script comprueba al iniciarse que `sort -z` esté disponible. También puedes comprobarlo manualmente con:

```bash
sort -z </dev/null
```

En macOS, verifica que `find`, `sort` y `mv` correspondan a las versiones GNU y no a las versiones BSD predeterminadas.

## 2. Instalar Python y MarkItDown

MarkItDown proporciona el comando `markitdown` que utiliza el script. Los metadatos actuales del paquete requieren **Python >=3.10 y <3.15** (Python 3.10–3.14). Se recomienda utilizar un entorno virtual para mantener sus dependencias separadas de los paquetes de Python del sistema.

### Paso 1 — Crear un entorno virtual

En WSL2, Ubuntu/Debian y las distribuciones Linux cuya versión predeterminada de `python3` esté dentro del rango admitido, utiliza:

```bash
mkdir -p "$HOME/.venvs"
python3 -m venv "$HOME/.venvs/markitdown-recursive"
```

En Fedora 45, utiliza el intérprete Python 3.14 compatible que instalaste en la sección anterior:

```bash
mkdir -p "$HOME/.venvs"
python3.14 -m venv "$HOME/.venvs/markitdown-recursive"
```

En otras versiones de Fedora, utiliza `python3` solo si su versión está dentro del rango admitido:

```bash
mkdir -p "$HOME/.venvs"
python3 -m venv "$HOME/.venvs/markitdown-recursive"
```

En macOS con Python 3.14 instalado mediante Homebrew:

```bash
mkdir -p "$HOME/.venvs"
python3.14 -m venv "$HOME/.venvs/markitdown-recursive"
```

### Paso 2 — Activar el entorno

```bash
source "$HOME/.venvs/markitdown-recursive/bin/activate"
```

### Paso 3 — Instalar MarkItDown

Para obtener la mayor compatibilidad posible con los formatos disponibles:

```bash
python -m pip install --upgrade pip
python -m pip install 'markitdown[all]'
```

También puedes instalar únicamente las dependencias opcionales de los formatos que necesites. Por ejemplo:

```bash
python -m pip install 'markitdown[pdf,docx,pptx,xlsx,xls]'
```

Los extras disponibles y los formatos compatibles pueden cambiar. Consulta la [documentación oficial de MarkItDown](https://github.com/microsoft/markitdown) antes de elegir un conjunto más reducido.

### Paso 4 — Verificar la instalación

```bash
python --version
command -v markitdown
markitdown --help
```

Los tres comandos deben funcionar. Mantén activo el entorno virtual cada vez que utilices el script. Cuando abras una terminal nueva, vuelve a activarlo:

```bash
source "$HOME/.venvs/markitdown-recursive/bin/activate"
```

Para salir del entorno:

```bash
deactivate
```

## 3. Descargar el script

Solo necesitas este archivo:

`MarkitdownRecursive.zsh`

Crea una carpeta `scripts` en tu directorio personal:

```bash
mkdir -p "$HOME/scripts"
```

### Opción A — Descargar desde el navegador

[**⬇️ Descargar MarkitdownRecursive.zsh**](https://github.com/LionnyRdguez/markitdown-recursive/releases/latest/download/MarkitdownRecursive.zsh)

Este enlace de descarga apunta a la rama **`main`**, destinada a las versiones estables para los usuarios. Solicita el archivo como descarga en lugar de abrir la vista del código fuente.

Guarda el archivo en esta ubicación:

```text
~/scripts/MarkitdownRecursive.zsh
```

**Usuarios de WSL que descargan desde un navegador de Windows:** normalmente, el navegador guarda los archivos en la carpeta Descargas de Windows, no directamente en el directorio personal de Linux. Desde Ubuntu, copia el archivo descargado a `~/scripts/`. Por ejemplo (sustituye el nombre de la cuenta de Windows):

```bash
cp "/mnt/c/Users/<WindowsUser>/Downloads/MarkitdownRecursive.zsh" \
   "$HOME/scripts/MarkitdownRecursive.zsh"
chmod +x "$HOME/scripts/MarkitdownRecursive.zsh"
```

Si el navegador muestra una página de GitHub en lugar de descargar el archivo:

1. [Abre el script en GitHub](https://github.com/LionnyRdguez/markitdown-recursive/blob/main/Zsh/MarkitdownRecursive.zsh).
2. Utiliza **Download raw file** en la barra de herramientas del archivo.
3. Guarda el archivo descargado en tu carpeta `scripts`.

### Opción B — Descargar desde la terminal

Ejecuta:

```bash
curl -fL \
    "https://raw.githubusercontent.com/LionnyRdguez/markitdown-recursive/main/Zsh/MarkitdownRecursive.zsh" \
    -o "$HOME/scripts/MarkitdownRecursive.zsh"
```

`curl -fL` sigue las redirecciones de GitHub y falla si se produce un error HTTP; `-o` guarda el archivo en la ubicación indicada.

### Hacer que el script sea ejecutable

Ejecuta este comando independientemente del método de descarga que hayas elegido:

```bash
chmod +x "$HOME/scripts/MarkitdownRecursive.zsh"
```

La instalación debería tener esta estructura:

```text
Directorio personal
└── scripts/
    └── MarkitdownRecursive.zsh
```

Las ubicaciones habituales son:

- Linux / WSL2: `/home/tu-usuario/scripts/MarkitdownRecursive.zsh`
- macOS: `/Users/tu-usuario/scripts/MarkitdownRecursive.zsh`

> **Ya puedes ejecutar el script.**

## 4. Ejecutar el script

Asegúrate de que el entorno virtual de MarkItDown esté activo.

### Mostrar la ayuda

```bash
"$HOME/scripts/MarkitdownRecursive.zsh" --help
```

También puedes utilizar `-h`:

```bash
"$HOME/scripts/MarkitdownRecursive.zsh" -h
```

### Procesar una carpeta específica

Por ejemplo, para procesar tu carpeta Documentos:

```bash
"$HOME/scripts/MarkitdownRecursive.zsh" "$HOME/Documents"
```

O para procesar Descargas:

```bash
"$HOME/scripts/MarkitdownRecursive.zsh" "$HOME/Downloads"
```

Puedes procesar cualquier directorio existente al que tu cuenta de usuario tenga acceso. Utiliza comillas en las rutas que contengan espacios o caracteres especiales.

También puedes iniciar el archivo desde una terminal Bash: al ejecutarlo directamente, el sistema utiliza Zsh como intérprete gracias a la línea *shebang* del script (`#!/usr/bin/env zsh`). No lo ejecutes anteponiendo `bash` al nombre del archivo.

### Procesar la carpeta actual

Sitúate en la carpeta que quieras procesar:

```bash
cd "$HOME/Documents"
```

Ejecuta el script sin indicar una carpeta:

```bash
"$HOME/scripts/MarkitdownRecursive.zsh"
```

Se utilizará como origen el directorio de trabajo actual.

### Argumentos disponibles

| Argumento | Descripción |
|---|---|
| `folder` | Directorio de origen opcional. |
| `-h` | Muestra la ayuda. |
| `--help` | Muestra la ayuda. |

Solo se puede proporcionar un directorio de origen. Actualmente, el script no permite indicar un destino personalizado ni sobrescribir archivos existentes.

## 5. Opcional — Ejecutarlo sin escribir la ruta completa

Puedes añadir `~/scripts` a tu variable `PATH`. Esto te permitirá ejecutar el script por su nombre desde cualquier directorio. Añade la línea al archivo de inicio del intérprete de comandos que utilices.

**Para Zsh**, ejecuta:

```zsh
touch "$HOME/.zshrc"
grep -qxF 'export PATH="$HOME/scripts:$PATH"' "$HOME/.zshrc" || \
    printf '\nexport PATH="$HOME/scripts:$PATH"\n' >> "$HOME/.zshrc"

source "$HOME/.zshrc"
```

**Para Bash**, ejecuta:

```bash
touch "$HOME/.bashrc"
grep -qxF 'export PATH="$HOME/scripts:$PATH"' "$HOME/.bashrc" || \
    printf '\nexport PATH="$HOME/scripts:$PATH"\n' >> "$HOME/.bashrc"

source "$HOME/.bashrc"
```

Después podrás ejecutarlo así:

```bash
MarkitdownRecursive.zsh "$HOME/Documents"
```

Esta configuración solo permite localizar el archivo por su nombre; no cambia el intérprete del script, que sigue siendo Zsh. Este paso es opcional. La ruta completa utilizada en la sección 4 funciona sin modificar `PATH`.

## 6. Comprender los resultados

La carpeta de salida se crea **dentro de la carpeta de origen**. Su nombre es el nombre de la carpeta de origen seguido de ` Markdown`. Los subdirectorios visibles se reproducen añadiendo el mismo sufijo.

**Antes**

```text
Documents/
├── report.pdf
├── notes.md
└── Projects/
    └── presentation.pptx
```

**Después**

```text
Documents/
├── report.pdf
├── notes.md
├── Projects/
│   └── presentation.pptx
└── Documents Markdown/
    ├── report.md
    ├── notes.md
    └── Projects Markdown/
        └── presentation.md
```

Los archivos originales no se modifican ni se eliminan.

### Reglas de procesamiento de archivos

| Entrada de origen | Qué ocurre |
|---|---|
| Archivo regular visible que no sea Markdown | Se envía a MarkItDown para su conversión. |
| Archivo `.md` existente | Se copia byte por byte, sin convertirlo. |
| `.MD` y otras variantes de mayúsculas/minúsculas | Se copian y se normaliza su extensión a `.md`. |
| Archivo o directorio oculto | Se omite, incluido su contenido si es un directorio. |
| Enlace simbólico | Se omite; el destino no se procesa a través del enlace. |
| Entrada especial del sistema de archivos | Se omite. |
| Archivo de destino existente | Nunca se sobrescribe. |
| Colisión de nombres | Se conserva el primer resultado correcto; las colisiones posteriores se omiten. |

Solo se elimina la última extensión del nombre:

```text
report.pdf       → report.md
data.v2.xlsx     → data.v2.md
README           → README.md
```

El script envía a MarkItDown todos los archivos regulares visibles que no sean Markdown, sin filtrar por extensión. Los archivos Markdown existentes se copian directamente. La conversión efectiva depende de la versión de MarkItDown instalada y de las dependencias opcionales que hayas instalado.

### Resultados existentes y colisiones de nombres

El script nunca sobrescribe un archivo de destino existente. Esto se aplica tanto a los archivos que quedaron de ejecuciones anteriores como a las colisiones que se produzcan durante una misma ejecución.

Por ejemplo, `report.docx` y `report.pdf` tienen como destino `report.md`. Los archivos se procesan en un orden lexicográfico determinista: se conserva el primer resultado correcto y se omite el archivo posterior que tenga el mismo destino.

Si necesitas volver a generar un archivo, revisa y haz una copia de seguridad del resultado existente antes de eliminarlo o moverlo.

## 7. Códigos de salida

| Código | Significado |
|---:|---|
| `0` | El procesamiento terminó correctamente. |
| `1` | El procesamiento terminó con uno o más errores de archivo, directorio, recorrido o limpieza. |
| `2` | Los argumentos, la ruta de origen, una dependencia ausente o el directorio de salida no válido impidieron iniciar el procesamiento. |
| `130` | Interrumpido con Ctrl+C (SIGINT). |
| `143` | Terminado mediante SIGTERM. |

Un error de conversión no necesariamente detiene el procesamiento de los demás archivos. Si el código de salida no es cero, revisa el resumen final que aparece en la terminal.

## 8. Solución de problemas

<details>
<summary><strong>markitdown: command not found</strong></summary>

Activa el entorno virtual:

```bash
source "$HOME/.venvs/markitdown-recursive/bin/activate"
```

Después, comprueba:

```bash
command -v markitdown
```

</details>

<details>
<summary><strong>sort: invalid option -- z</strong></summary>

El script necesita GNU Coreutils. Instálalo y asegúrate de que la versión GNU de `sort` tenga prioridad en `PATH`. En macOS, comprueba la configuración de `gnubin` de Homebrew.

</details>

<details>
<summary><strong>find: unknown predicate -samefile</strong></summary>

El script necesita GNU Findutils. Instálalo y comprueba la versión con:

```bash
find --version
```

</details>

<details>
<summary><strong>mv does not recognize -nT</strong></summary>

El script necesita GNU Coreutils. Comprueba que `mv --version` indique GNU Coreutils y no la versión BSD de `mv`.

</details>

<details>
<summary><strong>No se pudo convertir un documento</strong></summary>

Es posible que el formato no esté admitido por la versión de MarkItDown que tienes instalada o que falten las dependencias opcionales correspondientes a ese formato. Revisa el error que aparece en la terminal y consulta la [documentación oficial de MarkItDown](https://github.com/microsoft/markitdown).

</details>

<details>
<summary><strong>Se omitió un archivo existente</strong></summary>

Es intencional: los archivos de destino existentes nunca se sobrescriben. Revisa y haz una copia de seguridad del resultado existente antes de eliminarlo o moverlo.

</details>

<details>
<summary><strong>Se rechazó el directorio de salida</strong></summary>

La carpeta de salida no puede ser un enlace simbólico ni un archivo que no sea un directorio. También se comprueban los directorios de destino anidados. Revisa la ruta indicada antes de modificarla.

</details>

## 9. Actualizar el script

Para sustituir la copia instalada por la última versión publicada en **`main`**, ejecuta:

```bash
curl -fL \
    "https://raw.githubusercontent.com/LionnyRdguez/markitdown-recursive/main/Zsh/MarkitdownRecursive.zsh" \
    -o "$HOME/scripts/MarkitdownRecursive.zsh" \
    && chmod +x "$HOME/scripts/MarkitdownRecursive.zsh"
```

La rama `main` es la fuente de descarga para los usuarios. El trabajo de desarrollo que se encuentra en `develop` no está destinado a las instalaciones habituales.

## Recursos adicionales

- [Repositorio de MarkitdownRecursive](https://github.com/LionnyRdguez/markitdown-recursive)
- [MarkItDown — instalación y formatos compatibles](https://github.com/microsoft/markitdown)
- [Microsoft — Instalar WSL](https://learn.microsoft.com/windows/wsl/install/)
- [Homebrew](https://brew.sh/)
- [GNU Findutils](https://www.gnu.org/software/findutils/)
- [GNU Coreutils](https://www.gnu.org/software/coreutils/)

**Para colaboradores:** el repositorio completo contiene el árbol de código fuente, las pruebas automatizadas, los archivos de prueba y los resultados de referencia. No necesitas nada de eso para utilizar el script independiente.
