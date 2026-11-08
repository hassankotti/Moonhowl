import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:howl_core/howl_core.dart';
import 'package:image_picker/image_picker.dart';

import '../../l10n.dart';
import '../../main.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// Create or edit the local profile. No account, nothing leaves the phone
/// except what other players in the room see.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, this.firstRun = false});

  final bool firstRun;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _name = TextEditingController();
  int _color = Palette.avatarColors.first.toARGB32();
  String _icon = Palette.avatarIcons.first;
  String? _photo;
  bool _loaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loaded) return;
    _loaded = true;
    final p = AppScope.read(context).profile;
    if (p != null) {
      _name.text = p.name;
      _color = p.color;
      _icon = p.icon;
      _photo = p.photo;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Profile get _profile => Profile(name: _name.text.trim(), color: _color, icon: _icon, photo: _photo);

  Future<void> _pickPhoto() async {
    try {
      final file = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 160,
        maxHeight: 160,
        imageQuality: 70,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      final b64 = base64Encode(bytes);
      if (b64.length > Profile.maxPhotoLength) return;
      setState(() => _photo = b64);
    } catch (_) {}
  }

  Future<void> _save() async {
    final s = S.of(context);
    if (_name.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s.t('nameRequired'))));
      return;
    }
    await AppScope.read(context).saveProfile(_profile);
    if (mounted && !widget.firstRun) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.firstRun ? s.t('app') : s.t('editProfile')),
        automaticallyImplyLeading: !widget.firstRun,
        actions: [if (widget.firstRun) const _LanguageButton()],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            if (widget.firstRun) ...[
              Text(s.t('tagline'), textAlign: TextAlign.center, style: const TextStyle(color: Palette.mist, fontSize: 16)),
              const SizedBox(height: 20),
            ],
            Center(child: AvatarView(profile: _profile.copyWith(name: _name.text.isEmpty ? '?' : null), size: 112)),
            const SizedBox(height: 20),
            TextField(
              controller: _name,
              maxLength: Profile.maxNameLength,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
              decoration: InputDecoration(hintText: s.t('name'), counterText: ''),
              onChanged: (_) => setState(() {}),
            ),
            SectionTitle(s.t('avatar')),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                for (final icon in Palette.avatarIcons)
                  _Pick(
                    selected: _photo == null && icon == _icon,
                    onTap: () => setState(() {
                      _icon = icon;
                      _photo = null;
                    }),
                    child: Text(icon, style: const TextStyle(fontSize: 26)),
                  ),
              ],
            ),
            SectionTitle(s.t('color')),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              alignment: WrapAlignment.center,
              children: [
                for (final c in Palette.avatarColors)
                  GestureDetector(
                    onTap: () => setState(() => _color = c.toARGB32()),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: c,
                        shape: BoxShape.circle,
                        border: Border.all(color: _color == c.toARGB32() ? Colors.white : Colors.transparent, width: 3),
                      ),
                    ),
                  ),
              ],
            ),
            SectionTitle(s.t('photo')),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickPhoto,
                    icon: const Icon(Icons.photo_library_outlined),
                    label: Text(s.t('pickPhoto')),
                  ),
                ),
                if (_photo != null) ...[
                  const SizedBox(width: 10),
                  IconButton.filledTonal(
                    onPressed: () => setState(() => _photo = null),
                    icon: const Icon(Icons.delete_outline),
                    tooltip: s.t('removePhoto'),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 28),
            FilledButton(onPressed: _save, child: Text(s.t('save'))),
          ],
        ),
      ),
    );
  }
}

class _Pick extends StatelessWidget {
  const _Pick({required this.selected, required this.onTap, required this.child});

  final bool selected;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: 52,
          height: 52,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? Palette.surfaceHigh : Palette.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: selected ? Palette.moon : Colors.transparent, width: 2),
          ),
          child: child,
        ),
      );
}

class _LanguageButton extends StatelessWidget {
  const _LanguageButton();

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    return TextButton(
      onPressed: () => store.setLanguage(store.language == 'ar' ? 'en' : 'ar'),
      child: Text(store.language == 'ar' ? 'English' : 'العربية'),
    );
  }
}
