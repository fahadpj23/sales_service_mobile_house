// lib/screens/admin/users/user_management_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:intl/intl.dart';

class UserManagementScreen extends StatefulWidget {
  /// Optional — kept for backward compatibility. The screen streams
  /// shops live from `Mobile_house_Shops`, so this list is only used
  /// as a cold-start seed if provided.
  final List<Map<String, dynamic>> shops;

  const UserManagementScreen({super.key, this.shops = const []});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String _searchQuery = '';

  static const Color primaryGreen = Color(0xFF0A4D2E);
  static const Color secondaryGreen = Color(0xFF1A7D4A);
  static const Color accentGreen = Color(0xFF28A745);
  static const Color lightGreen = Color(0xFFE8F5E9);
  static const Color warningColor = Color(0xFFFFC107);
  static const Color dangerColor = Color(0xFFDC3545);

  static const List<String> _roles = ['admin', 'user', 'finance', 'purchaser'];

  static const List<String> _rolesRequiringShop = [
    'user',
    'finance',
    'purchaser',
  ];

  FirebaseApp? _creatorApp;

  // Live shops loaded from Mobile_house_Shops
  List<Map<String, dynamic>> _liveShops = [];
  StreamSubscription<QuerySnapshot>? _shopsSub;

  @override
  void initState() {
    super.initState();
    _subscribeToShops();
  }

  @override
  void dispose() {
    _shopsSub?.cancel();
    super.dispose();
  }

  void _subscribeToShops() {
    // Seed with the passed-in list so the dropdown isn't empty on cold start
    if (_liveShops.isEmpty && widget.shops.isNotEmpty) {
      _liveShops = List<Map<String, dynamic>>.from(widget.shops);
    }
    _shopsSub?.cancel();
    _shopsSub = _firestore
        .collection('Mobile_house_Shops')
        .orderBy('shopName')
        .snapshots()
        .listen(
          (snap) {
            if (!mounted) return;
            setState(() {
              _liveShops = snap.docs.map((d) {
                final data = d.data();
                return {
                  'id': d.id,
                  'name': data['shopName'] ?? 'Unknown',
                  'phone': data['phone'] ?? '',
                };
              }).toList();
            });
          },
          onError: (e) {
            debugPrint('Error streaming shops: $e');
          },
        );
  }

  Future<FirebaseAuth> _getCreatorAuth() async {
    if (_creatorApp == null) {
      _creatorApp = await Firebase.initializeApp(
        name: 'userCreator',
        options: Firebase.app().options,
      );
    }
    return FirebaseAuth.instanceFor(app: _creatorApp!);
  }

  bool _needsShop(String? role) {
    if (role == null) return false;
    return _rolesRequiringShop.contains(role);
  }

