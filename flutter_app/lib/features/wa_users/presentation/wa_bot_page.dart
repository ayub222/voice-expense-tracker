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
  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _phoneCtrl = TextEditingController();

  List<WaUser> _users = const [];
  bool _loading = false;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
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

  Future<void> _addUser() async {
    final name = _nameCtrl.text.trim();
    final phone = _phoneCtrl.text.trim();
    if (name.isEmpty || phone.isEmpty) {
      _showSnack('Nama dan nomor WhatsApp wajib diisi.');
      return;
    }

    setState(() => _submitting = true);
    try {
      final updated = await _repo.addUser(name: name, phone: phone);
      if (!mounted) return;
      _nameCtrl.clear();
      _phoneCtrl.clear();
      setState(() => _users = updated);
      _showSnack('Nomor berhasil disimpan. Sync otomatis ke WA Bot Railway ~15 detik.');
    } catch (e) {
      if (mounted) _showSnack('Gagal menambahkan: $e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
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

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _loadUsers,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            const _WaBotStatusCard(),
            const SizedBox(height: AppSpacing.md),
            _AddWaUserCard(
              nameController: _nameCtrl,
              phoneController: _phoneCtrl,
              submitting: _submitting,
              onSubmit: _addUser,
            ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Daftar Nomor WA Terdaftar (${_users.length})',
                  style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
                IconButton(
                  onPressed: _loading ? null : _loadUsers,
                  tooltip: 'Refresh daftar nomor',
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
                  border: Border.all(color: cs.error.withValues(alpha: 0.5)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_error!, style: tt.bodyMedium?.copyWith(color: cs.error)),
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
                  'Belum ada nomor WhatsApp terdaftar. Tambahkan nomor di atas agar bisa kirim Voice Note ke WA Bot.',
                  style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                ),
              )
            else
              ..._users.map(
                (user) => _WaUserTile(
                  user: user,
                  onToggle: () => _toggleUser(user),
                  onDelete: user.id == 1 ? null : () => _deleteUser(user),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _WaBotStatusCard extends StatelessWidget {
  const _WaBotStatusCard();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: AppRadius.lg,
        border: Border.all(color: cs.primary.withValues(alpha: 0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.cloud_done_outlined, color: cs.primary, size: 22),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'WA Bot 24/7 Aktif (Railway + Vercel + TiDB)',
                  style: tt.titleSmall?.copyWith(
                    color: cs.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Bot utama: 0895374884648 • Auto-sync user tiap 15 detik.',
            style: tt.bodySmall?.copyWith(color: cs.onSurface),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Kirim Voice Note atau teks ke self-chat atau ke grup WA bernama "Catatan Keuangan" agar tidak mengganggu chat pribadi.',
            style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _AddWaUserCard extends StatelessWidget {
  final TextEditingController nameController;
  final TextEditingController phoneController;
  final bool submitting;
  final VoidCallback onSubmit;

  const _AddWaUserCard({
    required this.nameController,
    required this.phoneController,
    required this.submitting,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: AppRadius.lg,
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Tambah Nomor WhatsApp',
            style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: nameController,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Nama Pengguna',
              hintText: 'Misal: Ayub / Istri / Admin',
              prefixIcon: Icon(Icons.person_outline),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: phoneController,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => onSubmit(),
            decoration: const InputDecoration(
              labelText: 'Nomor WhatsApp',
              hintText: '08xxxxxxxxxx',
              prefixIcon: Icon(Icons.phone_android),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton.icon(
              onPressed: submitting ? null : onSubmit,
              icon: submitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.person_add_alt_1),
              label: Text(submitting ? 'Menyimpan...' : 'Daftarkan Nomor WA'),
            ),
          ),
        ],
      ),
    );
  }
}

class _WaUserTile extends StatelessWidget {
  final WaUser user;
  final VoidCallback onToggle;
  final VoidCallback? onDelete;

  const _WaUserTile({
    required this.user,
    required this.onToggle,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: AppRadius.lg,
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: user.isActive
                ? cs.primary.withValues(alpha: 0.18)
                : cs.surfaceContainerHighest,
            child: Icon(
              Icons.chat_bubble_outline,
              color: user.isActive ? cs.primary : cs.onSurfaceVariant,
              size: 20,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.name,
                  style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  '${user.whatsappDisplay} • ${user.isActive ? "Aktif" : "Nonaktif"}',
                  style: tt.bodySmall?.copyWith(
                    color: user.isActive ? cs.primary : cs.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: user.isActive,
            onChanged: (_) => onToggle(),
          ),
          if (onDelete != null)
            IconButton(
              onPressed: onDelete,
              tooltip: 'Hapus nomor',
              icon: Icon(Icons.delete_outline, color: cs.error),
            ),
        ],
      ),
    );
  }
}
