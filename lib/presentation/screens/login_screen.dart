import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
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
  bool _rememberMe = false;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  // Configuración
  final _urlController = TextEditingController(text: 'https://api.ejemplo.com');
  final _tasaUSDController = TextEditingController(text: '36.50');
  final _tasaEURController = TextEditingController(text: '40.00');
  final _tasaCOPController = TextEditingController(text: '0.012');
  
  // URLs para obtener tasas de cambio
  static const String apiTasasUrlUSD = 'https://api.exchangerate-api.com/v4/latest/USD';
  static const String apiTasasUrlEUR = 'https://api.exchangerate-api.com/v4/latest/EUR';
  static const String apiTasasUrlCOP = 'https://api.exchangerate-api.com/v4/latest/COP';

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

  Future<void> _updateRatesFromAPI() async {
    try {
      final tasas = await _obtenerTodasLasTasas();
      
      if (mounted) {
        setState(() {
          if (tasas['USD'] != null) {
            _tasaUSDController.text = tasas['USD']!.toStringAsFixed(2);
          }
          if (tasas['EUR'] != null) {
            _tasaEURController.text = tasas['EUR']!.toStringAsFixed(2);
          }
          if (tasas['COP'] != null) {
            _tasaCOPController.text = tasas['COP']!.toStringAsFixed(4);
          }
        });
        
        _showSnackBar('Tasas actualizadas desde API', AppColors.success);
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('Error al actualizar tasas: $e', AppColors.error);
      }
    }
  }

  Future<Map<String, double>> _obtenerTodasLasTasas() async {
    final tasas = <String, double>{};
    
    try {
      // 1. Obtener tasa USD a VES
      final responseUSD = await http.get(Uri.parse(apiTasasUrlUSD)).timeout(const Duration(seconds: 10));
      if (responseUSD.statusCode == 200) {
        final dataUSD = jsonDecode(responseUSD.body);
        final tasaUsdVes = (dataUSD['rates']['VES'] as num?)?.toDouble() ?? 0.0;
        if (tasaUsdVes > 0) {
          tasas['USD'] = tasaUsdVes;
        }
      }
      
      // 2. Obtener tasa EUR a VES
      final responseEUR = await http.get(Uri.parse(apiTasasUrlEUR)).timeout(const Duration(seconds: 10));
      if (responseEUR.statusCode == 200) {
        final dataEUR = jsonDecode(responseEUR.body);
        final tasaEurVes = (dataEUR['rates']['VES'] as num?)?.toDouble() ?? 0.0;
        if (tasaEurVes > 0) {
          tasas['EUR'] = tasaEurVes;
        }
      }
      
      // 3. Obtener tasa COP a VES
      final responseCOP = await http.get(Uri.parse(apiTasasUrlCOP)).timeout(const Duration(seconds: 10));
      if (responseCOP.statusCode == 200) {
        final dataCOP = jsonDecode(responseCOP.body);
        final tasaCopVes = (dataCOP['rates']['VES'] as num?)?.toDouble() ?? 0.0;
        if (tasaCopVes > 0) {
          tasas['COP'] = tasaCopVes;
        }
      }
    } catch (e) {
      debugPrint('Error obteniendo tasas: $e');
    }
    
    return tasas;
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
    bool isUpdatingRates = false;
    
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
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'URL del Servidor',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: isDark ? AppColors.darkText : AppColors.lightText,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _urlController,
                      decoration: InputDecoration(
                        hintText: 'https://api.ejemplo.com',
                        prefixIcon: const Icon(Icons.link),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        filled: true,
                        fillColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
                      ),
                      keyboardType: TextInputType.url,
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Tasas de Cambio',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: isDark ? AppColors.darkText : AppColors.lightText,
                          ),
                        ),
                        TextButton.icon(
                          onPressed: isUpdatingRates ? null : () async {
                            setDialogState(() => isUpdatingRates = true);
                            await _updateRatesFromAPI();
                            setDialogState(() => isUpdatingRates = false);
                          },
                          icon: isUpdatingRates
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.refresh, size: 18),
                          label: Text(
                            isUpdatingRates ? 'Actualizando...' : 'Actualizar',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _tasaUSDController,
                      decoration: InputDecoration(
                        labelText: 'Tasa USD (Dólar)',
                        prefixIcon: const Icon(Icons.attach_money),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        filled: true,
                        fillColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _tasaEURController,
                      decoration: InputDecoration(
                        labelText: 'Tasa EUR (Euro)',
                        prefixIcon: const Icon(Icons.euro),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        filled: true,
                        fillColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _tasaCOPController,
                      decoration: InputDecoration(
                        labelText: 'Tasa COP (Peso Colombiano)',
                        prefixIcon: const Icon(Icons.monetization_on),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        filled: true,
                        fillColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,4}')),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
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
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Los cambios se guardarán localmente y se usarán en los cálculos',
                              style: TextStyle(
                                fontSize: 12,
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
              child: Center(
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(isTablet ? 48.0 : 24.0),
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: SlideTransition(
                      position: _slideAnimation,
                      child: Container(
                        constraints: BoxConstraints(maxWidth: isTablet ? 500 : double.infinity),
                        child: Card(
                          elevation: 8,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Padding(
                            padding: EdgeInsets.all(isTablet ? 48.0 : 32.0),
                            child: Form(
                              key: _formKey,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // Logo
                                  if (AppAssets.logoPath != null)
                                    Image.asset(
                                      AppAssets.logoPath!,
                                      height: isTablet ? 120 : 80,
                                      fit: BoxFit.contain,
                                      cacheWidth: isTablet ? 240 : 160, // Optimización de caché
                                      errorBuilder: (context, error, stackTrace) {
                                        return Icon(
                                          Icons.image_not_supported,
                                          size: isTablet ? 120 : 80,
                                          color: Colors.grey,
                                        );
                                      },
                                    ),
                                  SizedBox(height: isTablet ? 32 : 24),

                                  // Título
                                  Text(
                                    'POS ANDROID',
                                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: isDark ? Colors.white : AppColors.primary,
                                        ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Sistema de Punto de Venta',
                                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                          color: Colors.grey,
                                        ),
                                  ),
                                  SizedBox(height: isTablet ? 48 : 32),

                                  // Campo de contraseña
                                  TextFormField(
                                    controller: _passwordController,
                                    obscureText: _obscurePassword,
                                    decoration: InputDecoration(
                                      labelText: 'Contraseña',
                                      prefixIcon: const Icon(Icons.lock_outline),
                                      suffixIcon: IconButton(
                                        icon: Icon(
                                          _obscurePassword ? Icons.visibility_off : Icons.visibility,
                                        ),
                                        onPressed: () {
                                          setState(() => _obscurePassword = !_obscurePassword);
                                        },
                                      ),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return 'Contraseña requerida';
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 16),

                                  // Recordar contraseña
                                  Row(
                                    children: [
                                      Checkbox(
                                        value: _rememberMe,
                                        onChanged: (value) {
                                          setState(() => _rememberMe = value ?? false);
                                        },
                                      ),
                                      const Text('Recordar contraseña'),
                                    ],
                                  ),
                                  SizedBox(height: isTablet ? 32 : 24),

                                  // Botón de login
                                  SizedBox(
                                    width: double.infinity,
                                    height: 56,
                                    child: ElevatedButton(
                                      onPressed: _isLoading ? null : _handleLogin,
                                      style: ElevatedButton.styleFrom(
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                      ),
                                      child: _isLoading
                                          ? const CircularProgressIndicator(color: Colors.white)
                                          : const Text(
                                              'Iniciar Sesión',
                                              style: TextStyle(fontSize: 18),
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
