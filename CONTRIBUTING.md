# Guía de Contribución

¡Gracias por tu interés en contribuir a POS ANDROID! 🎉

## Cómo Contribuir

### 1. Fork del Proyecto

Haz un fork del repositorio y clónalo localmente:

```bash
git clone https://github.com/tu-usuario/pos_android.git
cd pos_android
```

### 2. Crear una Rama

Crea una rama para tu feature o bugfix:

```bash
git checkout -b feature/nueva-funcionalidad
# o
git checkout -b fix/correccion-bug
```

### 3. Hacer Cambios

- Escribe código limpio y bien documentado
- Sigue las convenciones de código de Dart/Flutter
- Asegúrate de que el código compile sin errores
- Prueba tus cambios en diferentes dispositivos

### 4. Commit

Usa mensajes de commit descriptivos:

```bash
git add .
git commit -m "feat: agregar funcionalidad de reportes"
# o
git commit -m "fix: corregir error en cálculo de totales"
```

### Convención de Commits

- `feat:` Nueva funcionalidad
- `fix:` Corrección de bug
- `docs:` Cambios en documentación
- `style:` Cambios de formato (no afectan el código)
- `refactor:` Refactorización de código
- `test:` Agregar o modificar tests
- `chore:` Tareas de mantenimiento

### 5. Push y Pull Request

```bash
git push origin feature/nueva-funcionalidad
```

Luego crea un Pull Request en GitHub con:
- Descripción clara de los cambios
- Screenshots si aplica
- Referencias a issues relacionados

## Estándares de Código

### Dart/Flutter

- Usa `dart format` antes de hacer commit
- Sigue las [Effective Dart Guidelines](https://dart.dev/guides/language/effective-dart)
- Usa nombres descriptivos para variables y funciones
- Comenta código complejo
- Evita código duplicado

### Estructura de Archivos

```
lib/
├── core/           # Utilidades, temas, constantes
├── data/           # Modelos, repositorios
├── presentation/   # UI (screens, widgets)
└── main.dart
```

### Widgets

- Crea widgets reutilizables cuando sea posible
- Usa `const` constructors cuando sea posible
- Mantén los widgets pequeños y enfocados
- Separa lógica de UI

### Responsive Design

- Usa `ResponsiveHelper` para tamaños
- No uses valores fijos (ej: `width: 200`)
- Prueba en diferentes tamaños de pantalla
- Mantén tamaños táctiles mínimos de 56dp

## Testing

Antes de hacer un PR, asegúrate de:

```bash
# Ejecutar tests
flutter test

# Verificar formato
dart format --set-exit-if-changed .

# Analizar código
flutter analyze
```

## Reportar Bugs

Usa el template de issues para reportar bugs:

- Descripción clara del problema
- Pasos para reproducir
- Comportamiento esperado vs actual
- Screenshots si aplica
- Versión de Flutter y dispositivo

## Solicitar Features

Para solicitar nuevas funcionalidades:

- Describe el problema que resuelve
- Propón una solución
- Considera alternativas
- Impacto en usuarios existentes

## Código de Conducta

- Sé respetuoso y profesional
- Acepta críticas constructivas
- Enfócate en lo mejor para el proyecto
- Ayuda a otros contribuidores

## Preguntas

Si tienes preguntas, abre un issue con la etiqueta `question`.

¡Gracias por contribuir! 🚀
