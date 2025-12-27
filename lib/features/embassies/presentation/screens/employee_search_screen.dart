import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../shared/widgets/standard_search_bar.dart';
import '../../data/models/embassy_employee_model.dart';
import '../../data/datasources/embassy_remote_datasource.dart';
import '../../domain/entities/embassy_entity.dart';

class EmployeeSearchScreen extends ConsumerStatefulWidget {
  final EmbassyEntity? embassy; // Optional: pre-filter by embassy

  const EmployeeSearchScreen({super.key, this.embassy});

  @override
  ConsumerState<EmployeeSearchScreen> createState() =>
      _EmployeeSearchScreenState();
}

class _EmployeeSearchScreenState extends ConsumerState<EmployeeSearchScreen> {
  final _searchController = TextEditingController();
  final _dataSource = EmbassyRemoteDataSourceImpl();

  List<EmbassyEmployeeModel> _employees = [];
  bool _isLoading = false;
  String? _selectedDepartment;
  String? _error;

  static const List<String> _departments = [
    'Tous les départements',
    'Direction',
    'Services consulaires',
    'Section des visas',
    'État civil',
    'Affaires sociales',
    'Chancellerie',
    'Communication',
    'Administration',
  ];

  @override
  void initState() {
    super.initState();
    _loadEmployees();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadEmployees() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final employees = await _dataSource.searchEmployees(
        query: _searchController.text.trim(),
        embassyId: widget.embassy?.id,
        department:
            _selectedDepartment == 'Tous les départements'
                ? null
                : _selectedDepartment,
      );

      setState(() {
        _employees = employees;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _sendEmail(String email) async {
    final uri = Uri.parse('mailto:$email');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _makePhoneCall(String phone) async {
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.embassy != null
              ? 'Personnel - ${widget.embassy!.name}'
              : 'Rechercher un employé',
        ),
        backgroundColor: theme.colorScheme.surface,
      ),
      body: Column(
        children: [
          // Search and filter section
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                // Search bar
                Padding(
                  padding: EdgeInsets.zero,
                  child: StandardSearchBar(
                    controller: _searchController,
                    hintText: 'Rechercher par nom, titre, rôle...',
                    onSubmitted: (_) => _loadEmployees(),
                    onClear: _loadEmployees,
                  ),
                ),

                // Department filter
                DropdownButtonFormField<String>(
                  value: _selectedDepartment,
                  decoration: InputDecoration(
                    labelText: 'Département',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                  items:
                      _departments.map((dept) {
                        return DropdownMenuItem(value: dept, child: Text(dept));
                      }).toList(),
                  onChanged: (value) {
                    setState(() => _selectedDepartment = value);
                    _loadEmployees();
                  },
                ),
              ],
            ),
          ),

          // Results
          Expanded(child: _buildContent()),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'Erreur de chargement',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(_error!, style: TextStyle(color: Colors.grey[500])),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadEmployees,
              icon: const Icon(Icons.refresh),
              label: const Text('Réessayer'),
            ),
          ],
        ),
      );
    }

    if (_employees.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'Aucun employé trouvé',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Essayez de modifier vos critères de recherche',
              style: TextStyle(color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadEmployees,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _employees.length,
        itemBuilder: (context, index) {
          return _EmployeeCard(
            employee: _employees[index],
            onEmail: _sendEmail,
            onPhone: _makePhoneCall,
          );
        },
      ),
    );
  }
}

class _EmployeeCard extends StatelessWidget {
  final EmbassyEmployeeModel employee;
  final Function(String) onEmail;
  final Function(String) onPhone;

  const _EmployeeCard({
    required this.employee,
    required this.onEmail,
    required this.onPhone,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Avatar
                CircleAvatar(
                  radius: 28,
                  backgroundImage:
                      employee.photoUrl != null
                          ? NetworkImage(employee.photoUrl!)
                          : null,
                  backgroundColor: theme.colorScheme.primaryContainer,
                  child:
                      employee.photoUrl == null
                          ? Text(
                            employee.name.isNotEmpty
                                ? employee.name[0].toUpperCase()
                                : '?',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.primary,
                            ),
                          )
                          : null,
                ),
                const SizedBox(width: 16),

                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        employee.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      if (employee.title != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          employee.title!,
                          style: TextStyle(
                            color: theme.colorScheme.primary,
                            fontSize: 14,
                          ),
                        ),
                      ],
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.secondaryContainer,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              employee.role,
                              style: TextStyle(
                                fontSize: 12,
                                color: theme.colorScheme.onSecondaryContainer,
                              ),
                            ),
                          ),
                          if (employee.department != null) ...[
                            const SizedBox(width: 8),
                            Text(
                              employee.department!,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // Languages
            if (employee.languages.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 6,
                children:
                    employee.languages.map((lang) {
                      return Chip(
                        label: Text(lang, style: const TextStyle(fontSize: 11)),
                        padding: EdgeInsets.zero,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                      );
                    }).toList(),
              ),
            ],

            // Bio
            if (employee.bio != null && employee.bio!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                employee.bio!,
                style: TextStyle(color: Colors.grey[600], fontSize: 13),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],

            // Actions
            if (employee.email != null || employee.phone != null) ...[
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  if (employee.email != null)
                    TextButton.icon(
                      onPressed: () => onEmail(employee.email!),
                      icon: const Icon(Icons.email_outlined, size: 20),
                      label: const Text('Email'),
                    ),
                  if (employee.phone != null)
                    TextButton.icon(
                      onPressed: () => onPhone(employee.phone!),
                      icon: const Icon(Icons.phone_outlined, size: 20),
                      label: const Text('Appeler'),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
