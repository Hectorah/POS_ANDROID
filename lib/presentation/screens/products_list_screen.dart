import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/app_colors.dart';
import '../../database/db_helper.dart';
import 'create_product_screen.dart';
import 'create_document_screen.dart' show CurrencyFormatter;
import '../../models/app_models.dart';

class ProductsListScreen extends StatefulWidget {
  const ProductsListScreen({super.key});

  @override
  State<ProductsListScreen> createState() => _ProductsListScreenState();
}

class _ProductsListScreenState extends State<ProductsListScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _products = [];
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  double _tasaUsd = 36.50;

  @override
  void initState() {
    super.initState();
    _loadTasaCambio();
    _loadProducts();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadTasaCambio() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final tasa = prefs.getDouble('tasa_usd') ?? 36.50;
      
      if (mounted) {
        setState(() {
          _tasaUsd = tasa;
        });
      }
      
      debugPrint('💱 Tasa de cambio cargada: \$1 = Bs. $_tasaUsd');
    } catch (e) {
      debugPrint('❌ Error cargando tasa de cambio: $e');
    }
  }

  Future<void> _loadProducts() async {
    try {
      setState(() => _isLoading = true);
      
      final products = await DbHelper.instance.obtenerProductos();
      
      if (mounted) {
        setState(() {
          _products = products;
          _isLoading = false;
        });
      }
      
      debugPrint('✅ ${_products.length} productos cargados');
    } catch (e) {
      debugPrint('❌ Error cargando productos: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  List<Map<String, dynamic>> get _filteredProducts {
    if (_searchQuery.isEmpty) {
      return _products;
    }
    
    return _products.where((product) {
      final nombre = (product['nombre'] ?? '').toString().toLowerCase();
      final codArticulo = (product['cod_articulo'] ?? '').toString().toLowerCase();
      final codBarras = (product['cod_barras'] ?? '').toString().toLowerCase();
      final query = _searchQuery.toLowerCase();
      
      return nombre.contains(query) || 
             codArticulo.contains(query) || 
             codBarras.contains(query);
    }).toList();
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

  Future<void> _navigateToCreateProduct() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => const CreateProductScreen(),
      ),
    );
    
    if (result == true) {
      _loadProducts();
      _showSnackBar('✅ Producto registrado exitosamente', AppColors.success);
    }
  }

  Future<void> _navigateToEditProduct(Map<String, dynamic> product) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => CreateProductScreen(product: product),
      ),
    );
    
    if (result == true) {
      _loadProducts();
      _showSnackBar('✅ Producto actualizado exitosamente', AppColors.success);
    }
  }

  Future<void> _deleteProduct(Map<String, dynamic> product) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: isDark ? AppColors.darkCard : AppColors.lightCard,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: AppColors.error, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Eliminar Producto',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppColors.darkText : AppColors.lightText,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '¿Estás seguro de eliminar este producto?',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: isDark ? AppColors.darkText : AppColors.lightText,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppColors.error.withValues(alpha: 0.3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product['nombre'] ?? 'Sin nombre',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: isDark ? AppColors.darkText : AppColors.lightText,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Código: ${product['cod_barras'] ?? 'Sin código'}',
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.info_outline, size: 18, color: AppColors.warning),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Esta acción no se puede deshacer',
                      style: TextStyle(
                        fontSize: 13,
                        fontStyle: FontStyle.italic,
                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(
                'Cancelar',
                style: TextStyle(
                  fontSize: 15,
                  color: isDark ? AppColors.darkText : AppColors.lightText,
                ),
              ),
            ),
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(dialogContext, true),
              icon: const Icon(Icons.delete_forever, size: 20),
              label: const Text('Eliminar'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      try {
        final productoId = product['id'] as int;
        final Map<String, dynamic> result = await DbHelper.instance.eliminarProducto(productoId);
        
        if (mounted) {
          final success = result['success'] as bool? ?? false;
          final message = result['message'] as String? ?? 'Error desconocido';
          
          if (success) {
            _loadProducts();
            _showSnackBar('✅ $message', AppColors.success);
          } else {
            // Mostrar diálogo informativo si no se puede eliminar
            _showCannotDeleteDialog(message);
          }
        }
      } catch (e) {
        if (mounted) {
          _showSnackBar('❌ Error al eliminar: $e', AppColors.error);
        }
      }
    }
  }

  void _showCannotDeleteDialog(String message) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: isDark ? AppColors.darkCard : AppColors.lightCard,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              const Icon(Icons.block, color: AppColors.warning, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'No se puede eliminar',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppColors.darkText : AppColors.lightText,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                message,
                style: TextStyle(
                  fontSize: 15,
                  color: isDark ? AppColors.darkText : AppColors.lightText,
                  height: 1.5,
                ),
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
                    const Icon(Icons.lightbulb_outline, color: AppColors.info, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Puedes editar el producto para actualizar su información o stock.',
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? AppColors.darkText : AppColors.lightText,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Entendido'),
            ),
          ],
          actionsAlignment: MainAxisAlignment.center,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final size = MediaQuery.of(context).size;
    final isTablet = size.width > 600;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        title: const Text('Productos'),
        backgroundColor: isDark ? AppColors.darkCard : AppColors.lightCard,
        foregroundColor: isDark ? AppColors.darkText : AppColors.lightText,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Barra de búsqueda
          Container(
            padding: EdgeInsets.all(isTablet ? 20 : 16),
            color: isDark ? AppColors.darkCard : Colors.white,
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Buscar por nombre, código o código de barras...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          setState(() {
                            _searchController.clear();
                            _searchQuery = '';
                          });
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: isTablet ? 20 : 16,
                  vertical: isTablet ? 16 : 12,
                ),
              ),
              onChanged: (value) {
                setState(() => _searchQuery = value);
              },
            ),
          ),

          // Lista de productos
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredProducts.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                _searchQuery.isEmpty ? Icons.inventory_2_outlined : Icons.search_off,
                                size: isTablet ? 100 : 80,
                                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                              ),
                              SizedBox(height: isTablet ? 24 : 16),
                              Text(
                                _searchQuery.isEmpty
                                    ? 'No hay productos registrados'
                                    : 'No se encontraron productos',
                                style: TextStyle(
                                  fontSize: isTablet ? 20 : 18,
                                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                                ),
                              ),
                              if (_searchQuery.isEmpty) ...[
                                SizedBox(height: isTablet ? 16 : 12),
                                Text(
                                  'Presiona el botón + para agregar uno',
                                  style: TextStyle(
                                    fontSize: isTablet ? 16 : 14,
                                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadProducts,
                        child: ListView.builder(
                          padding: EdgeInsets.all(isTablet ? 20 : 16),
                          itemCount: _filteredProducts.length,
                          itemBuilder: (context, index) {
                            final product = _filteredProducts[index];
                            return _buildProductCard(product, isDark, isTablet);
                          },
                        ),
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _navigateToCreateProduct,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        tooltip: 'Registrar Producto',
        child: const Icon(Icons.add, size: 32),
      ),
    );
  }

  Widget _buildProductCard(Map<String, dynamic> product, bool isDark, bool isTablet) {
    final nombre = product['nombre'] ?? 'Sin nombre';
    final codBarras = product['cod_barras'] ?? 'Sin código';
    final precio = (product['precio'] as num?)?.toDouble() ?? 0.0;
    final stock = (product['stock'] as num?)?.toDouble() ?? 0.0;
    final unidad = UnidadMedidaExtension.fromString(product['unidad_medida']);

    return Card(
      margin: EdgeInsets.only(bottom: isTablet ? 12 : 8),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      color: isDark ? AppColors.darkCard : Colors.white,
      child: InkWell(
        onTap: () => _navigateToEditProduct(product),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: EdgeInsets.all(isTablet ? 16 : 12),
          child: Row(
            children: [
              // Información del producto (izquierda)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Nombre
                    Text(
                      nombre,
                      style: TextStyle(
                        fontSize: isTablet ? 16 : 15,
                        fontWeight: FontWeight.bold,
                        color: isDark ? AppColors.darkText : AppColors.lightText,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    
                    // Código de barras
                    Text(
                      codBarras,
                      style: TextStyle(
                        fontSize: isTablet ? 13 : 12,
                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    
                    // Precios
                    Row(
                      children: [
                        Text(
                          CurrencyFormatter.formatUSD(precio),
                          style: TextStyle(
                            fontSize: isTablet ? 16 : 15,
                            fontWeight: FontWeight.bold,
                            color: AppColors.success,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '• ${CurrencyFormatter.formatBS(precio, _tasaUsd)}',
                          style: TextStyle(
                            fontSize: isTablet ? 14 : 13,
                            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              // Stock y acciones (derecha)
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Botones de acción
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(Icons.edit, size: isTablet ? 20 : 18),
                        color: AppColors.info,
                        onPressed: () => _navigateToEditProduct(product),
                        tooltip: 'Editar',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 32,
                          minHeight: 32,
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.delete, size: isTablet ? 20 : 18),
                        color: AppColors.error,
                        onPressed: () => _deleteProduct(product),
                        tooltip: 'Eliminar',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 32,
                          minHeight: 32,
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 4),
                  
                  // Stock
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: isTablet ? 10 : 8,
                      vertical: isTablet ? 6 : 5,
                    ),
                    decoration: BoxDecoration(
                      color: stock > 0
                          ? AppColors.success.withValues(alpha: 0.1)
                          : AppColors.error.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.inventory_2,
                          size: isTablet ? 16 : 14,
                          color: stock > 0 ? AppColors.success : AppColors.error,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Stock: ${stock.toStringAsFixed(0)} ${unidad.label}',
                          style: TextStyle(
                            fontSize: isTablet ? 13 : 12,
                            fontWeight: FontWeight.w600,
                            color: stock > 0 ? AppColors.success : AppColors.error,
                          ),
                        ),
                      ],
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
}
