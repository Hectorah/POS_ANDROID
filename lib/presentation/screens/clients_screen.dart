import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/utils/responsive_helper.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/validators.dart';
import '../widgets/custom_text_field.dart';
import '../widgets/custom_snackbar.dart';

// Modelo de cliente simplificado (sin backend)
class ClientModel {
  final String codigo;
  final String rifType;
  final String rifNumber;
  final String nombre;
  final String direccion;
  final String telefono;
  final String email;
  final bool agenteRetencion;

  ClientModel({
    required this.codigo,
    required this.rifType,
    required this.rifNumber,
    required this.nombre,
    required this.direccion,
    required this.telefono,
    required this.email,
    this.agenteRetencion = false,
  });

  String get fullRif => '$rifType-$rifNumber';
}

/// Pantalla de gestión de clientes - SOLO FRONTEND
class ClientsScreen extends StatefulWidget {
  const ClientsScreen({super.key});

  @override
  State<ClientsScreen> createState() => _ClientsScreenState();
}

class _ClientsScreenState extends State<ClientsScreen> {
  final TextEditingController _searchController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  
  List<ClientModel> _clients = [];
  List<ClientModel> _filteredClients = [];
  final bool _isLoading = false;
  int _displayLimit = 50;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadMockClients();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      if (_displayLimit < _filteredClients.length) {
        setState(() {
          _displayLimit += 50;
        });
      }
    }
  }

  void _loadMockClients() {
    // Datos de ejemplo para demostración
    _clients = [
      ClientModel(
        codigo: '1',
        rifType: 'J',
        rifNumber: '12345678-0',
        nombre: 'TECH SOLUTIONS C.A.',
        direccion: 'Av. Francisco de Miranda, Caracas',
        telefono: '0212-5551234',
        email: 'info@techsolutions.com',
        agenteRetencion: true,
      ),
      ClientModel(
        codigo: '2',
        rifType: 'V',
        rifNumber: '12345678',
        nombre: 'JUAN PÉREZ',
        direccion: 'Urb. El Rosal, Calle 3, Apto 4B',
        telefono: '0414-1234567',
        email: 'juan@email.com',
        agenteRetencion: false,
      ),
      ClientModel(
        codigo: '3',
        rifType: 'J',
        rifNumber: '87654321-9',
        nombre: 'COMERCIAL DEL ESTE C.A.',
        direccion: 'Centro Comercial El Recreo, Local 45',
        telefono: '0212-9876543',
        email: 'ventas@comercialeste.com',
        agenteRetencion: true,
      ),
    ];
    setState(() {
      _filteredClients = _clients;
    });
  }

  void _filterClients(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredClients = _clients;
      } else {
        _filteredClients = _clients
            .where((c) =>
                c.nombre.toLowerCase().contains(query.toLowerCase()) ||
                c.email.toLowerCase().contains(query.toLowerCase()) ||
                c.telefono.contains(query) ||
                c.fullRif.contains(query))
            .toList();
      }
      _displayLimit = 50;
    });
  }

  @override
  Widget build(BuildContext context) {
    final responsive = ResponsiveHelper(context);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Clientes'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              CustomSnackBar.info(context, 'Función en desarrollo');
            },
            tooltip: 'Recargar',
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.all(responsive.getPadding(16)),
            child: CustomTextField(
              controller: _searchController,
              hintText: 'Buscar por nombre, RIF, email o teléfono...',
              prefixIcon: Icons.search,
              onChanged: _filterClients,
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredClients.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.people_outline,
                              size: 64,
                              color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.3),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _searchController.text.isEmpty
                                  ? 'No hay clientes registrados'
                                  : 'No se encontraron clientes',
                              style: TextStyle(
                                fontSize: 16,
                                color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.6),
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: EdgeInsets.symmetric(horizontal: responsive.getPadding(16)),
                        itemCount: _filteredClients.length > _displayLimit 
                            ? _displayLimit + 1 
                            : _filteredClients.length,
                        itemBuilder: (context, index) {
                          if (index >= _displayLimit) {
                            return const Padding(
                              padding: EdgeInsets.all(16.0),
                              child: Center(
                                child: CircularProgressIndicator(),
                              ),
                            );
                          }
                          final client = _filteredClients[index];
                          return _buildClientCard(client, responsive, theme);
                        },
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddClientDialog(responsive, theme),
        icon: const Icon(Icons.person_add),
        label: const Text('Nuevo Cliente'),
        backgroundColor: theme.colorScheme.primary,
        heroTag: 'clientsFAB',
      ),
    );
  }

  Widget _buildClientCard(ClientModel client, ResponsiveHelper responsive, ThemeData theme) {
    return Card(
      margin: EdgeInsets.only(bottom: responsive.getMargin(12)),
      child: ListTile(
        contentPadding: EdgeInsets.all(responsive.getPadding(16)),
        leading: CircleAvatar(
          radius: responsive.getFontSize(30),
          backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.2),
          child: Text(
            client.nombre[0].toUpperCase(),
            style: TextStyle(
              fontSize: responsive.getFontSize(24),
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
            ),
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                client.nombre,
                style: TextStyle(
                  fontSize: responsive.getFontSize(16),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (client.agenteRetencion)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.accent),
                ),
                child: const Text(
                  'AR',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: AppColors.accent,
                  ),
                ),
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: responsive.getHeight(0.5)),
            Row(
              children: [
                Icon(
                  Icons.badge,
                  size: responsive.getFontSize(14),
                  color: theme.textTheme.bodyMedium?.color,
                ),
                SizedBox(width: responsive.getPadding(4)),
                Text(
                  client.fullRif,
                  style: TextStyle(
                    fontSize: responsive.getFontSize(14),
                    color: theme.textTheme.bodyMedium?.color,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            SizedBox(height: responsive.getHeight(0.3)),
            Row(
              children: [
                Icon(
                  Icons.email,
                  size: responsive.getFontSize(14),
                  color: theme.textTheme.bodyMedium?.color,
                ),
                SizedBox(width: responsive.getPadding(4)),
                Expanded(
                  child: Text(
                    client.email,
                    style: TextStyle(
                      fontSize: responsive.getFontSize(14),
                      color: theme.textTheme.bodyMedium?.color,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            SizedBox(height: responsive.getHeight(0.3)),
            Row(
              children: [
                Icon(
                  Icons.phone,
                  size: responsive.getFontSize(14),
                  color: theme.textTheme.bodyMedium?.color,
                ),
                SizedBox(width: responsive.getPadding(4)),
                Text(
                  client.telefono,
                  style: TextStyle(
                    fontSize: responsive.getFontSize(14),
                    color: theme.textTheme.bodyMedium?.color,
                  ),
                ),
              ],
            ),
          ],
        ),
        trailing: PopupMenuButton(
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'edit',
              child: Row(
                children: [
                  Icon(Icons.edit),
                  SizedBox(width: 8),
                  Text('Editar'),
                ],
              ),
            ),
          ],
          onSelected: (value) {
            if (value == 'edit') {
              _showEditClientDialog(client, responsive, theme);
            }
          },
        ),
      ),
    );
  }

  void _showAddClientDialog(ResponsiveHelper responsive, ThemeData theme) {
    final rifTypeController = TextEditingController(text: 'V');
    final rifNumberController = TextEditingController();
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final phoneController = TextEditingController();
    final addressController = TextEditingController();
    bool isRetentionAgent = false;
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: Container(
            width: double.maxFinite,
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.85,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(12),
                      topRight: Radius.circular(12),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.person_add, color: Colors.white, size: 28),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Nuevo Cliente',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      if (!isSaving)
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white),
                          onPressed: () => Navigator.pop(context),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: Form(
                    key: _formKey,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Flexible(
                                flex: 2,
                                child: DropdownButtonFormField<String>(
                                  initialValue: rifTypeController.text,
                                  decoration: const InputDecoration(
                                    labelText: 'Tipo',
                                    prefixIcon: Icon(Icons.badge),
                                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                                  ),
                                  items: const [
                                    DropdownMenuItem(value: 'V', child: Text('V')),
                                    DropdownMenuItem(value: 'E', child: Text('E')),
                                    DropdownMenuItem(value: 'J', child: Text('J')),
                                    DropdownMenuItem(value: 'G', child: Text('G')),
                                  ],
                                  onChanged: isSaving ? null : (value) {
                                    rifTypeController.text = value ?? 'V';
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),
                              Flexible(
                                flex: 5,
                                child: TextFormField(
                                  controller: rifNumberController,
                                  decoration: const InputDecoration(
                                    labelText: 'RIF/Cédula',
                                    hintText: '12345678',
                                  ),
                                  style: const TextStyle(fontSize: 16),
                                  keyboardType: TextInputType.number,
                                  enabled: !isSaving,
                                  inputFormatters: [
                                    RifInputFormatter(),
                                    FilteringTextInputFormatter.allow(RegExp(r'[0-9\-]')),
                                  ],
                                  validator: Validators.validateRif,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          TextFormField(
                            controller: nameController,
                            decoration: const InputDecoration(
                              labelText: 'Nombre completo',
                              prefixIcon: Icon(Icons.person),
                            ),
                            style: const TextStyle(fontSize: 16),
                            textCapitalization: TextCapitalization.characters,
                            enabled: !isSaving,
                            inputFormatters: [UpperCaseTextFormatter()],
                            validator: (value) => Validators.validateRequired(value, 'El nombre'),
                          ),
                          const SizedBox(height: 20),
                          TextFormField(
                            controller: emailController,
                            decoration: const InputDecoration(
                              labelText: 'Email',
                              prefixIcon: Icon(Icons.email),
                            ),
                            style: const TextStyle(fontSize: 16),
                            keyboardType: TextInputType.emailAddress,
                            enabled: !isSaving,
                            validator: Validators.validateEmail,
                          ),
                          const SizedBox(height: 20),
                          TextFormField(
                            controller: phoneController,
                            decoration: const InputDecoration(
                              labelText: 'Teléfono',
                              prefixIcon: Icon(Icons.phone),
                              hintText: '0414-1234567',
                            ),
                            style: const TextStyle(fontSize: 16),
                            keyboardType: TextInputType.phone,
                            enabled: !isSaving,
                            inputFormatters: [PhoneInputFormatter()],
                            validator: Validators.validatePhone,
                          ),
                          const SizedBox(height: 20),
                          TextFormField(
                            controller: addressController,
                            decoration: const InputDecoration(
                              labelText: 'Dirección',
                              prefixIcon: Icon(Icons.location_on),
                            ),
                            style: const TextStyle(fontSize: 16),
                            textCapitalization: TextCapitalization.words,
                            maxLines: 3,
                            enabled: !isSaving,
                            validator: (value) => Validators.validateRequired(value, 'La dirección'),
                          ),
                          const SizedBox(height: 20),
                          CheckboxListTile(
                            title: const Text('Agente de Retención'),
                            subtitle: const Text('Cliente sujeto a retención de IVA'),
                            value: isRetentionAgent,
                            enabled: !isSaving,
                            onChanged: (value) {
                              setDialogState(() {
                                isRetentionAgent = value ?? false;
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(
                        color: theme.brightness == Brightness.dark
                            ? AppColors.darkBorder
                            : AppColors.lightBorder,
                      ),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (!isSaving)
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Cancelar', style: TextStyle(fontSize: 16)),
                        ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: isSaving ? null : () async {
                          if (_formKey.currentState!.validate()) {
                            setDialogState(() => isSaving = true);
                            
                            await Future.delayed(const Duration(seconds: 1));
                            
                            if (context.mounted) {
                              Navigator.pop(context);
                              CustomSnackBar.success(context, 'Cliente guardado (demo)');
                            }
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        ),
                        child: isSaving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : const Text('Guardar', style: TextStyle(fontSize: 16)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showEditClientDialog(ClientModel client, ResponsiveHelper responsive, ThemeData theme) {
    CustomSnackBar.info(context, 'Función de edición en desarrollo');
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}
