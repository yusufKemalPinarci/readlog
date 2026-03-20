import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import '../../../shared/utils/image_helper.dart';

import '../application/profile_providers.dart';
import '../../../shared/services/profile_image_storage_service.dart';
import '../../../shared/widgets/book_scaffold.dart';
import '../../../shared/services/permission_service.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _usernameCtrl;
  final ImagePicker _imagePicker = ImagePicker();
  final ProfileImageStorageService _imageService = ProfileImageStorageService();
  bool _isSaving = false;
  bool _controllersInitialized = false;
  File? _selectedImage;
  String? _currentImagePath;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController();
    _usernameCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _usernameCtrl.dispose();
    super.dispose();
  }



  Future<void> _pickImage(ImageSource source) async {
    bool hasPermission = false;
    if (source == ImageSource.camera) {
      hasPermission = await PermissionService.requestCameraPermission(context);
    } else {
      hasPermission = await PermissionService.requestPhotoLibraryPermission(context);
    }

    if (!hasPermission) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Resim seçmek için izin gerekli.')),
        );
      }
      return;
    }

    try {
      final pickedFile = await _imagePicker.pickImage(source: source, imageQuality: 80);
      if (pickedFile != null) {
        await _cropImage(pickedFile.path);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Resim seçilirken hata oluştu: $e')),
        );
      }
    }
  }

  Future<void> _cropImage(String sourcePath) async {
    final croppedPath = await ImageHelper.cropImage(
      context: context,
      sourcePath: sourcePath,
      aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
      lockAspectRatio: true,
    );

    if (croppedPath != null) {
      setState(() {
        _selectedImage = File(croppedPath);
        _currentImagePath = null;
      });
    }
  }

  Future<void> _showImageSourceDialog() async {
    await showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded),
              title: const Text('Kameradan Çek'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded),
              title: const Text('Galeriden Seç'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
            if (_currentImagePath != null || _selectedImage != null)
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text('Resmi Kaldır', style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(context);
                  setState(() {
                    _selectedImage = null;
                    _currentImagePath = null;
                  });
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty || _usernameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lütfen tüm alanları doldurun.')),
      );
      return;
    }

    setState(() => _isSaving = true);

    final profileAsync = ref.read(profileProvider);
    await profileAsync.when(
      data: (current) async {
        // Resmi kaydet
        String? savedImagePath;
        if (_selectedImage != null) {
          savedImagePath = await _imageService.saveImage(current.id, _selectedImage!.path);
        } else if (_currentImagePath == null && current.avatarImagePath != null) {
          // Eğer resim kaldırıldıysa, eski resmi sil
          await _imageService.deleteImage(current.id);
        } else {
          // Resim değişmediyse mevcut yolu kullan
          savedImagePath = current.avatarImagePath;
        }

        final updated = current.copyWith(
          name: _nameCtrl.text.trim(),
          username: _usernameCtrl.text.trim().replaceFirst('@', ''),
          avatarImagePath: savedImagePath,
        );
        await ref.read(profileRepositoryProvider).update(updated);
        ref.invalidate(profileProvider);
      },
      loading: () async {},
      error: (_, __) async {},
    );

    if (!mounted) return;
    setState(() => _isSaving = false);
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(profileProvider);

    return BookScaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: const Text('Profil Düzenle'),
      ),
      body: profileAsync.when(
        data: (profile) {
          // Controller'ları sadece bir kez initialize et
          if (!_controllersInitialized) {
            _nameCtrl.text = profile.name;
            _usernameCtrl.text = profile.username;
            _currentImagePath = profile.avatarImagePath;
            if (_currentImagePath != null) {
              final file = File(_currentImagePath!);
              if (file.existsSync()) {
                _selectedImage = file;
              }
            }
            _controllersInitialized = true;
          }
          
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                const SizedBox(height: 24),
                GestureDetector(
                  onTap: _showImageSourceDialog,
                  child: Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      CircleAvatar(
                        radius: 60,
                        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                        child: _selectedImage != null
                            ? ClipOval(
                                child: Image.file(
                                  _selectedImage!,
                                  width: 120,
                                  height: 120,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Icon(
                                      Icons.person,
                                      size: 60,
                                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                                    );
                                  },
                                ),
                              )
                            : _currentImagePath != null
                                ? ClipOval(
                                    child: Image.file(
                                      File(_currentImagePath!),
                                      width: 120,
                                      height: 120,
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) {
                                        return Icon(
                                          Icons.person,
                                          size: 60,
                                          color: Theme.of(context).colorScheme.onPrimaryContainer,
                                        );
                                      },
                                    ),
                                  )
                                : Icon(
                                    Icons.person,
                                    size: 60,
                                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                                  ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.camera_alt,
                          size: 20,
                          color: Theme.of(context).colorScheme.onPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'AD SOYAD',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _nameCtrl,
                  decoration: InputDecoration(
                    hintText: 'Ad Soyad',
                    prefixIcon: const Icon(Icons.person_outline),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'KULLANICI ADI',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _usernameCtrl,
                  decoration: InputDecoration(
                    hintText: '@kullaniciadi',
                    prefixText: '@ ',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _isSaving ? null : _save,
                    style: FilledButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Text(
                            'Değişiklikleri Kaydet',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                          ),
                  ),
                ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Hata: $err')),
      ),
    );
  }
}