  // ============================================================
  // ADD USER
  // ============================================================
  Future<void> _addUser() async {
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final passwordCtrl = TextEditingController();
    final confirmPwdCtrl = TextEditingController();

    String? selectedRole;
    String? selectedShopId;
    bool obscurePwd = true;
    bool obscureConfirm = true;

    String? nameError;
    String? emailError;
    String? passwordError;
    String? confirmError;
    String? roleError;
    String? shopError;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) {
          final passwordsMatch =
              passwordCtrl.text.isNotEmpty &&
              passwordCtrl.text == confirmPwdCtrl.text;

          void submit() {
            final name = nameCtrl.text.trim();
            final email = emailCtrl.text.trim().toLowerCase();
            final pwd = passwordCtrl.text;
            final confirm = confirmPwdCtrl.text;

            nameError = name.isEmpty ? 'Name is required' : null;
            if (email.isEmpty) {
              emailError = 'Email is required';
            } else if (!email.contains('@') || !email.contains('.')) {
              emailError = 'Enter a valid email';
            } else {
              emailError = null;
            }
            passwordError = pwd.length < 6 ? 'At least 6 characters' : null;
            if (confirm.isEmpty) {
              confirmError = 'Please confirm password';
            } else if (confirm != pwd) {
              confirmError = 'Passwords do not match';
            } else {
              confirmError = null;
            }
            roleError = (selectedRole == null || selectedRole!.isEmpty)
                ? 'Please select a role'
                : null;
            if (_needsShop(selectedRole) &&
                (selectedShopId == null || selectedShopId!.isEmpty)) {
              shopError = 'Shop is required for this role';
            } else {
              shopError = null;
            }

            final hasError =
                nameError != null ||
                emailError != null ||
                passwordError != null ||
                confirmError != null ||
                roleError != null ||
                shopError != null;

            setDlgState(() {});
            if (hasError) return;
            Navigator.pop(ctx, true);
          }

          return AlertDialog(
            titlePadding: EdgeInsets.zero,
            contentPadding: EdgeInsets.zero,
            actionsPadding: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 14),
              decoration: BoxDecoration(
                color: lightGreen,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: primaryGreen.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: const Icon(
                      Icons.person_add_alt_1,
                      color: primaryGreen,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Add New User',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: primaryGreen,
                          ),
                        ),
                        SizedBox(height: 1),
                        Text(
                          'Create a login with access role',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.black54,
                            fontWeight: FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    icon: const Icon(Icons.close, size: 18),
                    tooltip: 'Close',
                  ),
                ],
              ),
            ),
            content: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _inputField(
                    label: 'Name',
                    hint: 'John Doe',
                    icon: Icons.person_outline,
                    controller: nameCtrl,
                    error: nameError,
                    textCapitalization: TextCapitalization.words,
                  ),
                  const SizedBox(height: 12),
                  _inputField(
                    label: 'Email',
                    hint: 'name@example.com',
                    icon: Icons.email_outlined,
                    controller: emailCtrl,
                    error: emailError,
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 12),
                  _passwordField(
                    label: 'Password',
                    hint: 'Min 6 characters',
                    controller: passwordCtrl,
                    obscure: obscurePwd,
                    error: passwordError,
                    onToggle: () => setDlgState(() => obscurePwd = !obscurePwd),
                  ),
                  const SizedBox(height: 12),
                  _passwordField(
                    label: 'Confirm Password',
                    hint: 'Re-enter password',
                    controller: confirmPwdCtrl,
                    obscure: obscureConfirm,
                    error: confirmError,
                    onToggle: () =>
                        setDlgState(() => obscureConfirm = !obscureConfirm),
                    showMatchTick: passwordsMatch,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: selectedRole,
                    style: const TextStyle(fontSize: 13, color: Colors.black87),
                    decoration: InputDecoration(
                      labelText: 'Role',
                      errorText: roleError,
                      filled: true,
                      fillColor: Colors.grey.shade50,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(
                          color: primaryGreen,
                          width: 1.4,
                        ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      prefixIcon: const Icon(Icons.badge_outlined, size: 18),
                    ),
                    hint: const Text('Select role'),
                    items: _roles
                        .map(
                          (r) => DropdownMenuItem(
                            value: r,
                            child: Row(
                              children: [
                                Icon(
                                  _getRoleIcon(r),
                                  size: 15,
                                  color: _getRoleColor(r),
                                ),
                                const SizedBox(width: 6),
                                Text(r),
                              ],
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (v) {
                      if (v == null) return;
                      setDlgState(() {
                        selectedRole = v;
                        roleError = null;
                        if (!_needsShop(v)) {
                          selectedShopId = null;
                          shopError = null;
                        }
                      });
                    },
                  ),
                  if (_needsShop(selectedRole)) ...[
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: selectedShopId,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.black87,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Shop',
                        errorText: shopError,
                        filled: true,
                        fillColor: Colors.grey.shade50,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(
                            color: primaryGreen,
                            width: 1.4,
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        prefixIcon: const Icon(Icons.store_outlined, size: 18),
                      ),
                      hint: const Text('Select shop'),
                      items: _liveShops
                          .map(
                            (s) => DropdownMenuItem<String>(
                              value: s['id'] as String,
                              child: Text(
                                s['name'] ?? 'Unknown',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (v) => setDlgState(() {
                        selectedShopId = v;
                        shopError = null;
                      }),
                    ),
                  ],
                  if (selectedRole == 'admin') ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: primaryGreen.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: primaryGreen.withOpacity(0.18),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.info_outline,
                            size: 14,
                            color: primaryGreen,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Admin sees all shops. No shop assignment needed.',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey[800],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(20, 6, 20, 14),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.grey[700],
                          side: BorderSide(color: Colors.grey.shade300),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton.icon(
                        onPressed: submit,
                        icon: const Icon(Icons.check, size: 16),
                        label: const Text(
                          'Create User',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryGreen,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );

    if (confirmed != true) return;

    _showLoadingDialog();
    try {
      final email = emailCtrl.text.trim().toLowerCase();
      final name = nameCtrl.text.trim();
      final password = passwordCtrl.text;
      final role = selectedRole!;

      final dup = await _firestore
          .collection('users')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();
      if (dup.docs.isNotEmpty) {
        if (mounted) Navigator.pop(context);
        _showSnackbar('A user with this email already exists', warningColor);
        return;
      }

      final creatorAuth = await _getCreatorAuth();
      final cred = await creatorAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      final newUid = cred.user!.uid;

      final needsShop = _needsShop(role);
      final shop = needsShop
          ? _liveShops.firstWhere(
              (s) => s['id'] == selectedShopId,
              orElse: () => {},
            )
          : <String, dynamic>{};

      await _firestore.collection('users').doc(newUid).set({
        'id': newUid,
        'uid': newUid,
        'name': name,
        'email': email,
        'role': role,
        'shopId': needsShop ? selectedShopId : null,
        'shopName': needsShop ? shop['name'] : null,
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': FirebaseAuth.instance.currentUser?.email ?? 'admin',
      });

      await creatorAuth.signOut();

      if (mounted) {
        Navigator.pop(context);
        _showSnackbar(
          'User + Auth account created. They can now log in.',
          accentGreen,
        );
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) Navigator.pop(context);
      _showSnackbar('Auth error: ${e.message ?? e.code}', dangerColor);
    } catch (e) {
      if (mounted) Navigator.pop(context);
      _showSnackbar('Error adding user: $e', dangerColor);
    }
  }

  Widget _inputField({
    required String label,
    required String hint,
    required IconData icon,
    required TextEditingController controller,
    String? error,
    TextInputType? keyboardType,
    TextCapitalization textCapitalization = TextCapitalization.none,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      textCapitalization: textCapitalization,
      style: const TextStyle(fontSize: 13),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        errorText: error,
        filled: true,
        fillColor: Colors.grey.shade50,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: primaryGreen, width: 1.4),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        prefixIcon: Icon(icon, size: 18),
      ),
    );
  }

  Widget _passwordField({
    required String label,
    required String hint,
    required TextEditingController controller,
    required bool obscure,
    required VoidCallback onToggle,
    String? error,
    bool showMatchTick = false,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      style: const TextStyle(fontSize: 13),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        errorText: error,
        filled: true,
        fillColor: Colors.grey.shade50,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: primaryGreen, width: 1.4),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        prefixIcon: const Icon(Icons.lock_outline, size: 18),
        suffixIcon: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showMatchTick)
              const Padding(
                padding: EdgeInsets.only(right: 4),
                child: Icon(
                  Icons.check_circle,
                  size: 16,
                  color: Color(0xFF28A745),
                ),
              ),
            IconButton(
              icon: Icon(
                obscure
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                size: 18,
              ),
              onPressed: onToggle,
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // EDIT USER
  // ============================================================
  Future<void> _editUser(String docId, Map<String, dynamic> data) async {
    final nameCtrl = TextEditingController(text: data['name'] ?? '');
    String selectedRole = (data['role'] ?? '').toString();
    String? selectedShopId = data['shopId'] as String?;

    if (!_roles.contains(selectedRole)) selectedRole = '';
    if (!_needsShop(selectedRole)) selectedShopId = null;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.edit, color: primaryGreen, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Edit User',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  style: const TextStyle(fontSize: 13),
                  decoration: const InputDecoration(
                    labelText: 'Name *',
                    border: OutlineInputBorder(),
                    isDense: true,
                    prefixIcon: Icon(Icons.person, size: 18),
                  ),
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  initialValue: (data['email'] ?? '').toString(),
                  enabled: false,
                  style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                  decoration: const InputDecoration(
                    labelText: 'Email (read-only)',
                    border: OutlineInputBorder(),
                    isDense: true,
                    prefixIcon: Icon(Icons.email, size: 18),
                  ),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: selectedRole.isEmpty ? null : selectedRole,
                  style: const TextStyle(fontSize: 13, color: Colors.black87),
                  decoration: const InputDecoration(
                    labelText: 'Role *',
                    border: OutlineInputBorder(),
                    isDense: true,
                    prefixIcon: Icon(Icons.badge, size: 18),
                  ),
                  hint: const Text('Select role'),
                  items: _roles
                      .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                      .toList(),
                  onChanged: (v) {
                    if (v == null) return;
                    setDlgState(() {
                      selectedRole = v;
                      if (!_needsShop(v)) selectedShopId = null;
                    });
                  },
                ),
                if (_needsShop(selectedRole)) ...[
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    value: selectedShopId,
                    style: const TextStyle(fontSize: 13, color: Colors.black87),
                    decoration: const InputDecoration(
                      labelText: 'Shop *',
                      border: OutlineInputBorder(),
                      isDense: true,
                      prefixIcon: Icon(Icons.store, size: 18),
                    ),
                    hint: const Text('Select shop'),
                    items: _liveShops
                        .map(
                          (s) => DropdownMenuItem<String>(
                            value: s['id'] as String,
                            child: Text(
                              s['name'] ?? 'Unknown',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setDlgState(() => selectedShopId = v),
                  ),
                ],
                if (selectedRole == 'admin') ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: primaryGreen.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: primaryGreen.withOpacity(0.2)),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.info_outline,
                          size: 14,
                          color: primaryGreen,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Admin sees all shops. No shop assignment needed.',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[800],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel', style: TextStyle(fontSize: 12)),
            ),
            ElevatedButton.icon(
              onPressed: () {
                if (nameCtrl.text.trim().isEmpty) {
                  _showSnackbar('Name is required', Colors.orange);
                  return;
                }
                if (selectedRole.isEmpty) {
                  _showSnackbar('Role is required', Colors.orange);
                  return;
                }
                if (_needsShop(selectedRole) &&
                    (selectedShopId == null || selectedShopId!.isEmpty)) {
                  _showSnackbar(
                    'Shop is required for $selectedRole role',
                    Colors.orange,
                  );
                  return;
                }
                Navigator.pop(ctx, true);
              },
              icon: const Icon(Icons.save, size: 16),
              label: const Text('Save', style: TextStyle(fontSize: 12)),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryGreen,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true) return;

    _showLoadingDialog();
    try {
      final needsShop = _needsShop(selectedRole);
      final shop = needsShop
          ? _liveShops.firstWhere(
              (s) => s['id'] == selectedShopId,
              orElse: () => {},
            )
          : <String, dynamic>{};

      await _firestore.collection('users').doc(docId).update({
        'name': nameCtrl.text.trim(),
        'role': selectedRole,
        'shopId': needsShop ? selectedShopId : FieldValue.delete(),
        'shopName': needsShop ? shop['name'] : FieldValue.delete(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (mounted) {
        Navigator.pop(context);
        _showSnackbar('User updated successfully', accentGreen);
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      _showSnackbar('Error updating user: $e', dangerColor);
    }
  }

  // ============================================================
  // DELETE USER
  // ============================================================
  Future<void> _deleteUser(String docId, Map<String, dynamic> data) async {
    final proceed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning_amber, color: dangerColor, size: 20),
            const SizedBox(width: 8),
            const Text(
              'Delete User',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to delete this user?',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Name: ${data['name'] ?? 'N/A'}',
                    style: const TextStyle(fontSize: 12),
                  ),
                  Text(
                    'Email: ${data['email'] ?? 'N/A'}',
                    style: const TextStyle(fontSize: 12),
                  ),
                  Text(
                    'Role: ${data['role'] ?? 'N/A'}',
                    style: const TextStyle(fontSize: 12),
                  ),
                  Text(
                    'Shop: ${data['shopName'] ?? 'No shop'}',
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Note: The Firebase Auth account must be removed separately '
              '(via Cloud Function or Admin SDK). The Firestore record '
              'will be deleted now.',
              style: TextStyle(fontSize: 11, color: Colors.grey[700]),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(fontSize: 12)),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.delete, size: 16),
            label: const Text('Delete', style: TextStyle(fontSize: 12)),
            style: ElevatedButton.styleFrom(
              backgroundColor: dangerColor,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );

    if (proceed != true) return;

    _showLoadingDialog();
    try {
      await _firestore.collection('users').doc(docId).delete();
      if (mounted) {
        Navigator.pop(context);
        _showSnackbar('User record deleted', dangerColor);
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      _showSnackbar('Error deleting user: $e', dangerColor);
    }
  }

  // ============================================================
  // HELPERS
  // ============================================================
  void _showSnackbar(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontSize: 12)),
        backgroundColor: color,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showLoadingDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: primaryGreen),
                const SizedBox(height: 12),
                const Text('Processing...', style: TextStyle(fontSize: 12)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _getRoleColor(String role) {
    switch (role) {
      case 'admin':
        return dangerColor;
      case 'finance':
        return const Color(0xFF9C27B0);
      case 'purchaser':
        return const Color(0xFFFF9800);
      case 'user':
      default:
        return secondaryGreen;
    }
  }

  IconData _getRoleIcon(String role) {
    switch (role) {
      case 'admin':
        return Icons.admin_panel_settings;
      case 'finance':
        return Icons.account_balance_wallet;
      case 'purchaser':
        return Icons.shopping_cart;
      case 'user':
      default:
        return Icons.person;
    }
  }

  Color _getAvatarColor(String? name) {
    if (name == null || name.isEmpty) return Colors.grey;
    final hash = name.codeUnitAt(0) % 4;
    switch (hash) {
      case 0:
        return primaryGreen;
      case 1:
        return const Color(0xFF2196F3);
      case 2:
        return const Color(0xFF9C27B0);
      default:
        return const Color(0xFFFF9800);
    }
  }

  // ============================================================
  // BUILD
  // ============================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: lightGreen,
      appBar: AppBar(
        title: const Text(
          'User Management',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: Colors.white,
          ),
        ),
        backgroundColor: primaryGreen,
        foregroundColor: Colors.white,
        elevation: 2,
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add, size: 20),
            tooltip: 'Add User',
            onPressed: _addUser,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          Expanded(child: _buildUserList()),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addUser,
        backgroundColor: primaryGreen,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.person_add),
        label: const Text('Add User'),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.all(10),
      color: Colors.white,
      child: Container(
        height: 38,
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: TextField(
          style: const TextStyle(fontSize: 12, color: Colors.black87),
          decoration: InputDecoration(
            hintText: 'Search by name, email, role, shop...',
            hintStyle: TextStyle(fontSize: 11, color: Colors.grey[400]),
            prefixIcon: Icon(Icons.search, color: primaryGreen, size: 18),
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
                    icon: Icon(Icons.clear, size: 16, color: Colors.grey),
                    onPressed: () => setState(() => _searchQuery = ''),
                  )
                : null,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 8,
            ),
            isDense: true,
          ),
          onChanged: (v) {
            setState(() => _searchQuery = v.toLowerCase());
          },
        ),
      ),
    );
  }

  Widget _buildUserList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore.collection('users').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 40, color: dangerColor),
                const SizedBox(height: 6),
                Text(
                  'Error loading users',
                  style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                ),
              ],
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: CircularProgressIndicator(color: secondaryGreen),
          );
        }

        final allDocs = snapshot.data?.docs ?? [];

        if (allDocs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.people_outline, size: 48, color: Colors.grey[400]),
                const SizedBox(height: 8),
                Text(
                  'No users found',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Tap "Add User" to create one',
                  style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                ),
              ],
            ),
          );
        }

        final docs = allDocs.where((d) {
          final data = d.data() as Map<String, dynamic>;
          if (_searchQuery.isEmpty) return true;
          return (data['name']?.toString().toLowerCase().contains(
                    _searchQuery,
                  ) ??
                  false) ||
              (data['email']?.toString().toLowerCase().contains(_searchQuery) ??
                  false) ||
              (data['role']?.toString().toLowerCase().contains(_searchQuery) ??
                  false) ||
              (data['shopName']?.toString().toLowerCase().contains(
                    _searchQuery,
                  ) ??
                  false);
        }).toList();

        int totalUsers = allDocs.length;
        int adminCount = allDocs.where((d) {
          final data = d.data() as Map<String, dynamic>;
          return data['role'] == 'admin';
        }).length;
        int shopUsers = allDocs.where((d) {
          final data = d.data() as Map<String, dynamic>;
          return data['shopId'] != null;
        }).length;

        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.search_off, size: 40, color: Colors.grey[400]),
                const SizedBox(height: 6),
                Text(
                  'No matching users',
                  style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                ),
              ],
            ),
          );
        }

        return Column(
          children: [
            _buildStatsBar(totalUsers, adminCount, shopUsers),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async => setState(() {}),
                color: secondaryGreen,
                child: ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: docs.length,
                  itemBuilder: (context, i) {
                    final doc = docs[i];
                    final data = doc.data() as Map<String, dynamic>;
                    return _buildUserCard(doc.id, data);
                  },
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatsBar(int total, int admins, int shopUsers) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      color: Colors.white,
      child: Row(
        children: [
          Expanded(
            child: _buildStatChip(
              Icons.people,
              '$total',
              'Total',
              primaryGreen,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildStatChip(
              Icons.admin_panel_settings,
              '$admins',
              'Admins',
              dangerColor,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildStatChip(
              Icons.store,
              '$shopUsers',
              'Shop Users',
              secondaryGreen,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatChip(
    IconData icon,
    String count,
    String label,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 4),
          Text(
            count,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(width: 3),
          Flexible(
            child: Text(
              label,
              style: TextStyle(fontSize: 10, color: Colors.grey[700]),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserCard(String docId, Map<String, dynamic> data) {
    final name = (data['name'] ?? 'Unknown').toString();
    final email = (data['email'] ?? '').toString();
    final role = (data['role'] ?? 'user').toString();
    final shopName = data['shopName']?.toString();
    final roleColor = _getRoleColor(role);
    final roleIcon = _getRoleIcon(role);
    final avatarColor = _getAvatarColor(name);

    final isAdminRole = role == 'admin';
    final shopDisplay = isAdminRole
        ? 'All shops (Admin)'
        : (shopName ?? 'No shop assigned');

    String createdStr = '';
    if (data['createdAt'] is Timestamp) {
      try {
        createdStr = DateFormat(
          'dd/MM/yy • hh:mm a',
        ).format((data['createdAt'] as Timestamp).toDate());
      } catch (_) {}
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: roleColor.withOpacity(0.25), width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: avatarColor.withOpacity(0.15),
                  child: Text(
                    name.isNotEmpty ? name[0].toUpperCase() : '?',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: avatarColor,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: primaryGreen,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (email.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Icon(
                              Icons.email,
                              size: 11,
                              color: Colors.grey[500],
                            ),
                            const SizedBox(width: 3),
                            Expanded(
                              child: Text(
                                email,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey[700],
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: roleColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: roleColor.withOpacity(0.4),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(roleIcon, size: 11, color: roleColor),
                      const SizedBox(width: 3),
                      Text(
                        role.toUpperCase(),
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: roleColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: roleColor.withOpacity(0.1)),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _buildDetailItem(
                          'Shop',
                          shopDisplay,
                          color: isAdminRole
                              ? dangerColor
                              : (shopName != null
                                    ? primaryGreen
                                    : Colors.grey[600]),
                        ),
                      ),
                    ],
                  ),
                  if (createdStr.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Expanded(
                          child: _buildDetailItem('Created', createdStr),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Expanded(
                        child: _buildDetailItem(
                          'UID',
                          (data['uid'] ?? data['id'] ?? '').toString(),
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: () => _editUser(docId, data),
                  icon: Icon(Icons.edit, size: 14, color: primaryGreen),
                  label: Text(
                    'Edit',
                    style: TextStyle(fontSize: 12, color: primaryGreen),
                  ),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    minimumSize: const Size(0, 0),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
                const SizedBox(width: 4),
                TextButton.icon(
                  onPressed: () => _deleteUser(docId, data),
                  icon: const Icon(
                    Icons.delete_outline,
                    size: 14,
                    color: dangerColor,
                  ),
                  label: const Text(
                    'Delete',
                    style: TextStyle(fontSize: 12, color: dangerColor),
                  ),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    minimumSize: const Size(0, 0),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailItem(String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label: ',
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 10,
                color: color ?? Colors.grey[800],
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
