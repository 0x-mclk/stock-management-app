import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../providers/product_provider.dart';
import '../models/product.dart';

class AddProductWithCameraScreen extends StatefulWidget {
  const AddProductWithCameraScreen({super.key});

  @override
  State<AddProductWithCameraScreen> createState() =>
      _AddProductWithCameraScreenState();
}

class _AddProductWithCameraScreenState
    extends State<AddProductWithCameraScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _barcodeController = TextEditingController();
  final TextEditingController _salePriceController = TextEditingController();
  final TextEditingController _purchasePriceController =
      TextEditingController();
  final TextEditingController _stockController = TextEditingController();
  final TextEditingController _minStockController = TextEditingController();

  MobileScannerController cameraController = MobileScannerController();
  bool _isFlashOn = false;
  bool _isCameraActive = true;
  bool _isExistingProduct = false; // Mevcut ürün mü kontrolü için

  @override
  void initState() {
    super.initState();
    // Kamerayı başlat
    WidgetsBinding.instance.addPostFrameCallback((_) {
      cameraController.start();
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _barcodeController.dispose();
    _salePriceController.dispose();
    _purchasePriceController.dispose();
    _stockController.dispose();
    _minStockController.dispose();
    cameraController.dispose();
    super.dispose();
  }

  void _onBarcodeDetected(BarcodeCapture capture) async {
    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isNotEmpty && _isCameraActive) {
      final String? code = barcodes.first.rawValue;
      if (code != null && code.isNotEmpty && _barcodeController.text != code) {
        setState(() {
          _barcodeController.text = code;
          _isCameraActive = false;
        });

        // Kamerayı durdur
        cameraController.stop();

        // Haptic feedback
        HapticFeedback.lightImpact();

        // Mevcut ürünü kontrol et
        final productProvider = context.read<ProductProvider>();
        final existingProducts = productProvider.products
            .where(
              (product) => product.barcode == code,
            )
            .toList();

        if (existingProducts.isNotEmpty) {
          final existingProduct = existingProducts.first;
          // Mevcut ürün bulundu, bilgilerini forma yükle
          setState(() {
            _isExistingProduct = true;
            _nameController.text = existingProduct.name;
            _salePriceController.text = existingProduct.salePrice.toString();
            _purchasePriceController.text =
                existingProduct.purchasePrice?.toString() ?? '';
            _stockController.text = existingProduct.stock.toString();
            _minStockController.text = existingProduct.minStockLevel.toString();
          });

          // Kullanıcıyı bilgilendir
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.info, color: Colors.white),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                        'Bu barkod zaten kayıtlı! Mevcut ürün bilgileri yüklendi: ${existingProduct.name}'),
                  ),
                ],
              ),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 3),
              behavior: SnackBarBehavior.floating,
              action: SnackBarAction(
                label: 'DÜZENLE',
                textColor: Colors.white,
                onPressed: () {
                  // Kullanıcı bilgileri düzenleyebilir
                },
              ),
            ),
          );
        } else {
          // Yeni barkod - başarı mesajı göster
          setState(() {
            _isExistingProduct = false;
            // Yeni ürün için formu temizle
            _nameController.clear();
            _salePriceController.clear();
            _purchasePriceController.clear();
            _stockController.clear();
            _minStockController.text = '5';
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white),
                  const SizedBox(width: 8),
                  Expanded(child: Text('Barkod okundu: $code')),
                ],
              ),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
  }

  void _toggleFlash() {
    setState(() {
      _isFlashOn = !_isFlashOn;
    });
    cameraController.toggleTorch();
  }

  void _restartCamera() {
    setState(() {
      _isCameraActive = true;
      _isExistingProduct = false; // Yeni tarama başlayınca sıfırla
      _barcodeController.clear();
      // Formu da temizle
      _nameController.clear();
      _salePriceController.clear();
      _purchasePriceController.clear();
      _stockController.clear();
      _minStockController.text = '5';
    });
    cameraController.start();
  }

  void _onBarcodeManuallyEntered(String value) async {
    if (value.trim().isNotEmpty && value.trim().length >= 8) {
      // Manuel girilen barkod için mevcut ürünü kontrol et
      final productProvider = context.read<ProductProvider>();
      final existingProducts = productProvider.products
          .where(
            (product) => product.barcode == value.trim(),
          )
          .toList();

      if (existingProducts.isNotEmpty) {
        final existingProduct = existingProducts.first;
        // Mevcut ürün bulundu, bilgilerini forma yükle
        setState(() {
          _isExistingProduct = true;
          _nameController.text = existingProduct.name;
          _salePriceController.text = existingProduct.salePrice.toString();
          _purchasePriceController.text =
              existingProduct.purchasePrice?.toString() ?? '';
          _stockController.text = existingProduct.stock.toString();
          _minStockController.text = existingProduct.minStockLevel.toString();
        });

        // Kullanıcıyı bilgilendir
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.info, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                      'Bu barkod zaten kayıtlı! Mevcut ürün: ${existingProduct.name}'),
                ),
              ],
            ),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        // Yeni barkod
        setState(() {
          _isExistingProduct = false;
        });
      }
    } else if (value.trim().isEmpty) {
      // Barkod temizlenirse formu sıfırla
      setState(() {
        _isExistingProduct = false;
        _nameController.clear();
        _salePriceController.clear();
        _purchasePriceController.clear();
        _stockController.clear();
        _minStockController.text = '5';
      });
    }
  }

  void _saveProduct() async {
    if (_nameController.text.trim().isEmpty ||
        _barcodeController.text.trim().isEmpty ||
        _salePriceController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ürün adı, barkod ve satış fiyatı zorunludur'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      // Aynı barkodlu ürün var mı kontrol et
      final productProvider = context.read<ProductProvider>();
      final existingProducts = productProvider.products
          .where(
            (product) => product.barcode == _barcodeController.text.trim(),
          )
          .toList();

      if (existingProducts.isNotEmpty) {
        // Mevcut ürünü güncelle
        final existingProduct = existingProducts.first;
        final updatedProduct = Product(
          id: existingProduct.id, // Mevcut ID'yi koru
          name: _nameController.text.trim(),
          barcode: _barcodeController.text.trim(),
          salePrice: double.tryParse(_salePriceController.text) ?? 0.0,
          purchasePrice: _purchasePriceController.text.trim().isEmpty
              ? null
              : double.tryParse(_purchasePriceController.text),
          stock: int.tryParse(_stockController.text) ?? 0,
          description: null,
          category: null,
          minStock: int.tryParse(_minStockController.text) ?? 5,
        );

        await productProvider.updateProduct(updatedProduct);

        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Mevcut ürün başarıyla güncellendi'),
              backgroundColor: Colors.blue,
            ),
          );
        }
      } else {
        // Yeni ürün ekle
        final product = Product(
          name: _nameController.text.trim(),
          barcode: _barcodeController.text.trim(),
          salePrice: double.tryParse(_salePriceController.text) ?? 0.0,
          purchasePrice: _purchasePriceController.text.trim().isEmpty
              ? null
              : double.tryParse(_purchasePriceController.text),
          stock: int.tryParse(_stockController.text) ?? 0,
          description: null,
          category: null,
          minStock: int.tryParse(_minStockController.text) ?? 5,
        );

        await productProvider.addProduct(product);

        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Ürün başarıyla eklendi'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Hata: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isExistingProduct ? 'Ürün Düzenle' : 'Yeni Ürün Ekle'),
        actions: [
          TextButton(
            onPressed: _saveProduct,
            child: Text(
              _isExistingProduct ? 'GÜNCELLE' : 'KAYDET',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Kamera Bölümü (1/3)
          Expanded(
            flex: 1,
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.black,
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: _isCameraActive
                  ? Stack(
                      children: [
                        MobileScanner(
                          controller: cameraController,
                          onDetect: _onBarcodeDetected,
                        ),
                        // Kamera kontrolleri
                        Positioned(
                          top: 16,
                          right: 16,
                          child: Row(
                            children: [
                              // Flash toggle
                              IconButton(
                                onPressed: _toggleFlash,
                                icon: Icon(
                                  _isFlashOn ? Icons.flash_on : Icons.flash_off,
                                  color: Colors.white,
                                  size: 28,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Tarama rehberi
                        Center(
                          child: Container(
                            width: 250,
                            height: 150,
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: Colors.red,
                                width: 2,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Center(
                              child: Text(
                                'Barkodu bu alanın içine getirin',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  shadows: [
                                    Shadow(
                                      offset: Offset(1, 1),
                                      blurRadius: 3,
                                      color: Colors.black54,
                                    ),
                                  ],
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                        ),
                      ],
                    )
                  :
                  // Kamera durduğunda gösterilecek alan
                  Container(
                      color: Colors.grey.shade800,
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.check_circle,
                              color: Colors.green,
                              size: 64,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Barkod Okundu!',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _barcodeController.text,
                              style: TextStyle(
                                color: Colors.grey.shade300,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: _restartCamera,
                              child: const Text('Tekrar Tara'),
                            ),
                          ],
                        ),
                      ),
                    ),
            ),
          ),

          // Form Bölümü (2/3)
          Expanded(
            flex: 2,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Ürün Bilgileri',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Barkod (manuel veya kamera ile)
                  TextField(
                    controller: _barcodeController,
                    decoration: InputDecoration(
                      labelText: 'Barkod *',
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.qr_code),
                      suffixIcon: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _barcodeController.clear();
                              setState(() {
                                _isExistingProduct = false;
                              });
                            },
                            tooltip: 'Temizle',
                          ),
                          IconButton(
                            icon: const Icon(Icons.camera_alt),
                            onPressed: _restartCamera,
                            tooltip: 'Kamera ile Tara',
                          ),
                        ],
                      ),
                      hintText:
                          'Barkod numarasını yazın veya kamera ile tarayın',
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: _onBarcodeManuallyEntered,
                  ),
                  const SizedBox(height: 16),

                  // Ürün Adı
                  TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Ürün Adı *',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.shopping_bag),
                    ),
                    textCapitalization: TextCapitalization.words,
                  ),
                  const SizedBox(height: 16),

                  // Satış Fiyatı
                  TextField(
                    controller: _salePriceController,
                    decoration: const InputDecoration(
                      labelText: 'Satış Fiyatı (₺) *',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.attach_money),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 16),

                  // Alış Fiyatı
                  TextField(
                    controller: _purchasePriceController,
                    decoration: const InputDecoration(
                      labelText: 'Alış Fiyatı (₺)',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.money_off),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 16),

                  // Stok
                  TextField(
                    controller: _stockController,
                    decoration: const InputDecoration(
                      labelText: 'Stok Miktarı',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.inventory),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 16),

                  // Minimum Stok
                  TextField(
                    controller: _minStockController,
                    decoration: const InputDecoration(
                      labelText: 'Minimum Stok Seviyesi',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.warning),
                      hintText: '5',
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 24),

                  // Kaydet Butonu
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _saveProduct,
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            _isExistingProduct ? Colors.blue : Colors.green,
                        foregroundColor: Colors.white,
                      ),
                      child: Text(
                        _isExistingProduct ? 'ÜRÜNÜ GÜNCELLE' : 'ÜRÜNÜ KAYDET',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
