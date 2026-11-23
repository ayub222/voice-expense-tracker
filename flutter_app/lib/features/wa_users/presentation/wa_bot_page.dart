import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../data/wa_user_repository.dart';
import '../domain/wa_user_model.dart';

class WaBotPage extends StatefulWidget {
  const WaBotPage({super.key});

  @override
  State<WaBotPage> createState() => _WaBotPageState();
}

class _WaBotPageState extends State<WaBotPage> {
  final WaUserRepository _repo = WaUserRepository();

  List<WaUser> _users = const [];
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await _repo.fetchUsers();
      if (mounted) {
        setState(() => _users = list);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = 'Gagal memuat data WA Bot: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _openAddUserSheet() async {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    bool saving = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.only(
            left: AppSpacing.lg,
            right: AppSpacing.lg,
            top: AppSpacing.lg,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + AppSpacing.lg,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tambah Nomor WhatsApp',
                  style: Theme.of(ctx)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  controller: nameCtrl,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Nama Pengguna',
                    hintText: 'Misal: Ayub / Admin',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  controller: phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Nomor WhatsApp',
                    hintText: '08xxxxxxxxxx',
                    prefixIcon: Icon(Icons.phone_android),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: saving
                        ? null
                        : () async {
                            final name = nameCtrl.text.trim();
                            final phone = phoneCtrl.text.trim();
                            if (name.isEmpty || phone.isEmpty) {
                              _showSnack('Nama dan nomor WhatsApp wajib diisi.');
                              return;
                            }
                            setModalState(() => saving = true);
                            try {
                              final updated = await _repo.addUser(
                                name: name,
                                phone: phone,
                              );
                              if (!mounted) return;
                              setState(() => _users = updated);
                              if (ctx.mounted) Navigator.pop(ctx);
                              _showSnack(
                                'Nomor disimpan. Sinkron otomatis ke WA Bot dalam 15 detik.',
                              );
                            } catch (e) {
                              if (mounted) _showSnack('Gagal menambahkan: $e');
                              setModalState(() => saving = false);
                            }
                          },
                    child: Text(saving ? 'Menyimpan...' : 'Simpan Nomor'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _toggleUser(WaUser user) async {
    try {
      final updated = await _repo.toggleUser(user.id);
      if (mounted) setState(() => _users = updated);
    } catch (e) {
      if (mounted) _showSnack('Gagal mengubah status: $e');
    }
  }

  Future<void> _deleteUser(WaUser user) async {
    try {
      final updated = await _repo.deleteUser(user.id);
      if (mounted) {
        setState(() => _users = updated);
        _showSnack('Nomor ${user.name} dihapus.');
      }
    } catch (e) {
      if (mounted) _showSnack('Gagal menghapus: $e');
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddUserSheet,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Tambah Nomor'),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadUsers,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.md,
                  AppSpacing.md,
                  96,
                ),
                children: [
                  const _WaBotBanner(),
                  const SizedBox(height: AppSpacing.lg),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Nomor Terdaftar (${_users.length})',
                        style: tt.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      IconButton(
                        onPressed: _loading ? null : _loadUsers,
                        tooltip: 'Muat ulang',
                        icon: const Icon(Icons.refresh),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  if (_loading && _users.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(AppSpacing.xl),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (_error != null && _users.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerLow,
                        borderRadius: AppRadius.lg,
                        border:
                            Border.all(color: cs.error.withValues(alpha: 0.4)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _error!,
                            style: tt.bodyMedium?.copyWith(color: cs.error),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          FilledButton.tonalIcon(
                            onPressed: _loadUsers,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Coba Lagi'),
                          ),
                        ],
                      ),
                    )
                  else if (_users.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerLow,
                        borderRadius: AppRadius.lg,
                        border: Border.all(color: cs.outlineVariant),
                      ),
                      child: Text(
                        'Belum ada nomor terdaftar. Tekan tombol "Tambah Nomor" di pojok kanan bawah.',
                        style:
                            tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                      ),
                    )
                  else
                    Container(
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerLow,
                        borderRadius: AppRadius.lg,
                        border: Border.all(color: cs.outlineVariant),
                      ),
                      child: ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _users.length,
                        separatorBuilder: (_, __) => Divider(
                          height: 1,
                          color: cs.outlineVariant,
                        ),
                        itemBuilder: (context, index) {
                          final user = _users[index];
                          return _WaUserRow(
                            user: user,
                            onToggle: () => _toggleUser(user),
                            onDelete:
                                user.id == 1 ? null : () => _deleteUser(user),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _WaBotBanner extends StatelessWidget {
  const _WaBotBanner();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final sem = Theme.of(context).extension<AppSemanticColors>()!;
    final tt = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: AppRadius.lg,
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: sem.income.withValues(alpha: 0.12),
              borderRadius: AppRadius.md,
            ),
            child: Icon(Icons.cloud_done_outlined, color: sem.income, size: 20),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'WA Bot 24/7 Aktif • 0895374884648',
                  style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  'Daftar nomor otomatis sinkron ke bot setiap 15 detik. Gunakan self-chat atau grup "Catatan Keuangan".',
                  style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WaUserRow extends StatelessWidget {
  final WaUser user;
  final VoidCallback onToggle;
  final VoidCallback? onDelete;

  const _WaUserRow({
    required this.user,
    required this.onToggle,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final sem = Theme.of(context).extension<AppSemanticColors>()!;
    final tt = Theme.of(context).textTheme;
    final badgeColor = user.isActive ? sem.income : cs.onSurfaceVariant;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: 4,
      ),
      leading: CircleAvatar(
        backgroundColor: badgeColor.withValues(alpha: 0.12),
        child: Icon(Icons.person_outline, color: badgeColor, size: 20),
      ),
      title: Text(
        user.name,
        style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w600),
      ),
      subtitle: Row(
        children: [
          Text(user.whatsappDisplay, style: tt.bodySmall),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: badgeColor.withValues(alpha: 0.12),
              borderRadius: AppRadius.full,
            ),
            child: Text(
              user.isActive ? 'Aktif' : 'Nonaktif',
              style: tt.labelSmall?.copyWith(
                color: badgeColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Switch(value: user.isActive, onChanged: (_) => onToggle()),
          if (onDelete != null)
            IconButton(
              onPressed: onDelete,
              tooltip: 'Hapus nomor',
              icon: Icon(Icons.delete_outline, color: cs.error, size: 20),
            ),
        ],
      ),
    );
  }
}
