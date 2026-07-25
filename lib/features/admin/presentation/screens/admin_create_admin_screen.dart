import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/enums/admin_enums.dart';
import '../../domain/constants/role_permissions.dart';
import '../providers/role_management_provider.dart';

class AdminCreateAdminScreen extends ConsumerStatefulWidget {
  const AdminCreateAdminScreen({super.key});

  @override
  ConsumerState<AdminCreateAdminScreen> createState() =>
      _AdminCreateAdminScreenState();
}

class _AdminCreateAdminScreenState
    extends ConsumerState<AdminCreateAdminScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();

  AdminRole _selectedRole = AdminRole.contentMod;
  bool _isSearching = false;
  bool _isAssigning = false;
  AdminUser? _foundUser;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF1E293B)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Créer un administrateur',
          style: TextStyle(
            color: Color(0xFF1E293B),
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 32),
            _buildSearchCard(),
            if (_foundUser != null) ...[
              const SizedBox(height: 24),
              _buildUserPreview(),
            ],
            const SizedBox(height: 24),
            _buildRoleSelector(),
            const SizedBox(height: 24),
            _buildPermissionsPreview(),
            const SizedBox(height: 32),
            _buildActionButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(30),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.person_add_alt_1,
              color: Colors.white,
              size: 32,
            ),
          ),
          const SizedBox(width: 20),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Nouvel Administrateur',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Recherchez un utilisateur existant et attribuez-lui un rôle d\'administration',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchCard() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.search, color: Color(0xFF6366F1)),
                  SizedBox(width: 8),
                  Text(
                    'Rechercher un utilisateur',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Entrez l\'adresse email de l\'utilisateur que vous souhaitez promouvoir',
                style: TextStyle(
                  color: Color(0xFF64748B),
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: 'Adresse email',
                  hintText: 'utilisateur@exemple.com',
                  prefixIcon: const Icon(Icons.email_outlined),
                  suffixIcon: _isSearching
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : IconButton(
                          icon: const Icon(Icons.search),
                          onPressed: _searchUser,
                        ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Veuillez entrer une adresse email';
                  }
                  if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                      .hasMatch(value)) {
                    return 'Veuillez entrer une adresse email valide';
                  }
                  return null;
                },
                onFieldSubmitted: (_) => _searchUser(),
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withAlpha(20),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.withAlpha(50)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline,
                          color: Colors.red, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUserPreview() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: _foundUser!.adminRole != AdminRole.none
              ? Colors.orange.withAlpha(100)
              : const Color(0xFF10B981).withAlpha(100),
          width: 2,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _foundUser!.adminRole != AdminRole.none
                      ? Icons.warning_amber_rounded
                      : Icons.check_circle_outline,
                  color: _foundUser!.adminRole != AdminRole.none
                      ? Colors.orange
                      : const Color(0xFF10B981),
                ),
                const SizedBox(width: 8),
                Text(
                  _foundUser!.adminRole != AdminRole.none
                      ? 'Utilisateur déjà administrateur'
                      : 'Utilisateur trouvé',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: _foundUser!.adminRole != AdminRole.none
                        ? Colors.orange
                        : const Color(0xFF10B981),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                CircleAvatar(
                  radius: 32,
                  backgroundImage: _foundUser!.photoUrl != null
                      ? NetworkImage(_foundUser!.photoUrl!)
                      : null,
                  backgroundColor: const Color(0xFFE2E8F0),
                  child: _foundUser!.photoUrl == null
                      ? Text(
                          (_foundUser!.displayName ?? _foundUser!.email ?? '?')
                              .substring(0, 1)
                              .toUpperCase(),
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF64748B),
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _foundUser!.displayName ?? 'Sans nom',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _foundUser!.email ?? '',
                        style: const TextStyle(
                          color: Color(0xFF64748B),
                        ),
                      ),
                      if (_foundUser!.adminRole != AdminRole.none) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: _foundUser!.adminRole.color.withAlpha(30),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _foundUser!.adminRole.icon,
                                size: 16,
                                color: _foundUser!.adminRole.color,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Rôle actuel: ${_foundUser!.adminRole.displayName}',
                                style: TextStyle(
                                  color: _foundUser!.adminRole.color,
                                  fontWeight: FontWeight.w500,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoleSelector() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.assignment_ind, color: Color(0xFF6366F1)),
                SizedBox(width: 8),
                Text(
                  'Sélectionner un rôle',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1E293B),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            RadioGroup<AdminRole>(
              groupValue: _selectedRole,
              onChanged: (value) {
                if (value != null) setState(() => _selectedRole = value);
              },
              child: Column(
                children: availableAdminRoles
                    .map((role) => _buildRoleOption(role))
                    .toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoleOption(AdminRole role) {
    final isSelected = _selectedRole == role;
    return GestureDetector(
      onTap: () => setState(() => _selectedRole = role),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? role.color.withAlpha(15) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? role.color : const Color(0xFFE2E8F0),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: role.color.withAlpha(30),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(role.icon, color: role.color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    role.displayName,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? role.color : const Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    role.description,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
            Radio<AdminRole>(
              value: role,
              fillColor: WidgetStateProperty.resolveWith(
                (states) => states.contains(WidgetState.selected)
                    ? role.color
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPermissionsPreview() {
    final permissions = rolePermissions[_selectedRole] ?? {};
    final groupedPermissions = <String, List<AdminPermission>>{};

    for (final permission in permissions) {
      groupedPermissions
          .putIfAbsent(permission.category, () => [])
          .add(permission);
    }

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.security, color: _selectedRole.color),
                const SizedBox(width: 8),
                Text(
                  'Permissions de ${_selectedRole.shortName}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1E293B),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${permissions.length} permissions actives',
              style: const TextStyle(
                color: Color(0xFF64748B),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: groupedPermissions.entries.map((entry) {
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: _selectedRole.color.withAlpha(15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _selectedRole.color.withAlpha(50),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.check_circle,
                        size: 16,
                        color: _selectedRole.color,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${entry.key} (${entry.value.length})',
                        style: TextStyle(
                          color: _selectedRole.color,
                          fontWeight: FontWeight.w500,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close),
            label: const Text('Annuler'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          flex: 2,
          child: ElevatedButton.icon(
            onPressed: _foundUser != null && !_isAssigning
                ? _assignRole
                : null,
            icon: _isAssigning
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.person_add),
            label: Text(
              _foundUser?.adminRole != AdminRole.none
                  ? 'Modifier le rôle'
                  : 'Créer l\'administrateur',
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6366F1),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _searchUser() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSearching = true;
      _errorMessage = null;
      _foundUser = null;
    });

    final user = await ref
        .read(roleManagementNotifierProvider.notifier)
        .searchUserByEmail(_emailController.text.trim());

    setState(() {
      _isSearching = false;
      _foundUser = user;
      if (user == null) {
        _errorMessage = 'Aucun utilisateur trouvé avec cette adresse email';
      }
    });
  }

  Future<void> _assignRole() async {
    if (_foundUser == null) return;

    setState(() => _isAssigning = true);

    final success = await ref
        .read(roleManagementNotifierProvider.notifier)
        .assignRole(_foundUser!.id, _selectedRole);

    setState(() => _isAssigning = false);

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _foundUser!.adminRole != AdminRole.none
                      ? 'Rôle modifié en ${_selectedRole.displayName}'
                      : '${_foundUser!.displayName ?? _foundUser!.email} est maintenant ${_selectedRole.displayName}',
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
      Navigator.pop(context, true);
    }
  }
}
