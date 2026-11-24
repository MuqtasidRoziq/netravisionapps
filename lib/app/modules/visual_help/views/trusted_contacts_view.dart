import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../data/models/visual_help_models.dart';
import '../../../services/auto_click_service.dart';
import '../../../services/contacts_service.dart';
import '../../../utils/constants/app_colors.dart';
import '../controllers/visual_help_controller.dart';

class TrustedContactsView extends GetView<VisualHelpController> {
  const TrustedContactsView({super.key});

  @override
  Widget build(BuildContext context) {
    final contactsService = Get.find<ContactsService>();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      controller.speakTrustedContactsIntro();
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kontak Keluarga & Darurat'),
        leading: Obx(() {
          final isSelected = controller.selectedContactActionKey.value == 'back_to_menu';
          return Semantics(
            label: 'Kembali ke Menu Bantuan Relawan. ${isSelected ? "Sedang dipilih. Ketuk dua kali untuk kembali." : "Ketuk dua kali untuk mendengar fungsi dan kembali."}',
            hint: isSelected ? 'Ketuk dua kali untuk kembali' : 'Ketuk dua kali untuk mendengar fungsi',
            button: true,
            child: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.primaryBlue),
              onPressed: () => controller.handleContactsBackButtonTap(),
            ),
          );
        }),
        actions: [
          // Tombol Sinkronkan Ulang Buku Kontak HP
          IconButton(
            tooltip: 'Sinkronkan Ulang Kontak HP',
            icon: const Icon(Icons.sync_rounded, color: AppColors.primaryBlue),
            onPressed: () async {
              controller.ttsService.speak('Menyinkronkan ulang seluruh kontak ponsel...');
              await contactsService.syncDeviceContacts();
              final total = contactsService.allAvailableContacts.length;
              controller.ttsService.speak(
                'Sinkronisasi selesai. Berhasil memuat $total kontak dari buku telepon Anda.',
                isUrgent: true,
              );
            },
          ),
          Obx(() {
            final isSelected = controller.selectedContactActionKey.value == 'add_contact';
            return Semantics(
              label: 'Tambah Kontak Baru. ${isSelected ? "Sedang dipilih. Ketuk dua kali untuk membuka formulir." : "Ketuk dua kali untuk mendengar penjelasan dan membuka formulir."}',
              hint: isSelected ? 'Ketuk dua kali untuk membuka formulir' : 'Ketuk dua kali untuk mendengar fungsi',
              button: true,
              child: IconButton(
                tooltip: 'Tambah Kontak',
                icon: const Icon(Icons.person_add_alt_1_rounded, color: AppColors.primaryBlue),
                onPressed: () => controller.handleAddContactButtonTap(
                  () => _showAddContactDialog(context, contactsService),
                ),
              ),
            );
          }),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          children: [
            // Banner Status Layanan Auto-Klik Aksesibilitas
            Obx(() {
              final autoClick = Get.isRegistered<AutoClickService>() ? Get.find<AutoClickService>() : null;
              final isEnabled = autoClick?.isAccessibilityGranted.value ?? false;
              if (isEnabled) return const SizedBox.shrink();

              return Semantics(
                label: 'Layanan Auto-Klik Panggilan WhatsApp belum aktif. Ketuk untuk membuka menu Pengaturan Aksesibilitas ponsel agar panggilan video dan pesan terkirim otomatis.',
                button: true,
                child: Container(
                  margin: const EdgeInsets.only(bottom: 14),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF8E1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFFFB300), width: 1.5),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.touch_app_rounded, color: Color(0xFFF57C00), size: 24),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Panggilan Otomatis WhatsApp',
                              style: TextStyle(
                                color: Color(0xFFE65100),
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 2),
                            const Text(
                              'Aktifkan Layanan Aksesibilitas NetraVision agar video call & pesan darurat langsung tertekan otomatis tanpa meraba layar.',
                              style: TextStyle(fontSize: 12, color: Color(0xFF5D4037)),
                            ),
                            const SizedBox(height: 8),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFF57C00),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              onPressed: () {
                                autoClick?.requestPermission();
                              },
                              child: const Text('Aktifkan di Pengaturan HP', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
            // ================= KARTU STATUS SINKRONISASI BUKU KONTAK HP =================
            Obx(() {
              final isSyncing = contactsService.isSyncingDeviceContacts.value;
              final hasPerm = contactsService.hasContactsPermission.value;
              final totalCount = contactsService.allAvailableContacts.length;

              return Semantics(
                label: hasPerm
                    ? 'Status sinkronisasi: $totalCount kontak terhubung dari buku telepon HP. Ketuk dua kali tombol di kanan untuk sinkronkan ulang.'
                    : 'Akses kontak belum diizinkan. Ketuk untuk menyinkronkan kontak dari HP.',
                child: Container(
                  margin: const EdgeInsets.only(bottom: 14),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: hasPerm ? const Color(0xFF81C784) : AppColors.lightBlueBorder,
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: (hasPerm ? const Color(0xFF2E7D32) : AppColors.primaryBlue).withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          hasPerm ? Icons.contact_phone_rounded : Icons.perm_contact_calendar_rounded,
                          color: hasPerm ? const Color(0xFF2E7D32) : AppColors.primaryBlue,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              hasPerm ? 'Buku Kontak HP Terhubung' : 'Sinkronisasi Kontak HP',
                              style: TextStyle(
                                color: hasPerm ? const Color(0xFF1B5E20) : AppColors.primaryBlue,
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              hasPerm
                                  ? '$totalCount kontak siap dihubungi'
                                  : 'Izinkan akses untuk memuat nomor keluarga',
                              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: hasPerm ? const Color(0xFFE8F5E9) : AppColors.primaryBlue,
                          foregroundColor: hasPerm ? const Color(0xFF2E7D32) : Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: isSyncing
                            ? null
                            : () async {
                                controller.ttsService.speak('Menyinkronkan kontak dari buku telepon...', isUrgent: true);
                                final granted = await contactsService.requestContactsPermission();
                                final count = contactsService.allAvailableContacts.length;
                                if (granted) {
                                  controller.ttsService.speak(
                                    'Sinkronisasi selesai. Berhasil memuat $count kontak dari ponsel Anda.',
                                    isUrgent: true,
                                  );
                                } else {
                                  controller.ttsService.speak(
                                    'Izin akses kontak belum diberikan di pengaturan ponsel.',
                                    isUrgent: true,
                                  );
                                }
                              },
                        icon: isSyncing
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.sync_rounded, size: 16),
                        label: Text(
                          isSyncing ? 'Memuat...' : (hasPerm ? 'Sinkron' : 'Hubungkan'),
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
            const SizedBox(height: 16),

            // ================= 1. TOMBOL PENCARIAN KONTAK VIA SUARA =================
            Obx(() {
              final isListening = controller.isContactListening.value;
              final hasQuery = controller.contactSearchQuery.value.isNotEmpty;

              return Semantics(
                label: isListening
                    ? 'Mikrofon sedang mendengarkan. Silakan sebutkan nama kontak yang ingin dihubungi.'
                    : 'Cari Kontak dengan Suara. Ketuk dua kali lalu sebutkan nama orang terdekat atau keluarga yang ingin dihubungi.',
                button: true,
                child: Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isListening
                          ? [const Color(0xFF1B5E20), const Color(0xFF2E7D32)]
                          : [AppColors.primaryBlue, const Color(0xFF1565C0)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: (isListening ? Colors.green : AppColors.primaryBlue).withValues(alpha: 0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: () => controller.startContactVoiceSearch(),
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                isListening ? Icons.mic_rounded : Icons.mic_none_rounded,
                                color: Colors.white,
                                size: 32,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    isListening
                                        ? 'Mendengarkan...'
                                        : (hasQuery
                                            ? 'Cari Lagi via Suara'
                                            : 'Cari Kontak via Suara'),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    isListening
                                        ? 'Sebutkan nama kontak sekarang...'
                                        : (hasQuery
                                            ? 'Ucapan: "${controller.contactSearchQuery.value}"'
                                            : 'Ketuk lalu sebut nama (e.g. "Ibu")'),
                                    style: TextStyle(
                                      color: Colors.white.withValues(alpha: 0.9),
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (controller.hasContactSearched.value)
                              IconButton(
                                tooltip: 'Reset pencarian',
                                icon: const Icon(Icons.close_rounded, color: Colors.white, size: 26),
                                onPressed: () => controller.resetContactSearch(),
                              )
                            else
                              const Icon(Icons.touch_app_rounded, color: Colors.white70, size: 24),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }),

            // Input Pencarian Teks / Nomor (Alternatif fleksibel selain suara)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.lightBlueBorder),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: TextField(
                controller: controller.contactTextController,
                onChanged: (val) => controller.searchContactsByText(val),
                decoration: InputDecoration(
                  hintText: 'Ketik nama atau nomor kontak...',
                  hintStyle: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
                  prefixIcon: const Icon(Icons.search_rounded, color: AppColors.primaryBlue),
                  suffixIcon: Obx(() {
                    if (controller.contactSearchQuery.value.isEmpty) {
                      return const SizedBox.shrink();
                    }
                    return IconButton(
                      icon: const Icon(Icons.clear_rounded, color: Colors.grey),
                      onPressed: () => controller.resetContactSearch(),
                    );
                  }),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
              ),
            ),

            // ================= 2. HASIL PENCARIAN SUARA / TEKS (JIKA ADA PENCARIAN) =================
            Obx(() {
              if (!controller.hasContactSearched.value) {
                return const SizedBox.shrink();
              }

              final results = controller.contactSearchResults;
              if (results.isEmpty) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 20),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF3E0),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFFFFB74D), width: 1.5),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.search_off_rounded, color: Color(0xFFE65100), size: 40),
                      const SizedBox(height: 10),
                      Text(
                        'Kontak "${controller.contactSearchQuery.value}" Tidak Ditemukan',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Color(0xFFE65100),
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Silakan ketuk tombol mikrofon di atas untuk menyebutkan nama lain, atau minta keluarga menambahkan nomor baru.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Color(0xFF5D4037), fontSize: 13),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFE65100),
                          side: const BorderSide(color: Color(0xFFE65100)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: () => controller.resetContactSearch(),
                        icon: const Icon(Icons.refresh_rounded, size: 18),
                        label: const Text('Tampilkan Semua Kontak'),
                      ),
                    ],
                  ),
                );
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Hasil Pencarian (${results.length} ditemukan)',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () => controller.resetContactSearch(),
                        icon: const Icon(Icons.close_rounded, size: 16),
                        label: const Text('Tutup', style: TextStyle(fontSize: 13)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ...results.map((contact) => _buildFoundContactCard(context, contact)),
                  const Divider(height: 32, thickness: 1.2),
                ],
              );
            }),

            // Daftar Kontak Tersinkronisasi
            Obx(() {
              final isSyncing = contactsService.isSyncingDeviceContacts.value;
              final list = contactsService.allAvailableContacts;

              if (isSyncing) {
                return Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.lightBlueBorder),
                  ),
                  child: const Column(
                    children: [
                      CircularProgressIndicator(strokeWidth: 3),
                      SizedBox(height: 16),
                      Text(
                        'Menyinkronkan Buku Kontak HP...',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primaryBlue,
                        ),
                      ),
                      SizedBox(height: 6),
                      Text(
                        'Membaca nomor keluarga dan orang terdekat dari ponsel',
                        style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                );
              }

              if (list.isEmpty) {
                return Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.lightBlueBorder),
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 72,
                        height: 72,
                        decoration: const BoxDecoration(
                          color: AppColors.lightBlue,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.sync_problem_rounded, color: AppColors.primaryBlue, size: 38),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Belum Ada Kontak yang Dimuat',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'NetraVision membaca kontak keluarga langsung dari buku telepon ponsel Anda. Ketuk tombol di bawah untuk menyinkronkan kontak HP secara otomatis.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 14,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryBlue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          onPressed: () async {
                            controller.ttsService.speak('Menyinkronkan kontak dari buku telepon...', isUrgent: true);
                            final granted = await contactsService.requestContactsPermission();
                            if (granted) {
                              controller.ttsService.speak(
                                'Sinkronisasi berhasil. Berhasil memuat ${contactsService.allAvailableContacts.length} kontak.',
                                isUrgent: true,
                              );
                            } else {
                              controller.ttsService.speak(
                                'Izin akses kontak ponsel belum diberikan.',
                                isUrgent: true,
                              );
                            }
                          },
                          icon: const Icon(Icons.sync_rounded, size: 22),
                          label: const Text(
                            'Izinkan & Sinkronkan Kontak HP',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Kontak WhatsApp HP (${list.length})',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const Row(
                          children: [
                            Icon(Icons.check_circle_rounded, color: AppColors.successGreen, size: 16),
                            SizedBox(width: 4),
                            Text(
                              'Khusus WhatsApp',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: AppColors.successGreen,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  ...list.map((contact) {
                    return Obx(() {
                      final isCardSelected = controller.selectedContactActionKey.value == 'card_${contact.id}';
                      final isDeviceContact = contact.id.startsWith('device_');

                      return Card(
                        elevation: isCardSelected ? 4 : 2,
                        margin: const EdgeInsets.only(bottom: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: isCardSelected
                              ? const BorderSide(color: AppColors.primaryBlue, width: 2.5)
                              : BorderSide.none,
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () => controller.handleContactCardTap(contact),
                          child: Semantics(
                            label: 'Kontak ${contact.name}, ${contact.relationship}, nomor ${contact.phoneNumber}. ${isCardSelected ? "Sedang dipilih. Ketuk dua kali untuk membuka menu pilihan panggilan." : "Ketuk dua kali untuk mendengar info dan membuka menu pilihan."}',
                            hint: 'Ketuk dua kali untuk membuka pilihan panggilan',
                            button: true,
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              contact.name,
                                              style: const TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold,
                                                color: AppColors.textPrimary,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              '${contact.relationship} • ${contact.phoneNumber}',
                                              style: const TextStyle(
                                                color: AppColors.textSecondary,
                                                fontSize: 14,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (!isDeviceContact)
                                        Obx(() {
                                          final isDeleteSelected =
                                              controller.selectedContactActionKey.value == 'delete_${contact.id}';
                                          return Semantics(
                                            label: 'Hapus kontak ${contact.name}. ${isDeleteSelected ? "Sedang dipilih. Ketuk dua kali untuk menghapus kontak." : "Ketuk dua kali untuk konfirmasi hapus."}',
                                            hint: isDeleteSelected ? 'Ketuk dua kali untuk menghapus' : 'Ketuk dua kali untuk konfirmasi hapus',
                                            button: true,
                                            child: IconButton(
                                              tooltip: 'Hapus kontak',
                                              icon: Icon(
                                                Icons.delete_outline_rounded,
                                                color: isDeleteSelected ? AppColors.emergencyRed : Colors.grey,
                                                size: isDeleteSelected ? 28 : 24,
                                              ),
                                              onPressed: () => controller.handleDeleteContactTap(contact),
                                            ),
                                          );
                                        }),
                                    ],
                                  ),
                                  const SizedBox(height: 14),

                                  // 3 Tombol Aksi Langsung: 1. Telepon Seluler (Langsung), 2. Telepon WA, 3. Chat
                                  Row(
                                    children: [
                                      // 1. Telepon Seluler (Panggilan Langsung Tanpa Chat)
                                      Expanded(
                                        flex: 4,
                                        child: Obx(() {
                                          final isPhoneSelected =
                                              controller.selectedContactActionKey.value == 'phone_${contact.id}';
                                          return Semantics(
                                            label: 'Panggil ${contact.name} via Telepon Seluler langsung tanpa chat. ${isPhoneSelected ? "Sedang dipilih. Ketuk dua kali untuk memanggil langsung." : "Ketuk dua kali untuk mendengar penjelasan dan memanggil."}',
                                            hint: isPhoneSelected ? 'Ketuk dua kali untuk memanggil langsung' : 'Ketuk dua kali untuk mendengar penjelasan',
                                            button: true,
                                            child: ElevatedButton.icon(
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: AppColors.primaryBlue,
                                                foregroundColor: Colors.white,
                                                shape: RoundedRectangleBorder(
                                                  borderRadius: BorderRadius.circular(12),
                                                  side: isPhoneSelected
                                                      ? const BorderSide(color: Colors.white, width: 2.5)
                                                      : BorderSide.none,
                                                ),
                                                padding: const EdgeInsets.symmetric(vertical: 12),
                                                elevation: isPhoneSelected ? 4 : 1,
                                              ),
                                              onPressed: () => controller.handleContactPhoneTap(contact),
                                              icon: const Icon(Icons.phone_rounded, size: 18),
                                              label: Text(
                                                isPhoneSelected ? 'Panggil' : 'Telepon',
                                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                              ),
                                            ),
                                          );
                                        }),
                                      ),
                                      const SizedBox(width: 8),

                                      // 2. VC WhatsApp (Video Call Langsung ke Keluarga)
                                      Expanded(
                                        flex: 4,
                                        child: Obx(() {
                                          final isWaSelected =
                                              controller.selectedContactActionKey.value == 'wa_voice_${contact.id}';
                                          return Semantics(
                                            label: 'Panggil ${contact.name} via Video Call WhatsApp langsung. ${isWaSelected ? "Sedang dipilih. Ketuk dua kali untuk memulai panggilan video." : "Ketuk dua kali untuk mendengar penjelasan dan memulai video call."}',
                                            hint: isWaSelected ? 'Ketuk dua kali untuk memulai video call' : 'Ketuk dua kali untuk mendengar penjelasan',
                                            button: true,
                                            child: ElevatedButton.icon(
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: const Color(0xFF25D366),
                                                foregroundColor: Colors.white,
                                                shape: RoundedRectangleBorder(
                                                  borderRadius: BorderRadius.circular(12),
                                                  side: isWaSelected
                                                      ? const BorderSide(color: Colors.white, width: 2.5)
                                                      : BorderSide.none,
                                                ),
                                                padding: const EdgeInsets.symmetric(vertical: 12),
                                                elevation: isWaSelected ? 4 : 1,
                                              ),
                                              onPressed: () => controller.handleContactWhatsAppVoiceTap(contact),
                                              icon: const Icon(Icons.videocam_rounded, size: 20),
                                              label: Text(
                                                isWaSelected ? 'Panggil VC' : 'VC WA',
                                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                              ),
                                            ),
                                          );
                                        }),
                                      ),
                                      const SizedBox(width: 8),

                                      // 3. Chat WhatsApp
                                      Expanded(
                                        flex: 3,
                                        child: Obx(() {
                                          final isChatSelected =
                                              controller.selectedContactActionKey.value == 'chat_${contact.id}';
                                          return Semantics(
                                            label: 'Kirim pesan WhatsApp ke ${contact.name}. ${isChatSelected ? "Sedang dipilih. Ketuk dua kali untuk membuka pesan." : "Ketuk dua kali untuk mendengar penjelasan dan membuka pesan."}',
                                            hint: isChatSelected ? 'Ketuk dua kali untuk membuka pesan' : 'Ketuk dua kali untuk mendengar penjelasan',
                                            button: true,
                                            child: ElevatedButton.icon(
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: const Color(0xFF128C7E),
                                                foregroundColor: Colors.white,
                                                shape: RoundedRectangleBorder(
                                                  borderRadius: BorderRadius.circular(12),
                                                  side: isChatSelected
                                                      ? const BorderSide(color: Colors.white, width: 2.5)
                                                      : BorderSide.none,
                                                ),
                                                padding: const EdgeInsets.symmetric(vertical: 12),
                                                elevation: isChatSelected ? 4 : 1,
                                              ),
                                              onPressed: () => controller.handleContactChatTap(contact),
                                              icon: const Icon(Icons.chat_rounded, size: 18),
                                              label: Text(
                                                isChatSelected ? 'Buka Chat' : 'Chat',
                                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                              ),
                                            ),
                                          );
                                        }),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    });
                  }),
                ],
              );
            }),

            const SizedBox(height: 14),
            // Tombol Sinkronkan Buku Kontak HP
            Obx(() {
              final isSyncing = contactsService.isSyncingDeviceContacts.value;
              return Semantics(
                label: 'Sinkronkan kontak dari buku telepon ponsel. Ketuk dua kali untuk membaca kontak ponsel.',
                button: true,
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primaryBlue,
                      side: const BorderSide(color: AppColors.primaryBlue),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: isSyncing
                        ? null
                        : () async {
                            final granted = await contactsService.requestContactsPermission();
                            if (granted) {
                              controller.ttsService.speak(
                                'Buku kontak ponsel berhasil disinkronkan. Tersedia ${contactsService.deviceContacts.length} kontak tambahan.',
                                isUrgent: true,
                              );
                            } else {
                              controller.ttsService.speak(
                                'Izin akses kontak ponsel belum diberikan.',
                                isUrgent: true,
                              );
                            }
                          },
                    icon: isSyncing
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.sync_rounded, size: 20),
                    label: Text(
                      isSyncing ? 'Menyinkronkan Kontak HP...' : 'Sinkronkan Kontak dari Buku Telepon HP',
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildFoundContactCard(BuildContext context, TrustedContact contact) {
    return Card(
      elevation: 4,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: Color(0xFF25D366), width: 2.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: const Color(0xFF25D366).withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.person_rounded, color: Color(0xFF1B5E20), size: 30),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        contact.name,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${contact.relationship} • ${contact.phoneNumber}',
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // TOMBOL MEGA UTAMA: "Telepon WhatsApp Sekarang"
            Semantics(
              label: 'Telepon WhatsApp Sekarang ke ${contact.name}. Ketuk dua kali untuk langsung memulai panggilan video WhatsApp.',
              hint: 'Ketuk dua kali untuk menelepon WhatsApp',
              button: true,
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF25D366),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    elevation: 3,
                  ),
                  onPressed: () => controller.handleContactWhatsAppVoiceTap(contact),
                  icon: const Icon(Icons.videocam_rounded, size: 26),
                  label: const Text(
                    'Telepon WhatsApp Sekarang',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),

            // Tombol Sekunder: Telepon Seluler & Chat
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primaryBlue,
                      side: const BorderSide(color: AppColors.primaryBlue, width: 1.5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    onPressed: () => controller.handleContactPhoneTap(contact),
                    icon: const Icon(Icons.phone_rounded, size: 18),
                    label: const Text('Panggilan Seluler', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF128C7E),
                      side: const BorderSide(color: Color(0xFF128C7E), width: 1.5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    onPressed: () => controller.handleContactChatTap(contact),
                    icon: const Icon(Icons.chat_rounded, size: 18),
                    label: const Text('Chat WA', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showAddContactDialog(BuildContext context, ContactsService service) {
    controller.speakAddContactHelp();
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final relCtrl = TextEditingController(text: 'Keluarga');

    Get.defaultDialog(
      title: 'Tambah Kontak Keluarga / Tepercaya',
      titleStyle: const TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.bold,
        color: AppColors.primaryBlue,
      ),
      content: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(
                color: AppColors.lightBlue,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline_rounded, color: AppColors.primaryBlue, size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Bantu pengguna dengan mengetikkan nama dan nomor WhatsApp atau telepon yang aktif.',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.primaryBlue,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Semantics(
              label: 'Kolom teks: Nama Lengkap Kontak. Ketik nama orang terdekat atau keluarga.',
              textField: true,
              child: TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Nama Lengkap Kontak',
                  hintText: 'Misal: Ibu Ani, Kak Budi',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person_rounded),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Semantics(
              label: 'Kolom teks: Nomor Telepon atau WhatsApp. Masukkan nomor kontak aktif.',
              textField: true,
              child: TextField(
                controller: phoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Nomor Telepon / WhatsApp',
                  hintText: 'Misal: 081234567890',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.phone_rounded),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Semantics(
              label: 'Kolom teks: Hubungan keluarga atau kerabat.',
              textField: true,
              child: TextField(
                controller: relCtrl,
                decoration: const InputDecoration(
                  labelText: 'Hubungan',
                  hintText: 'Misal: Keluarga, Wali, Teman',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.favorite_rounded),
                ),
              ),
            ),
          ],
        ),
      ),
      textConfirm: 'Simpan Kontak',
      textCancel: 'Batal',
      confirmTextColor: Colors.white,
      buttonColor: AppColors.primaryBlue,
      onConfirm: () {
        if (nameCtrl.text.trim().isNotEmpty && phoneCtrl.text.trim().isNotEmpty) {
          final newContact = TrustedContact(
            id: 'contact_${DateTime.now().millisecondsSinceEpoch}',
            name: nameCtrl.text.trim(),
            phoneNumber: phoneCtrl.text.trim(),
            relationship: relCtrl.text.trim().isEmpty ? 'Keluarga' : relCtrl.text.trim(),
          );
          service.addContact(newContact);
          controller.ttsService.speak(
            'Kontak ${newContact.name} berhasil disimpan.',
            isUrgent: true,
          );
          Get.back();
        } else {
          controller.ttsService.speak(
            'Nama dan nomor telepon harus diisi.',
            isUrgent: true,
          );
        }
      },
    );
  }
}
