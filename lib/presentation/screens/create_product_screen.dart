import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/constants/app_colors.dart';
import '../../database/db_helper.dart';
import '../../presentation/widgets/custom_snackbar.dart';

class CreateProductScreen extends StatefulWidget {
  final Map<String, dynamic>? product;
  
  const CreateProductScreen({super.key, this.product});

  @override
  State<CreateProductScreen> createState() => _CreateProductScreenState();
}

class _CreateProductScreenState extends State<CreateProductScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;
  bool get _isEditing => widget.product != null;

  // Controladores
  final _codArticuloController = TextEditingController();
  final _codBarrasController = TextEditingController();
  final _nombreController = TextEditingController();
  final _descripcionController = TextEditingController();
  final _precioController = TextEditingController();
  final _stockController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      _loadProductData();
    }
  }

  void _loadProductData() {
    final product = widget.product!;
    _codArticuloController.text = product['cod_articulo'] ?? '';
    _codBarrasController.text = product['cod_barras'] ?? '';
    _nombreController.text = product['nombre'] ?? '';
    _descripcionController.text = product['descripcion'] ?? '';
    _precioController.text = (product['precio'] as num?)?.toStringAsFixed(2) ?? '';
    _stockController.text = (product['stock'] as num?)?.toStringAsFixed(0) ?? '';
  }

  @override
  void dispose() {
    _codArticuloController.dispose();
    _codBarrasController.dispose();
    _nombreController.dispose();
    _descripcionController.dispose();
    _precioController.dispose();
    _stockController.dispose();
    super.dispose();
  }

  Future<void> _saveProduct() async {
    if (!_formKey.currentState!.validate()) {
      CustomSnackBar.warning(context, 'Por favor completa todos los campos requeridos');
      return;
    }

    setState(() => _isSaving = true);

    try {
      final codArticulo = _codArticuloController.text.trim().toUpperCase();
      final codBarras = _codBarrasController.text.trim();
      final nombre = _nombreController.text.trim().toUpperCase();
      final descripcion = _descripcionController.text.trim().toUpperCase();
      final precio = double.parse(_precioController.text.trim());
      final stock = double.parse(_stockController.text.trim());

      if (_isEditing) {
        // Actualizar producto existente
        final productoId = widget.product!['id'] as int;
        
        final success = await DbHelper.instance.actualizarProducto(
          productoId: productoId,
          codBarras: codBarras,
          nombre: nombre,
          descripcion: descripcion,
          precio: precio,
          stock: stock,
        );
        
        if (!success) {
          throw Exception('No se pudo actualizar el producto');
        }
        
        debugPrint('✅ Producto actualizado con ID: $productoId');
      } else {
        // Verificar si el código de artículo ya existe
        final existingProduct = await DbHelper.instance.buscarProductoPorCodigo(codArticulo);
        
        if (existingProduct != null) {
          if (mounted) {
            CustomSnackBar.error(context, 'Ya existe un producto con el código: $codArticulo');
            setState(() => _isSaving = false);
          }
          return;
        }

        // Crear nuevo producto
        final productoId = await DbHelper.instance.crearProducto(
          codArticulo: codArticulo,
          codBarras: codBarras,
          nombre: nombre,
          descripcion: descripcion,
          precio: precio,
        );

        // Crear existencia inicial
        await DbHelper.instance.crearExistencia(
          productoId: productoId,
          cantidad: stock,
        );

        debugPrint('✅ Producto creado con ID: $productoId');
      }

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      debugPrint('❌ Error guardando producto: $e');
      if (mounted) {
        CustomSnackBar.error(context, 'Error al guardar el producto: $e');
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final size = MediaQuery.of(context).size;
    final isTablet = size.width > 600;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        title: Text(_isEditing ? 'Editar Producto' : 'Registrar Producto'),
        backgroundColor: isDark ? AppColors.darkCard : AppColors.lightCard,
        foregroundColor: isDark ? AppColors.darkText : AppColors.lightText,
        elevation: 0,
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: EdgeInsets.all(isTablet ? 24 : 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildSectionTitle('Información del Producto', isDark, isTablet),
              SizedBox(height: isTablet ? 20 : 16),

              _buildTextField(
                controller: _codArticuloController,
                label: 'Código de Artículo',
                hint: 'Ej: PROD001',
                icon: Icons.tag,
                isRequired: true,
                isDark: isDark,
                isTablet: isTablet,
                maxLength: 20,
                enabled: !_isEditing, // No editable si está editando
                textCapitalization: TextCapitalization.characters,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'El código de artículo es requerido';
                  }
                  if (value.trim().length < 2) {
                    return 'Mínimo 2 caracteres';
                  }
                  if (value.trim().length > 20) {
                    return 'Máximo 20 caracteres';
                  }
                  return null;
                },
              ),
              SizedBox(height: isTablet ? 16 : 12),

              _buildTextField(
                controller: _codBarrasController,
                label: 'Código de Barras',
                hint: 'Ej: 7501234567890 (opcional)',
                icon: Icons.qr_code_scanner,
                isRequired: false,
                isDark: isDark,
                isTablet: isTablet,
                maxLength: 20,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                ],
                validator: (value) {
                  if (value != null && value.trim().isNotEmpty) {
                    if (value.trim().length < 8) {
                      return 'Mínimo 8 dígitos';
                    }
                    if (value.trim().length > 20) {
                      return 'Máximo 20 dígitos';
                    }
                  }
                  return null;
                },
              ),
              SizedBox(height: isTablet ? 16 : 12),

              _buildTextField(
                controller: _nombreController,
                label: 'Nombre del Producto',
                hint: 'Ej: LAPTOP HP 15"',
                icon: Icons.inventory_2,
                isRequired: true,
                isDark: isDark,
                isTablet: isTablet,
                maxLength: 100,
                textCapitalization: TextCapitalization.characters,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'El nombre es requerido';
                  }
                  if (value.trim().length < 3) {
                    return 'Mínimo 3 caracteres';
                  }
                  if (value.trim().length > 100) {
                    return 'Máximo 100 caracteres';
                  }
                  return null;
                },
              ),
              SizedBox(height: isTablet ? 16 : 12),

              _buildTextField(
                controller: _descripcionController,
                label: 'Descripción',
                hint: 'DESCRIPCIÓN DETALLADA DEL PRODUCTO (OPCIONAL)',
                icon: Icons.description,
                isRequired: false,
                isDark: isDark,
                isTablet: isTablet,
                maxLines: 3,
                maxLength: 500,
                textCapitalization: TextCapitalization.sentences,
                validator: (value) {
                  if (value != null && value.trim().isNotEmpty) {
                    if (value.trim().length > 500) {
                      return 'Máximo 500 caracteres';
                    }
                  }
                  return null;
                },
              ),
              SizedBox(height: isTablet ? 24 : 20),

              _buildSectionTitle('Precio y Stock', isDark, isTablet),
              SizedBox(height: isTablet ? 20 : 16),

              _buildTextField(
                controller: _precioController,
                label: 'Precio (USD)',
                hint: '0.00',
                icon: Icons.attach_money,
                isRequired: true,
                isDark: isDark,
                isTablet: isTablet,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                ],
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'El precio es requerido';
                  }
                  final precio = double.tryParse(value.trim());
                  if (precio == null) {
                    return 'Ingresa un precio válido';
                  }
                  if (precio <= 0) {
                    return 'El precio debe ser mayor a 0';
                  }
                  if (precio > 999999.99) {
                    return 'Precio máximo: 999,999.99';
                  }
                  return null;
                },
              ),
              SizedBox(height: isTablet ? 16 : 12),

              _buildTextField(
                controller: _stockController,
                label: 'Stock ${_isEditing ? 'Actual' : 'Inicial'}',
                hint: '0',
                icon: Icons.inventory,
                isRequired: true,
                isDark: isDark,
                isTablet: isTablet,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                ],
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'El stock es requerido';
                  }
                  final stock = double.tryParse(value.trim());
                  if (stock == null) {
                    return 'Ingresa un stock válido';
                  }
                  if (stock < 0) {
                    return 'El stock no puede ser negativo';
                  }
                  if (stock > 999999.99) {
                    return 'Stock máximo: 999,999.99';
                  }
                  return null;
                },
              ),
              SizedBox(height: isTablet ? 32 : 24),

              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isSaving
                          ? null
                          : () => Navigator.pop(context, false),
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.symmetric(
                          vertical: isTablet ? 18 : 16,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        side: BorderSide(
                          color: isDark ? AppColors.darkText : AppColors.lightText,
                        ),
                      ),
                      child: Text(
                        'Cancelar',
                        style: TextStyle(
                          fontSize: isTablet ? 18 : 16,
                          color: isDark ? AppColors.darkText : AppColors.lightText,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: isTablet ? 16 : 12),

                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: _isSaving ? null : _saveProduct,
                      icon: _isSaving
                          ? SizedBox(
                              width: isTablet ? 20 : 18,
                              height: isTablet ? 20 : 18,
                              child: const CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : Icon(Icons.save, size: isTablet ? 24 : 20),
                      label: Text(
                        _isSaving 
                            ? 'Guardando...' 
                            : _isEditing 
                                ? 'Actualizar Producto' 
                                : 'Guardar Producto',
                        style: TextStyle(
                          fontSize: isTablet ? 18 : 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(
                          vertical: isTablet ? 18 : 16,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 2,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, bool isDark, bool isTablet) {
    return Text(
      title,
      style: TextStyle(
        fontSize: isTablet ? 20 : 18,
        fontWeight: FontWeight.bold,
        color: isDark ? AppColors.darkText : AppColors.lightText,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required bool isRequired,
    required bool isDark,
    required bool isTablet,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    int maxLines = 1,
    int? maxLength,
    bool enabled = true,
    TextCapitalization textCapitalization = TextCapitalization.none,
  }) {
    return TextFormField(
      controller: controller,
      enabled: enabled,
      decoration: InputDecoration(
        labelText: isRequired ? '$label *' : label,
        hintText: hint,
        prefixIcon: Icon(icon, size: isTablet ? 24 : 20),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        filled: true,
        fillColor: enabled 
            ? (isDark ? AppColors.darkCard : Colors.white)
            : (isDark ? AppColors.darkBackground : Colors.grey[200]),
        contentPadding: EdgeInsets.symmetric(
          horizontal: isTablet ? 20 : 16,
          vertical: isTablet ? 18 : 16,
        ),
        labelStyle: TextStyle(
          fontSize: isTablet ? 16 : 14,
        ),
        hintStyle: TextStyle(
          fontSize: isTablet ? 15 : 13,
          color: Colors.grey,
        ),
        counterText: maxLength != null ? '' : null,
      ),
      style: TextStyle(
        fontSize: isTablet ? 16 : 14,
      ),
      textCapitalization: textCapitalization,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      maxLines: maxLines,
      maxLength: maxLength,
      validator: validator,
    );
  }
}
