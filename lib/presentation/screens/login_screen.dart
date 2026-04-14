import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_assets.dart';
import '../../core/theme/theme_provider.dart';
import '../../providers/user_provider.dart';
import '../../services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  // Configuración
  final _urlController = TextEditingController(text: 'https://api.ejemplo.com');
  final _tasaUSDController = TextEditingController(text: '36.50');
  final _tasaEURController = TextEditingController(text: '40.00');
  final _tasaCOPController = TextEditingController(text: '0.012');

  @override
  void initState() {
    super.initState();
    
    _loadSavedConfig();
    
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800), // Reducido de 1200 a 800
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOut), // Más rápido
      ),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.2), // Menos desplazamiento
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.2, 1.0, curve: Curves.easeOut), // Más rápido
      ),
    );

    _animationController.forward();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    
    // Precargar el logo después de que el widget esté montado
    if (AppAssets.logoPath != null) {
      precacheImage(AssetImage(AppAssets.logoPath!), context);
    }
  }

  Future<void> _loadSavedConfig() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Cargar URL guardada
      final savedUrl = prefs.getString('server_url');
      if (savedUrl != null) {
        _urlController.text = savedUrl;
      }
      
      // Cargar tasas guardadas
      final savedUSD = prefs.getDouble('tasa_usd');
      final savedEUR = prefs.getDouble('tasa_eur');
      final savedCOP = prefs.getDouble('tasa_cop');
      
      if (mounted) {
        setState(() {
          if (savedUSD != null) _tasaUSDController.text = savedUSD.toStringAsFixed(2);
          if (savedEUR != null) _tasaEURController.text = savedEUR.toStringAsFixed(2);
          if (savedCOP != null) _tasaCOPController.text = savedCOP.toStringAsFixed(4);
        });
      }
    } catch (e) {
      debugPrint('Error cargando configuración: $e');
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showConfigDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: isDark ? AppColors.darkCard : AppColors.lightCard,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Row(
                children: [
                  Icon(
                    Icons.settings,
                    color: isDark ? AppColors.darkText : AppColors.primary,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Configuración',
                    style: TextStyle(
                      color: isDark ? AppColors.darkText : AppColors.lightText,
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: MediaQuery.of(context).size.width * 0.9,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'URL del Servidor',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: isDark ? AppColors.darkText : AppColors.lightText,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _urlController,
                        decoration: InputDecoration(
                          hintText: 'https://api.ejemplo.com',
                          prefixIcon: const Icon(Icons.link, size: 20),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          filled: true,
                          fillColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
                          contentPadding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        keyboardType: TextInputType.url,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Tasas de Cambio',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: isDark ? AppColors.darkText : AppColors.lightText,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _tasaUSDController,
                        decoration: InputDecoration(
                          labelText: 'Tasa USD (Dólar)',
                          labelStyle: const TextStyle(fontSize: 13),
                          prefixIcon: const Icon(Icons.attach_money, size: 20),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          filled: true,
                          fillColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
                          contentPadding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                        ],
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _tasaEURController,
                        decoration: InputDecoration(
                          labelText: 'Tasa EUR (Euro)',
                          labelStyle: const TextStyle(fontSize: 13),
                          prefixIcon: const Icon(Icons.euro, size: 20),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          filled: true,
                          fillColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
                          contentPadding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                        ],
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _tasaCOPController,
                        decoration: InputDecoration(
                          labelText: 'Tasa COP (Peso Col.)',
                          labelStyle: const TextStyle(fontSize: 13),
                          prefixIcon: const Icon(Icons.monetization_on, size: 20),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          filled: true,
                          fillColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
                          contentPadding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,4}')),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.info.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: AppColors.info.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.info_outline,
                              color: AppColors.info,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Las tasas se cargan automáticamente al iniciar',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: Text(
                    'Cancelar',
                    style: TextStyle(
                      color: isDark ? AppColors.darkText : AppColors.lightText,
                    ),
                  ),
                ),
                ElevatedButton(
                  onPressed: () async {
                    try {
                      final prefs = await SharedPreferences.getInstance();
                      
                      // Guardar URL
                      await prefs.setString('server_url', _urlController.text.trim());
                      
                      // Guardar tasas
                      final usd = double.tryParse(_tasaUSDController.text) ?? 36.50;
                      final eur = double.tryParse(_tasaEURController.text) ?? 40.00;
                      final cop = double.tryParse(_tasaCOPController.text) ?? 0.012;
                      
                      await prefs.setDouble('tasa_usd', usd);
                      await prefs.setDouble('tasa_eur', eur);
                      await prefs.setDouble('tasa_cop', cop);
                      
                      if (context.mounted) {
                        Navigator.of(dialogContext).pop();
                        _showSnackBar('Configuración guardada exitosamente', AppColors.success);
                      }
                    } catch (e) {
                      if (context.mounted) {
                        _showSnackBar('Error al guardar: $e', AppColors.error);
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('Guardar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    _passwordController.dispose();
    _urlController.dispose();
    _tasaUSDController.dispose();
    _tasaEURController.dispose();
    _tasaCOPController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final password = _passwordController.text.trim();
      
      // Verificar usuario en la base de datos usando AuthService
      final usuario = await AuthService.instance.login('admin', password);
      
      if (usuario != null) {
        // Usuario válido - convertir a UserModel para el provider
        final demoUser = UserModel(
          userId: usuario.id.toString(),
          userName: usuario.nombre,
          userType: usuario.nivel,
        );

        if (!mounted) return;
        
        final userProvider = Provider.of<UserProvider>(context, listen: false);
        userProvider.setUser(demoUser);

        _showSnackBar('Bienvenido ${demoUser.userName}', AppColors.success);
        
        Navigator.of(context).pushReplacementNamed('/documents');
      } else {
        // Usuario o contraseña incorrectos
        if (!mounted) return;
        _showSnackBar('Usuario o contraseña incorrectos', AppColors.error);
      }
    } catch (e) {
      if (!mounted) return;
      _showSnackBar('Error al iniciar sesión: $e', AppColors.error);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final themeProvider = Provider.of<ThemeProvider>(context);
    final size = MediaQuery.of(context).size;
    final isTablet = size.width > 600;

    return Scaffold(
      resizeToAvoidBottomInset: false, // El teclado se superpone sin redimensionar
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDark
                    ? [AppColors.darkBackground, AppColors.darkCard]
                    : [Colors.blue.shade50, Colors.white],
              ),
            ),
            child: SafeArea(
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: isTablet ? 48.0 : 32.0,
                  vertical: 16.0,
                ),
                child: Column(
                  children: [
                    // Espacio para los botones flotantes
                    const SizedBox(height: 60),
                    
                    // Contenido centrado
                    Expanded(
                      child: Center(
                        child: FadeTransition(
                          opacity: _fadeAnimation,
                          child: SlideTransition(
                            position: _slideAnimation,
                            child: Container(
                              constraints: BoxConstraints(
                                maxWidth: isTablet ? 600 : 500,
                              ),
                              child: Card(
                                elevation: 12,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(24),
                                ),
                                child: Padding(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: isTablet ? 64.0 : 40.0,
                                    vertical: isTablet ? 56.0 : 40.0,
                                  ),
                                  child: Form(
                                    key: _formKey,
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        // Logo más grande
                                        if (AppAssets.logoPath != null)
                                          Image.asset(
                                            AppAssets.logoPath!,
                                            height: isTablet ? 160 : 120,
                                            fit: BoxFit.contain,
                                            cacheWidth: isTablet ? 320 : 240,
                                            errorBuilder: (context, error, stackTrace) {
                                              return Icon(
                                                Icons.image_not_supported,
                                                size: isTablet ? 160 : 120,
                                                color: Colors.grey,
                                              );
                                            },
                                          ),
                                        SizedBox(height: isTablet ? 36 : 28),

                                        // Título más grande
                                        Text(
                                          'POS ANDROID',
                                          style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                                                fontWeight: FontWeight.bold,
                                                fontSize: isTablet ? 36 : 30,
                                                color: isDark ? Colors.white : AppColors.primary,
                                              ),
                                        ),
                                        const SizedBox(height: 10),
                                        Text(
                                          'Sistema de Punto de Venta',
                                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                                fontSize: isTablet ? 18 : 16,
                                                color: Colors.grey,
                                              ),
                                        ),
                                        SizedBox(height: isTablet ? 48 : 36),

                                        // Campo de contraseña más grande
                                        TextFormField(
                                          controller: _passwordController,
                                          obscureText: _obscurePassword,
                                          style: TextStyle(fontSize: isTablet ? 18 : 16),
                                          decoration: InputDecoration(
                                            labelText: 'Contraseña',
                                            labelStyle: TextStyle(fontSize: isTablet ? 18 : 16),
                                            prefixIcon: Icon(
                                              Icons.lock_outline,
                                              size: isTablet ? 28 : 24,
                                            ),
                                            suffixIcon: IconButton(
                                              icon: Icon(
                                                _obscurePassword ? Icons.visibility_off : Icons.visibility,
                                                size: isTablet ? 28 : 24,
                                              ),
                                              onPressed: () {
                                                setState(() => _obscurePassword = !_obscurePassword);
                                              },
                                            ),
                                            border: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(16),
                                            ),
                                            contentPadding: EdgeInsets.symmetric(
                                              horizontal: isTablet ? 24 : 20,
                                              vertical: isTablet ? 20 : 16,
                                            ),
                                          ),
                                          validator: (value) {
                                            if (value == null || value.isEmpty) {
                                              return 'Contraseña requerida';
                                            }
                                            return null;
                                          },
                                        ),
                                        SizedBox(height: isTablet ? 36 : 28),

                                        // Botón de login más grande
                                        SizedBox(
                                          width: double.infinity,
                                          height: isTablet ? 64 : 56,
                                          child: ElevatedButton(
                                            onPressed: _isLoading ? null : _handleLogin,
                                            style: ElevatedButton.styleFrom(
                                              shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(16),
                                              ),
                                              elevation: 4,
                                            ),
                                            child: _isLoading
                                                ? const CircularProgressIndicator(color: Colors.white)
                                                : Text(
                                                    'Iniciar Sesión',
                                                    style: TextStyle(
                                                      fontSize: isTablet ? 20 : 18,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                          ),
                                        ),
                                            ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Botones flotantes en la parte superior
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  // Botón de configuración
                  Container(
                    decoration: BoxDecoration(
                      color: isDark 
                          ? AppColors.darkCard.withValues(alpha: 0.9)
                          : Colors.white.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: IconButton(
                      icon: Icon(
                        Icons.settings,
                        color: isDark ? AppColors.darkText : AppColors.primary,
                      ),
                      onPressed: _showConfigDialog,
                      tooltip: 'Configuración',
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Botón de cambio de tema
                  Container(
                    decoration: BoxDecoration(
                      color: isDark 
                          ? AppColors.darkCard.withValues(alpha: 0.9)
                          : Colors.white.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: IconButton(
                      icon: Icon(
                        themeProvider.themeMode == ThemeMode.dark
                            ? Icons.light_mode_rounded
                            : Icons.dark_mode_rounded,
                        color: isDark ? AppColors.darkText : AppColors.primary,
                      ),
                      onPressed: () {
                        themeProvider.toggleTheme();
                      },
                      tooltip: 'Cambiar tema',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
