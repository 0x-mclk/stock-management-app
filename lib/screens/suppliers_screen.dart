import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/supplier_provider.dart';
import '../providers/purchase_provider.dart';

import '../models/supplier.dart';
import '../utils/currency_formatter.dart';
import '../utils/web_utils.dart';
import 'supplier_detail_screen.dart';

class SuppliersScreen extends StatefulWidget {
  const SuppliersScreen({super.key});

  @override
  State<SuppliersScreen> createState() => _SuppliersScreenState();
}

class _SuppliersScreenState extends State<SuppliersScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedFilter = 'all'; // all, debt, no_debt

  @override
  void initState() {
    super.initState();
    // Ensure suppliers are loaded when screen opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final supplierProvider =
          Provider.of<SupplierProvider>(context, listen: false);
      supplierProvider.loadSuppliers();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = WebBreakpoints.isDesktop(context);
    return Scaffold(
      appBar: isDesktop ? null : _buildMobileAppBar(),
      body: isDesktop ? _buildDesktopBody(context) : _buildMobileBody(),
      floatingActionButton: isDesktop
          ? null
          : FloatingActionButton(
              heroTag: 'suppliers_fab',
              onPressed: () => _showAddSupplierDialog(),
              child: const Icon(Icons.business),
            ),
    );
  }

  PreferredSizeWidget _buildMobileAppBar() {
    return AppBar(
      title: const Text('Tedarikçi Yönetimi'),
      actions: [
        IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () => _showFilterDialog()),
        IconButton(
            icon: const Icon(Icons.business),
            onPressed: () => _showAddSupplierDialog()),
      ],
    );
  }

  // ─── Desktop Body ───────────────────────────────────────────────────────────
  Widget _buildDesktopBody(BuildContext context) {
    return Consumer<SupplierProvider>(
      builder: (context, supplierProvider, _) {
        final all = supplierProvider.suppliers;
        final totalDebt =
            all.fold<double>(0, (sum, s) => sum + s.debt);
        final debtCount = all.where((s) => s.debt > 0).length;

        return WebPageWrapper(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Tedarikçi Yönetimi',
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.5,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Tedarikçilerinizi ve borçlarınızı takip edin',
                          style: TextStyle(fontSize: 13, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: () => _showAddSupplierDialog(),
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('Yeni Tedarikçi'),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Summary cards
              Row(
                children: [
                  _SummaryStatCard(
                    label: 'Toplam Tedarikçi',
                    value: '${all.length}',
                    icon: Icons.business_rounded,
                    color: Colors.blue,
                  ),
                  const SizedBox(width: 12),
                  _SummaryStatCard(
                    label: 'Borçlu Tedarikçi',
                    value: '$debtCount',
                    icon: Icons.warning_amber_rounded,
                    color: Colors.orange,
                  ),
                  const SizedBox(width: 12),
                  _SummaryStatCard(
                    label: 'Toplam Borç',
                    value: CurrencyFormatter.formatWithSymbol(totalDebt),
                    icon: Icons.account_balance_rounded,
                    color: totalDebt > 0 ? Colors.red : Colors.green,
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Toolbar
              Row(
                children: [
                  SizedBox(
                    width: 320,
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Tedarikçi adı, telefon ara...',
                        prefixIcon: const Icon(Icons.search, size: 20),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _searchQuery = '');
                                },
                              )
                            : null,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        isDense: true,
                      ),
                      onChanged: (v) => setState(() => _searchQuery = v),
                    ),
                  ),
                  const SizedBox(width: 12),
                  _FilterChipRow(
                    selected: _selectedFilter,
                    onChanged: (v) => setState(() => _selectedFilter = v),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // DataTable
              Expanded(child: _buildSupplierDataTable(supplierProvider)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSupplierDataTable(SupplierProvider supplierProvider) {
    var suppliers = supplierProvider.suppliers
        .where((s) =>
            s.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            (s.phone?.contains(_searchQuery) ?? false))
        .toList();

    if (_selectedFilter == 'debt') {
      suppliers = suppliers.where((s) => s.debt > 0).toList();
    } else if (_selectedFilter == 'no_debt') {
      suppliers = suppliers.where((s) => s.debt == 0).toList();
    }

    if (suppliers.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.business_outlined,
                size: 56, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              _searchQuery.isEmpty
                  ? 'Henüz tedarikçi eklenmemiş'
                  : '"$_searchQuery" için sonuç yok',
              style: const TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SingleChildScrollView(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor:
                  WidgetStateProperty.all(Colors.grey.shade50),
              headingTextStyle: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: Colors.black87,
              ),
              dataTextStyle: const TextStyle(fontSize: 13),
              columnSpacing: 24,
              horizontalMargin: 20,
              columns: const [
                DataColumn(label: Text('Tedarikçi Adı')),
                DataColumn(label: Text('Telefon')),
                DataColumn(label: Text('E-posta')),
                DataColumn(label: Text('Borç'), numeric: true),
                DataColumn(label: Text('Toplam Alım'), numeric: true),
                DataColumn(label: Text('İşlemler')),
              ],
              rows: suppliers.map((s) {
                return DataRow(cells: [
                  DataCell(
                    Text(s.name,
                        style: const TextStyle(
                            fontWeight: FontWeight.w500)),
                    onTap: () => _openSupplierDetail(s),
                  ),
                  DataCell(Text(s.phone ?? '—')),
                  DataCell(Text(s.email ?? '—')),
                  DataCell(
                    Text(
                      CurrencyFormatter.formatWithSymbol(s.debt),
                      style: TextStyle(
                        color: s.debt > 0 ? Colors.red : Colors.green,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  DataCell(Text(CurrencyFormatter.formatWithSymbol(
                      s.totalPurchases))),
                  DataCell(Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.visibility_rounded,
                            size: 18, color: Colors.blue),
                        tooltip: 'Detay',
                        onPressed: () => _openSupplierDetail(s),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      const SizedBox(width: 12),
                      IconButton(
                        icon: const Icon(Icons.edit_rounded,
                            size: 18, color: Colors.grey),
                        tooltip: 'Düzenle',
                        onPressed: () => _showEditSupplierDialog(s),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      const SizedBox(width: 12),
                      IconButton(
                        icon: const Icon(Icons.delete_rounded,
                            size: 18, color: Colors.red),
                        tooltip: 'Sil',
                        onPressed: () => _showDeleteConfirmation(s),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  )),
                ]);
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }

  void _openSupplierDetail(Supplier supplier) {
    showWebPanel(
      context: context,
      child: SupplierDetailScreen(supplier: supplier),
      panelWidth: 720,
    );
  }

  // ─── Mobile Body ────────────────────────────────────────────────────────────
  Widget _buildMobileBody() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Tedarikçi adı, telefon ara...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onChanged: (v) => setState(() => _searchQuery = v),
              ),
              if (_selectedFilter != 'all')
                Container(
                  margin: const EdgeInsets.only(top: 8),
                  child: Chip(
                    label: Text(_getFilterName()),
                    onDeleted: () =>
                        setState(() => _selectedFilter = 'all'),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: Consumer<SupplierProvider>(
            builder: (context, supplierProvider, _) {
              var filtered = supplierProvider.suppliers
                  .where((s) =>
                      s.name
                          .toLowerCase()
                          .contains(_searchQuery.toLowerCase()) ||
                      (s.phone?.contains(_searchQuery) ?? false))
                  .toList();
              if (_selectedFilter == 'debt') {
                filtered = filtered.where((s) => s.debt > 0).toList();
              } else if (_selectedFilter == 'no_debt') {
                filtered = filtered.where((s) => s.debt == 0).toList();
              }
              if (filtered.isEmpty) {
                return const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.business_outlined,
                          size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text('Henüz tedarikçi bulunmuyor',
                          style:
                              TextStyle(fontSize: 18, color: Colors.grey)),
                      SizedBox(height: 8),
                      Text(
                          'Yeni tedarikçi eklemek için + butonuna dokunun',
                          style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: filtered.length,
                itemBuilder: (context, i) =>
                    _buildSupplierCard(filtered[i]),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSupplierCard(Supplier supplier) {
    final hasDebt = supplier.debt > 0;

    return Consumer<SupplierProvider>(
      builder: (context, supplierProvider, child) {
        // ✅ Artık Purchase tablosundan gelecek
        final totalPurchases = supplier.totalPurchases;

        return Card(
          margin:
              const EdgeInsets.only(bottom: 8), // Biraz artırıldı (6'dan 8'e)
          elevation: 2, // Hafif gölge eklendi
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: InkWell(
            onTap: () => _navigateToSupplierDetail(supplier),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: hasDebt
                      ? Colors.orange.withValues(alpha: 0.2)
                      : Colors.blue.withValues(alpha: 0.1),
                  width: 1,
                ),
              ),
              child: Padding(
                padding:
                    const EdgeInsets.all(14), // Biraz artırıldı (12'den 14'e)
                child: Column(
                  children: [
                    // Üst kısım: Avatar, isim, telefon ve menu
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 20, // Biraz büyütüldü (18'den 20'ye)
                          backgroundColor:
                              hasDebt ? Colors.orange : Colors.blue,
                          child: Text(
                            supplier.name.isNotEmpty
                                ? supplier.name[0].toUpperCase()
                                : '?',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16, // Biraz büyütüldü (14'ten 16'ya)
                            ),
                          ),
                        ),
                        const SizedBox(
                            width: 12), // Biraz artırıldı (8'den 12'ye)
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                supplier.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 17, // Biraz büyütüldü (14'ten 15'e)
                                  color: Colors.black87,
                                ),
                              ),
                              const SizedBox(
                                  height: 2), // Biraz artırıldı (1'den 2'ye)
                              Text(
                                'Tel: ${supplier.phone ?? "Belirtilmemiş"}',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize:
                                      12, // Biraz büyütüldü (11'den 12'ye)
                                ),
                              ),
                            ],
                          ),
                        ),
                        PopupMenuButton<String>(
                          onSelected: (value) {
                            switch (value) {
                              case 'view':
                                _navigateToSupplierDetail(supplier);
                                break;
                              case 'edit':
                                _showEditSupplierDialog(supplier);
                                break;
                              case 'payment_history':
                                _navigateToPaymentHistory(supplier);
                                break;
                              case 'purchase':
                                _showAddPurchase(supplier);
                                break;
                              case 'delete':
                                _showDeleteConfirmation(supplier);
                                break;
                            }
                          },
                          itemBuilder: (context) => [
                            const PopupMenuItem(
                              value: 'view',
                              child: Row(
                                children: [
                                  Icon(Icons.visibility),
                                  SizedBox(width: 8),
                                  Text('Detaylar'),
                                ],
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'edit',
                              child: Row(
                                children: [
                                  Icon(Icons.edit),
                                  SizedBox(width: 8),
                                  Text('Düzenle'),
                                ],
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'purchase',
                              child: Row(
                                children: [
                                  Icon(Icons.shopping_cart),
                                  SizedBox(width: 8),
                                  Text('Alışveriş Ekle'),
                                ],
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'payment_history',
                              child: Row(
                                children: [
                                  Icon(Icons.payment),
                                  SizedBox(width: 8),
                                  Text('Ödeme Geçmişi'),
                                ],
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'delete',
                              child: Row(
                                children: [
                                  Icon(Icons.delete, color: Colors.red),
                                  SizedBox(width: 8),
                                  Text('Sil',
                                      style: TextStyle(color: Colors.red)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),

                    // Alt kısım: Borç ve Toplam Alışveriş bilgileri - Yatay format
                    const SizedBox(height: 8), // Biraz artırıldı (6'dan 8'e)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          vertical: 8, horizontal: 4),
                      decoration: BoxDecoration(
                        color: Colors.grey.withValues(alpha: 0.03),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        children: [
                          // Borç bilgisi - Sol tarafa yaslanmış
                          if (hasDebt) ...[
                            Expanded(
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color:
                                          Colors.orange.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Icon(
                                      Icons.warning_amber_rounded,
                                      color: Colors.orange[700],
                                      size: 16,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Flexible(
                                    child: Text(
                                      'Borç: ${CurrencyFormatter.formatWithSymbol(supplier.debt)}',
                                      style: TextStyle(
                                        color: Colors.orange[700],
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],

                          // Toplam Alışveriş bilgisi - Ortadan başlayıp sağa doğru
                          Expanded(
                            child: Row(
                              mainAxisAlignment: hasDebt
                                  ? MainAxisAlignment.center
                                  : MainAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: Colors.green.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Icon(
                                    Icons.shopping_cart_outlined,
                                    color: Colors.green[700],
                                    size: 16,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    'Alışveriş: ${CurrencyFormatter.formatWithSymbol(totalPurchases)}',
                                    style: TextStyle(
                                      color: Colors.green[700],
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ],
                            ),
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
      },
    );
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Filtrele'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<String>(
              title: const Text('Tümü'),
              value: 'all',
              groupValue: _selectedFilter,
              onChanged: (value) {
                setState(() {
                  _selectedFilter = value!;
                });
                Navigator.pop(context);
              },
            ),
            RadioListTile<String>(
              title: const Text('Borçlu Olanlar'),
              value: 'debt',
              groupValue: _selectedFilter,
              onChanged: (value) {
                setState(() {
                  _selectedFilter = value!;
                });
                Navigator.pop(context);
              },
            ),
            RadioListTile<String>(
              title: const Text('Borcu Olmayanlar'),
              value: 'no_debt',
              groupValue: _selectedFilter,
              onChanged: (value) {
                setState(() {
                  _selectedFilter = value!;
                });
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  String _getFilterName() {
    switch (_selectedFilter) {
      case 'debt':
        return 'Borçlu Olanlar';
      case 'no_debt':
        return 'Borcu Olmayanlar';
      default:
        return 'Tümü';
    }
  }

  void _showAddSupplierDialog() {
    _showSupplierDialog();
  }

  void _showEditSupplierDialog(Supplier supplier) {
    _showSupplierDialog(supplier: supplier);
  }

  void _showSupplierDialog({Supplier? supplier}) {
    final isEditing = supplier != null;
    final nameController = TextEditingController(text: supplier?.name ?? '');
    final phoneController = TextEditingController(text: supplier?.phone ?? '');
    final addressController =
        TextEditingController(text: supplier?.address ?? '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isEditing ? 'Tedarikçi Düzenle' : 'Yeni Tedarikçi Ekle'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Tedarikçi Adı *',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: phoneController,
                decoration: const InputDecoration(
                  labelText: 'Telefon',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: addressController,
                decoration: const InputDecoration(
                  labelText: 'Adres',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Tedarikçi adı zorunludur'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              final newSupplier = Supplier(
                id: supplier?.id, // Yeni tedarikçi için null olacak
                name: nameController.text.trim(),
                phone: phoneController.text.trim().isEmpty
                    ? null
                    : phoneController.text.trim(),
                email: null,
                address: addressController.text.trim().isEmpty
                    ? null
                    : addressController.text.trim(),
                notes: null,
                debt: isEditing ? supplier.debt : 0.0,
                totalPurchases: isEditing ? supplier.totalPurchases : 0.0,
                monthlyPurchases: isEditing ? supplier.monthlyPurchases : 0.0,
                yearlyPurchases: isEditing ? supplier.yearlyPurchases : 0.0,
                storeId: '', // ✅ Provider otomatik atayacak
              );

              try {
                if (isEditing) {
                  await context.read<SupplierProvider>().updateSupplier(newSupplier);
                } else {
                  await context.read<SupplierProvider>().addSupplier(newSupplier);
                }
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(isEditing
                          ? 'Tedarikçi güncellendi'
                          : 'Tedarikçi eklendi'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Hata: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: Text(isEditing ? 'Güncelle' : 'Ekle'),
          ),
        ],
      ),
    );
  }

  void _navigateToSupplierDetail(Supplier supplier) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => SupplierDetailScreen(supplier: supplier),
      ),
    );
  }

  void _navigateToPaymentHistory(Supplier supplier) {
    // Supplier ID kontrolü
    if (supplier.id == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tedarikçi bilgisi hatalı. Lütfen sayfayı yenileyin.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Tedarikçi detay sayfasına yönlendir ve ödeme geçmişi tabını aç
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => SupplierDetailScreen(
          supplier: supplier,
          initialTabIndex:
              2, // Ödeme geçmişi tabının index'i (0: Genel, 1: Alışveriş, 2: Ödeme)
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
  }

  void _savePurchase(Supplier supplier, String productName, double amount,
      DateTime date) async {
    // Supplier ID kontrolü
    if (supplier.id == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tedarikçi bilgisi hatalı. Alışveriş kaydedilemedi.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      // ✅ YENİ YÖNTEM: Purchase Provider kullan (Sale değil!)
      final purchaseProvider = context.read<PurchaseProvider>();
      final storeId = supplier.storeId; // Supplier'ın kendi store ID'si

      if (storeId.isEmpty) {
        throw Exception('Store ID bulunamadı');
      }

      final purchaseId = await purchaseProvider.createPurchase(
        supplierId: supplier.id!,
        storeId: storeId,
        productName: productName,
        amount: amount,
        purchaseDate: date,
        paymentMethod: 'cash',
        notes: 'Tedarikçi alımı',
      );

      if (purchaseId != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Alım kaydedildi: ${amount.toStringAsFixed(2)} TL'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        throw Exception('Alım kaydedilemedi');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Hata: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }

    // SalesProvider'a ekle
    // ✅ Purchase kaydedildi, Sale sistemine dokunmadık

    // Başarı mesajı göster
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${supplier.name} - $productName alışverişi kaydedildi'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _showAddPurchase(Supplier supplier) {
    final amountController = TextEditingController();
    final productNameController = TextEditingController();
    DateTime selectedDate = DateTime.now();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(
            '${supplier.name} - Alışveriş Ekle',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Ürün Adı
                TextField(
                  controller: productNameController,
                  decoration: const InputDecoration(
                    labelText: 'Ürün Adı',
                    border: OutlineInputBorder(),
                    hintText: 'Örn: Patates, Domates vb.',
                  ),
                ),
                const SizedBox(height: 16),

                // Toplam Tutar
                TextField(
                  controller: amountController,
                  decoration: const InputDecoration(
                    labelText: 'Toplam Tutar',
                    border: OutlineInputBorder(),
                    prefixText: '₺',
                    hintText: '0.00',
                  ),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                ),
                const SizedBox(height: 16),

                // Tarih Seçimi
                InkWell(
                  onTap: () async {
                    final DateTime? picked = await showDatePicker(
                      context: context,
                      initialDate: selectedDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null && picked != selectedDate) {
                      setState(() {
                        selectedDate = picked;
                      });
                    }
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today, color: Colors.grey),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Alım Tarihi',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                            Text(
                              _formatDate(selectedDate),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                        const Icon(Icons.arrow_drop_down, color: Colors.grey),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Geçmiş tarihli alışverişler de eklenebilir',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('İptal'),
            ),
            ElevatedButton(
              onPressed: () {
                final productName = productNameController.text.trim();
                final amountText = amountController.text.trim();

                // Validasyon
                if (productName.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Ürün adı girilmelidir')),
                  );
                  return;
                }

                final amount = double.tryParse(amountText) ?? 0;
                if (amount <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Geçerli bir tutar girilmelidir')),
                  );
                  return;
                }

                // Alışverişi kaydet
                _savePurchase(supplier, productName, amount, selectedDate);
                Navigator.pop(context);
              },
              child: const Text('Kaydet'),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteConfirmation(Supplier supplier) {
    // Supplier ID kontrolü
    if (supplier.id == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tedarikçi bilgisi hatalı. Lütfen sayfayı yenileyin.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tedarikçi Sil'),
        content: Text(
            '${supplier.name} tedarikçisini silmek istediğinizden emin misiniz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () {
              context.read<SupplierProvider>().removeSupplier(supplier.id!);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Tedarikçi silindi'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Web-only helper widgets
// ─────────────────────────────────────────────
class _SummaryStatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _SummaryStatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Colors.grey.shade200),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: color,
                    ),
                  ),
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
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

class _FilterChipRow extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onChanged;

  const _FilterChipRow(
      {required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    const filters = [
      ('all', 'Tümü'),
      ('debt', 'Borçlu'),
      ('no_debt', 'Borçsuz'),
    ];
    return Row(
      children: filters.map((f) {
        final isSelected = selected == f.$1;
        return Padding(
          padding: const EdgeInsets.only(right: 8),
          child: FilterChip(
            label: Text(f.$2),
            selected: isSelected,
            onSelected: (_) => onChanged(f.$1),
          ),
        );
      }).toList(),
    );
  }
}
