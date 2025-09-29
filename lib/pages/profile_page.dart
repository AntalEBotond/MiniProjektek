import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/api_service.dart';
import 'profil/frame_preview_strip.dart';
import 'profil/framed_avatar.dart';
import 'profil/note_editor.dart' show showEmojiPickerSheet;
import 'profil/note_editor_page.dart';
import 'profil/note_overlay.dart';
import 'services/sticker_service.dart';
import 'utils/i18n.dart';
import 'utils/ui_utils.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage>
    with SingleTickerProviderStateMixin {
  final ImagePicker _picker = ImagePicker();

  bool _loading = true;
  bool _saving = false;
  bool _reduceMotion = false;
  double _haloStrength = 0.65;
  bool _dirty = false;
  String? _authToken;

  Timer? _nameDebounce;
  Timer? _descDebounce;

  late final AnimationController _haloCtrl;
  Timer? _statusTicker;
  Timer? _autoSaveTimer;

  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _descCtrl = TextEditingController();

  String? _avatarPath;
  Uint8List? _avatarBytes;
  String? _avatarUrl;
  String _avatarFrame = 'none';
  String? _statusNote;
  DateTime? _statusNoteExpires;
  String? _statusEmoji;
  Color _noteTextColor = Colors.white;
  Color _noteBgColor = const Color(0xDD000000);

  String? _facebook;
  String? _instagram;
  String? _tiktok;
  String? _youtube;

  String? _bannerPath;
  Uint8List? _bannerBytes;
  String? _bannerUrl;
  String _themeMode = 'system';
  Color _accentColor = const Color(0xFF00C853);
  String? _pronouns;
  String? _websiteUrl;
  String? _location;
  String? _language;
  bool _compactMode = false;
  double _textScalePref = 1.0;
  String? _avatarStickerAsset;
  List<Sticker> _stickers = const [];
  static const List<String> kStickers = [];

  static const List<String> kFrameStyles = [
    'none',
    'glow-00E676',
    'glow-03A9F4',
    'glow-FF5252',
    'glow-AB47BC',
    'neon-00FF9C',
    'neon-FFEA00',
    'neon-FF3D00',
    'neon-00E5FF',
    'neon-7C4DFF',
    'outline-42A5F5',
    'outline-FF7043',
    'outline-66BB6A',
    'outline-EC407A',
    'outline-FFC107',
    'ring-1DE9B6',
    'ring-E040FB',
    'ring-FF6E40',
    'ring-29B6F6',
    'ring-AED581',
    'gradient-sunset',
    'gradient-ocean',
    'gradient-forest',
    'gradient-violet',
    'gradient-fire',
    'gradient-candy',
    'gradient-berry',
    'gradient-sky',
    'gradient-mint',
    'gradient-royal',
    'gradient-rose',
    'gradient-aurora',
    'gradient-citrus',
    'gradient-plasma',
    'gradient-peach',
    'gradient-lava',
    'gradient-aqua',
    'gradient-steel',
    'gradient-gold',
    'gradient-silver',
    'gradient-bronze',
    'rainbow',
    'glow-FF4081',
    'glow-8BC34A',
    'neon-18FFFF',
    'neon-E040FB',
    'outline-90CAF9',
    'outline-FFAB91',
    'ring-80CBC4',
    'ring-CE93D8'
  ];

  Set<String> _frameFavs = {};
  String? _frameTempPreview;
  static const Map<String, List<String>> _kCategories = {
    'All': [],
    'Gradients': ['gradient-', 'rainbow'],
    'Glow': ['glow-'],
    'Neon': ['neon-'],
    'Outline': ['outline-'],
    'Ring': ['ring-'],
    'Other': ['none'],
  };

  @override
  void initState() {
    super.initState();
    _haloCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 18),
    )..repeat();

    () async {
      final sp = await SharedPreferences.getInstance();
      if (!mounted) return;
      setState(() {
        _haloStrength = sp.getDouble('profile_halo_strength') ?? 0.65;
        _reduceMotion = sp.getBool('profile_reduce_motion') ?? false;
        _frameFavs = (sp.getStringList('profile_frame_favs') ?? []).toSet();
      });
      if (!mounted) return;
      if (_reduceMotion) {
        _haloCtrl.stop();
      } else if (!_haloCtrl.isAnimating) {
        _haloCtrl.repeat();
      }
    }();

    _loadProfile();
    _nameCtrl.addListener(_saveName);
    _descCtrl.addListener(_saveDescription);
  }

  @override
  void dispose() {
    _nameDebounce?.cancel();
    _descDebounce?.cancel();
    _nameCtrl.removeListener(_saveName);
    _descCtrl.removeListener(_saveDescription);
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _haloCtrl.dispose();
    _statusTicker?.cancel();
    super.dispose();
  }

  void _markDirty() {
    if (!_dirty) setState(() => _dirty = true);
    _scheduleAutoSave();
  }

  void _scheduleAutoSave() {
    if (_authToken == null) return;
    _autoSaveTimer?.cancel();
    _autoSaveTimer = Timer(const Duration(seconds: 1), () {
      if (mounted && _dirty && !_saving) {
        _saveProfileToServer(silent: true);
      }
    });
  }

  Future<void> _persistUx() async {
    final sp = await SharedPreferences.getInstance();
    await sp.setDouble('profile_halo_strength', _haloStrength);
    await sp.setBool('profile_reduce_motion', _reduceMotion);
    await sp.setStringList('profile_frame_favs', _frameFavs.toList());
    _markDirty();
  }

  void _startStatusTicker() {
    _statusTicker?.cancel();
    if (_statusNoteExpires == null) return;
    _statusTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        if (_statusNoteExpires != null &&
            DateTime.now().isAfter(_statusNoteExpires!)) {
          _statusTicker?.cancel();
        }
      });
    });
  }

  double get _statusProgress {
    if (_statusNoteExpires == null) return 0;
    final end = _statusNoteExpires!;
    final start = end.subtract(const Duration(hours: 24));
    final now = DateTime.now();
    final total = end.difference(start).inMilliseconds.toDouble();
    final done = (now.isBefore(start)
            ? 0
            : now.difference(start).inMilliseconds.toDouble())
        .clamp(0, total);
    return (done / total);
  }

  Future<void> _loadProfile() async {
    final p = await SharedPreferences.getInstance();
    final token = p.getString('auth_token');
    _authToken = token;

    if (token == null) {
      if (!mounted) return;
      setState(() {
        if (kIsWeb) {
          final b64 = p.getString('profile_avatar_b64');
          _avatarBytes =
              (b64 != null && b64.isNotEmpty) ? base64Decode(b64) : null;
          _avatarPath = null;
        } else {
          _avatarPath = p.getString('profile_avatar');
        }
        _nameCtrl.text = p.getString('profile_name') ?? '';
        _descCtrl.text = p.getString('profile_description') ?? '';
        _facebook = p.getString('profile_facebook');
        _instagram = p.getString('profile_instagram');
        _tiktok = p.getString('profile_tiktok');
        _youtube = p.getString('profile_youtube');
        _avatarUrl = p.getString('profile_avatar_url');
        _avatarFrame = p.getString('profile_avatar_frame') ?? 'none';
        _avatarStickerAsset = p.getString('profile_avatar_sticker_asset');
        _bannerUrl = p.getString('profile_banner_url');
        _themeMode = p.getString('profile_theme_mode') ?? 'system';
        _accentColor = _colorFromHex(
            p.getString('profile_accent_color'), const Color(0xFF00C853));
        _pronouns = p.getString('profile_pronouns');
        _websiteUrl = p.getString('profile_website');
        _location = p.getString('profile_location');
        _language = p.getString('profile_language');
        _compactMode = p.getBool('profile_compact_mode') ?? false;
        _textScalePref = (p.getDouble('profile_text_scale') ?? 1.0)
            .clamp(0.9, 1.2);
        final sn = p.getString('profile_status_note');
        final se = p.getString('profile_status_note_expires');
        _statusNote = sn;
        _statusNoteExpires =
            (se != null && se.isNotEmpty) ? DateTime.tryParse(se) : null;
        _noteTextColor =
            _colorFromHex(p.getString('profile_status_note_color'), Colors.white);
        _noteBgColor = _colorFromHex(
            p.getString('profile_status_note_bg'), const Color(0xDD000000));
        _statusEmoji = p.getString('profile_status_note_emoji');
        _loading = false;
        _dirty = false;
      });
      _startStatusTicker();
      return;
    }

    try {
      final api = ApiService();
      final data = await api.getProfile(token);
      if (!mounted) return;
      setState(() {
        _nameCtrl.text = (data['full_name'] ?? '') as String;
        _descCtrl.text = (data['description'] ?? '') as String;
        _facebook = data['social_facebook'] as String?;
        _instagram = data['social_instagram'] as String?;
        _tiktok = data['social_tiktok'] as String?;
        _youtube = data['social_youtube'] as String?;
        _avatarUrl = data['avatar_url'] as String?;
        _bannerUrl = data['banner_url'] as String?;
        _avatarFrame = (data['avatar_frame'] as String?) ?? 'none';
        _avatarStickerAsset = data['avatar_sticker'] as String?;
        _themeMode = (data['theme_mode'] as String?) ??
            (p.getString('profile_theme_mode') ?? 'system');
        _accentColor =
            _colorFromHex(data['accent_color'] as String?, _accentColor);
        _pronouns = data['pronouns'] as String?;
        _websiteUrl = data['website_url'] as String?;
        _location = data['location'] as String?;
        _language = data['language'] as String?;
        _compactMode =
            ((data['compact_mode'] ?? p.getBool('profile_compact_mode') ??
                        false) ==
                    true);
        final ts = data['text_scale'];
        if (ts != null) {
          final v = double.tryParse(ts.toString());
          if (v != null) _textScalePref = v.clamp(0.9, 1.2);
        }
        final sn = data['status_note'] as String?;
        final se = data['status_note_expires'] as String?;
        final sc = data['status_note_color'] as String?;
        final sb = data['status_note_bg'] as String?;
        if (se != null) {
          final dt = DateTime.tryParse(se);
          if (dt != null && dt.isAfter(DateTime.now())) {
            _statusNote = sn;
            _statusNoteExpires = dt;
          } else {
            _statusNote = null;
            _statusNoteExpires = null;
          }
        } else {
          _statusNote = sn;
          _statusNoteExpires = null;
        }
        _noteTextColor = _colorFromHex(sc, Colors.white);
        _noteBgColor =
            _colorFromHex(sb, const Color(0xDD000000));
        _statusEmoji = data['status_note_emoji'] as String?;
        if (kIsWeb) {
          final b64 = p.getString('profile_avatar_b64');
          _avatarBytes =
              (b64 != null && b64.isNotEmpty) ? base64Decode(b64) : null;
          _avatarPath = null;
        } else {
          _avatarPath = p.getString('profile_avatar');
        }
        _loading = false;
        _dirty = false;
      });
      await p.setString('profile_theme_mode', _themeMode);
      await p.setString('profile_accent_color', _hexFromColor(_accentColor));
      await p.setBool('profile_compact_mode', _compactMode);
      await p.setDouble('profile_text_scale', _textScalePref);
      await p.setString('profile_language', _language ?? '');
      if (_avatarStickerAsset != null && _avatarStickerAsset!.isNotEmpty) {
        await p.setString(
            'profile_avatar_sticker_asset', _avatarStickerAsset!);
      } else {
        await p.remove('profile_avatar_sticker_asset');
      }
      if (_bannerUrl != null) {
        await p.setString('profile_banner_url', _bannerUrl!);
      } else {
        await p.remove('profile_banner_url');
      }
      _startStatusTicker();
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
      }
      if (!mounted) return;
      if (e is ApiException && e.status == 401) {
        await p.remove('auth_token');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  'Sesiune invalidă/expirată. Te rugăm să te reconectezi.')),
        );
        Future.microtask(
            () => Navigator.of(context).pushReplacementNamed('/login'));
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Nu s-a putut incarca profilul: $e')),
      );
    }
  }

  Future<void> _revertLocal() async {
    final p = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _nameCtrl.text = p.getString('profile_name') ?? '';
      _descCtrl.text = p.getString('profile_description') ?? '';
      _facebook = p.getString('profile_facebook');
      _instagram = p.getString('profile_instagram');
      _tiktok = p.getString('profile_tiktok');
      _youtube = p.getString('profile_youtube');
      _avatarUrl = p.getString('profile_avatar_url');
      _avatarFrame = p.getString('profile_avatar_frame') ?? 'none';
      _avatarStickerAsset = p.getString('profile_avatar_sticker_asset');
      _bannerUrl = p.getString('profile_banner_url');
      _themeMode = p.getString('profile_theme_mode') ?? _themeMode;
      _accentColor =
          _colorFromHex(p.getString('profile_accent_color'), _accentColor);
      _pronouns = p.getString('profile_pronouns');
      _websiteUrl = p.getString('profile_website');
      _location = p.getString('profile_location');
      _language = p.getString('profile_language');
      _compactMode = p.getBool('profile_compact_mode') ?? _compactMode;
      _textScalePref =
          p.getDouble('profile_text_scale') ?? _textScalePref;
      final sn = p.getString('profile_status_note');
      final se = p.getString('profile_status_note_expires');
      _statusNote = sn;
      _statusNoteExpires =
          (se != null && se.isNotEmpty) ? DateTime.tryParse(se) : null;
      _noteTextColor =
          _colorFromHex(p.getString('profile_status_note_color'), Colors.white);
      _noteBgColor = _colorFromHex(
          p.getString('profile_status_note_bg'), const Color(0xDD000000));
      _statusEmoji = p.getString('profile_status_note_emoji');
      _dirty = false;
    });
    _startStatusTicker();
  }

  Future<void> _saveProfileToServer({bool silent = false}) async {
    final p = await SharedPreferences.getInstance();
    final token = _authToken ?? p.getString('auth_token');
    if (token == null) {
      if (!silent) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(I18n.t(context, 'not_authenticated'))),
        );
      }
      return;
    }
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final api = ApiService();
      final payload = <String, dynamic>{
        'full_name': _nameCtrl.text,
        'description': _descCtrl.text,
        'social_facebook': _facebook,
        'social_instagram': _instagram,
        'social_tiktok': _tiktok,
        'social_youtube': _youtube,
      };
      final updated = await api.updateProfile(token, {
        ...payload,
        'avatar_frame': _avatarFrame,
        'avatar_sticker': _avatarStickerAsset,
        if (_statusNote != null && _statusNote!.isNotEmpty)
          'status_note': _statusNote,
        if (_statusNoteExpires != null)
          'status_note_expires': _statusNoteExpires!.toIso8601String(),
        'status_note_color': _hexFromColor(_noteTextColor),
        'status_note_bg': _hexFromColor(_noteBgColor),
        if (_statusEmoji != null && _statusEmoji!.isNotEmpty)
          'status_note_emoji': _statusEmoji,
        'theme_mode': _themeMode,
        'accent_color': _hexFromColor(_accentColor),
        'halo_strength': _haloStrength.toStringAsFixed(2),
        'avatar_frame_favs':
            _frameFavs.isEmpty ? null : jsonEncode(_frameFavs.toList()),
        'pronouns': _pronouns,
        'website_url': _websiteUrl,
        'location': _location,
        'compact_mode': _compactMode,
        'text_scale': _textScalePref.toStringAsFixed(2),
        'reduce_motion': _reduceMotion,
      });

      p.setString('profile_name', updated['full_name']?.toString() ?? '');
      p.setString(
          'profile_description', updated['description']?.toString() ?? '');
      if (updated['social_facebook'] != null) {
        p.setString('profile_facebook', updated['social_facebook']);
      } else {
        p.remove('profile_facebook');
      }
      if (updated['social_instagram'] != null) {
        p.setString('profile_instagram', updated['social_instagram']);
      } else {
        p.remove('profile_instagram');
      }
      if (updated['social_tiktok'] != null) {
        p.setString('profile_tiktok', updated['social_tiktok']);
      } else {
        p.remove('profile_tiktok');
      }
      if (updated['social_youtube'] != null) {
        p.setString('profile_youtube', updated['social_youtube']);
      } else {
        p.remove('profile_youtube');
      }
      if (updated['avatar_url'] != null) {
        p.setString('profile_avatar_url', updated['avatar_url']);
      } else {
        p.remove('profile_avatar_url');
      }
      if (updated['avatar_frame'] != null) {
        p.setString('profile_avatar_frame', updated['avatar_frame']);
      } else {
        p.remove('profile_avatar_frame');
      }
      if (updated['status_note'] != null) {
        p.setString('profile_status_note', updated['status_note']);
      } else {
        p.remove('profile_status_note');
      }
      if (updated['status_note_expires'] != null) {
        p.setString('profile_status_note_expires',
            updated['status_note_expires']);
      } else {
        p.remove('profile_status_note_expires');
      }
      if (updated['status_note_color'] != null) {
        p.setString('profile_status_note_color',
            updated['status_note_color']);
      }
      if (updated['status_note_bg'] != null) {
        p.setString(
            'profile_status_note_bg', updated['status_note_bg']);
      }
      if (updated['status_note_emoji'] != null) {
        p.setString('profile_status_note_emoji',
            updated['status_note_emoji']);
      } else {
        p.remove('profile_status_note_emoji');
      }
      if (updated['avatar_sticker'] != null) {
        p.setString('profile_avatar_sticker_asset',
            updated['avatar_sticker']);
      } else {
        p.remove('profile_avatar_sticker_asset');
      }
      if (updated['banner_url'] != null) {
        p.setString('profile_banner_url', updated['banner_url']);
      }
      if (updated['theme_mode'] != null) {
        p.setString('profile_theme_mode', updated['theme_mode']);
      }
      if (updated['accent_color'] != null) {
        p.setString('profile_accent_color', updated['accent_color']);
      }
      if (updated['language'] != null) {
        p.setString('profile_language', updated['language']);
      }
      if (updated['pronouns'] != null) {
        p.setString('profile_pronouns', updated['pronouns']);
      } else {
        p.remove('profile_pronouns');
      }
      if (updated['website_url'] != null) {
        p.setString('profile_website', updated['website_url']);
      } else {
        p.remove('profile_website');
      }
      if (updated['location'] != null) {
        p.setString('profile_location', updated['location']);
      } else {
        p.remove('profile_location');
      }
      p.setBool('profile_compact_mode', (updated['compact_mode'] == true));
      if (updated['text_scale'] != null) {
        final v = double.tryParse(updated['text_scale'].toString()) ?? 1.0;
        p.setDouble('profile_text_scale', v);
      }
      if (updated['halo_strength'] != null) {
        final v = double.tryParse(updated['halo_strength'].toString());
        if (v != null) {
          await p.setDouble('profile_halo_strength', v);
          if (mounted) setState(() => _haloStrength = v);
        }
      }
      if (updated['avatar_frame_favs'] != null) {
        try {
          final list = List<String>.from(
              (jsonDecode(updated['avatar_frame_favs']) as List));
          await p.setStringList('profile_frame_favs', list);
          if (mounted) setState(() => _frameFavs = list.toSet());
        } catch (_) {}
      }

      if (!mounted) return;
      HapticFeedback.mediumImpact();
      if (!silent) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(I18n.t(context, 'profile_saved'))),
        );
      }
      setState(() => _dirty = false);
    } catch (e) {
      if (!mounted) return;
      if (!silent) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${I18n.t(context, 'save_failed')}: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _saveName() async {
    _markDirty();
    _nameDebounce?.cancel();
    _nameDebounce = Timer(const Duration(milliseconds: 350), () async {
      final p = await SharedPreferences.getInstance();
      p.setString('profile_name', _nameCtrl.text);
    });
  }

  void _saveDescription() async {
    _markDirty();
    _descDebounce?.cancel();
    _descDebounce = Timer(const Duration(milliseconds: 500), () async {
      final p = await SharedPreferences.getInstance();
      p.setString('profile_description', _descCtrl.text);
    });
  }

  Future<void> _saveAvatarFromXFile(XFile file) async {
    final p = await SharedPreferences.getInstance();
    final token = _authToken ?? p.getString('auth_token');
    if (token == null) {
      if (kIsWeb) {
        final bytes = await file.readAsBytes();
        final b64 = base64Encode(bytes);
        await p.setString('profile_avatar_b64', b64);
        if (!mounted) return;
        setState(() {
          _avatarBytes = bytes;
          _avatarPath = null;
        });
      } else {
        await p.setString('profile_avatar', file.path);
        if (!mounted) return;
        setState(() {
          _avatarPath = file.path;
          _avatarBytes = null;
        });
      }
      return;
    }

    try {
      final api = ApiService();
      String url;
      if (kIsWeb) {
        final bytes = await file.readAsBytes();
        final b64 = base64Encode(bytes);
        await p.setString('profile_avatar_b64', b64);
        if (!mounted) return;
        setState(() {
          _avatarBytes = bytes;
          _avatarPath = null;
        });
        final name = file.name.isNotEmpty ? file.name : 'avatar.jpg';
        url = await api.uploadAvatarBytes(token, bytes, filename: name);
      } else {
        await p.setString('profile_avatar', file.path);
        if (!mounted) return;
        setState(() {
          _avatarPath = file.path;
          _avatarBytes = null;
        });
        url =
            await api.uploadAvatarPath(token, file.path, filename: file.name);
      }
      final cacheBusted =
          '$url?v=${DateTime.now().millisecondsSinceEpoch}';
      await p.setString('profile_avatar_url', cacheBusted);
      if (!mounted) return;
      setState(() => _avatarUrl = cacheBusted);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(I18n.t(context, 'avatar_updated'))));
      HapticFeedback.selectionClick();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${I18n.t(context, 'upload_error')}: $e')));
    }
  }

  Future<void> _clearAvatar() async {
    final p = await SharedPreferences.getInstance();
    final token = _authToken ?? p.getString('auth_token');
    if (token != null) {
      try {
        await ApiService().deleteAvatar(token);
        await p.remove('profile_avatar_url');
        setState(() => _avatarUrl = null);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(
                  '${I18n.t(context, 'avatar_delete_failed')}: $e')));
        }
      }
    }
    if (kIsWeb) {
      await p.remove('profile_avatar_b64');
      setState(() => _avatarBytes = null);
    } else {
      await p.remove('profile_avatar');
      setState(() => _avatarPath = null);
    }
    HapticFeedback.lightImpact();
  }

  Future<void> _saveBannerFromXFile(XFile file) async {
    final p = await SharedPreferences.getInstance();
    final token = _authToken ?? p.getString('auth_token');
    if (token == null) {
      if (kIsWeb) {
        final bytes = await file.readAsBytes();
        final b64 = base64Encode(bytes);
        await p.setString('profile_banner_b64', b64);
        if (!mounted) return;
        setState(() {
          _bannerBytes = bytes;
          _bannerPath = null;
        });
      } else {
        await p.setString('profile_banner', file.path);
        if (!mounted) return;
        setState(() {
          _bannerPath = file.path;
          _bannerBytes = null;
        });
      }
      return;
    }

    try {
      final api = ApiService();
      String url;
      if (kIsWeb) {
        final bytes = await file.readAsBytes();
        await p.setString('profile_banner_b64', base64Encode(bytes));
        setState(() {
          _bannerBytes = bytes;
          _bannerPath = null;
        });
        final name = file.name.isNotEmpty ? file.name : 'banner.jpg';
        url = await api.uploadBannerBytes(token, bytes, filename: name);
      } else {
        await p.setString('profile_banner', file.path);
        setState(() {
          _bannerPath = file.path;
          _bannerBytes = null;
        });
        url =
            await api.uploadBannerPath(token, file.path, filename: file.name);
      }
      final cacheBusted =
          '$url?v=${DateTime.now().millisecondsSinceEpoch}';
      await p.setString('profile_banner_url', cacheBusted);
      if (!mounted) return;
      setState(() => _bannerUrl = cacheBusted);
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(I18n.t(context, 'banner_updated'))));
      HapticFeedback.selectionClick();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${I18n.t(context, 'upload_error')}: $e')));
    }
  }

  Future<void> _clearBanner() async {
    final p = await SharedPreferences.getInstance();
    final token = _authToken ?? p.getString('auth_token');
    if (token != null) {
      try {
        await ApiService().deleteBanner(token);
        await p.remove('profile_banner_url');
        setState(() => _bannerUrl = null);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(
                  '${I18n.t(context, 'banner_delete_failed')}: $e')));
        }
      }
    }
    if (kIsWeb) {
      await p.remove('profile_banner_b64');
      setState(() => _bannerBytes = null);
    } else {
      await p.remove('profile_banner');
      setState(() => _bannerPath = null);
    }
    HapticFeedback.lightImpact();
  }

  Future<void> _showActionSheet(List<_SheetAction> actions) async {
    if (actions.isEmpty) return;
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color:
                      Theme.of(context).colorScheme.surface.withOpacity(0.9),
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: actions.length,
                  separatorBuilder: (_, __) => Divider(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withOpacity(0.06),
                    height: 1,
                  ),
                  itemBuilder: (_, i) {
                    final action = actions[i];
                    return ListTile(
                      leading: Icon(
                        action.icon,
                        color: action.isDestructive
                            ? Colors.redAccent
                            : null,
                      ),
                      title: Text(
                        action.label,
                        style: TextStyle(
                          color: action.isDestructive
                              ? Colors.redAccent
                              : null,
                        ),
                      ),
                      onTap: () async {
                        Navigator.of(context).pop();
                        await action.onSelected?.call();
                      },
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showBannerOptions() {
    _showActionSheet([
      _SheetAction(
        icon: Icons.photo_library,
        label: I18n.t(context, 'pick_from_gallery'),
        onSelected: () => _pickBannerImage(ImageSource.gallery),
      ),
      _SheetAction(
        icon: Icons.camera_alt,
        label: I18n.t(context, 'take_photo'),
        onSelected: () => _pickBannerImage(ImageSource.camera),
      ),
      if ((_bannerUrl != null && _bannerUrl!.isNotEmpty) ||
          (!kIsWeb && _bannerPath != null && _bannerPath!.isNotEmpty) ||
          (kIsWeb && _bannerBytes != null && _bannerBytes!.isNotEmpty))
        _SheetAction(
          icon: Icons.delete,
          label: I18n.t(context, 'delete_banner'),
          isDestructive: true,
          onSelected: _clearBanner,
        ),
    ]);
  }

  Future<void> _pickBannerImage(ImageSource source) async {
    try {
      final XFile? file = await _picker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 90,
      );
      if (file != null) {
        await _saveBannerFromXFile(file);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Eroare la incarcare banner: $e')),
      );
    }
  }

  void _showImageOptions() {
    _showActionSheet([
      _SheetAction(
        icon: Icons.photo_library,
        label: I18n.t(context, 'pick_from_gallery'),
        onSelected: () => _pickImage(ImageSource.gallery),
      ),
      _SheetAction(
        icon: Icons.camera_alt,
        label: I18n.t(context, 'take_photo'),
        onSelected: () => _pickImage(ImageSource.camera),
      ),
      if ((_avatarUrl != null && _avatarUrl!.isNotEmpty) ||
          (!kIsWeb && _avatarPath != null && _avatarPath!.isNotEmpty) ||
          (kIsWeb && _avatarBytes != null && _avatarBytes!.isNotEmpty))
        _SheetAction(
          icon: Icons.delete,
          label: I18n.t(context, 'delete_avatar'),
          isDestructive: true,
          onSelected: _clearAvatar,
        ),
      if (_currentAvatarImage() != null)
        _SheetAction(
          icon: Icons.zoom_out_map,
          label: I18n.t(context, 'zoom_avatar'),
          onSelected: () {
            _openAvatarViewer();
            return Future.value();
          },
        ),
    ]);
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? file = await _picker.pickImage(
        source: source,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 90,
      );
      if (file != null) {
        await _saveAvatarFromXFile(file);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${I18n.t(context, 'image_load_error')}: $e')),
      );
    }
  }

  void _setFrame(String style) async {
    setState(() => _avatarFrame = style);
    final p = await SharedPreferences.getInstance();
    await p.setString('profile_avatar_frame', style);
    _markDirty();
    HapticFeedback.selectionClick();
  }

  void _cycleFrame(int dir) {
    final list = kFrameStyles;
    final idx = list.indexOf(_avatarFrame);
    final next = (idx < 0) ? 0 : (idx + dir) % list.length;
    final sel = list[(next + list.length) % list.length];
    _setFrame(sel);
  }

  void _randomizeFrame() {
    final pool = kFrameStyles.where((e) => e != 'none').toList();
    if (pool.isEmpty) return;
    pool.shuffle();
    _setFrame(pool.first);
    HapticFeedback.selectionClick();
  }

  Future<void> _openFramePickerSheet() async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _FramePickerSheet(
        allStyles: kFrameStyles,
        current: _avatarFrame,
        favs: _frameFavs,
        categories: _kCategories,
        colorsFor: _colorsForFrame,
        onPreviewStart: (style) => setState(() => _frameTempPreview = style),
        onPreviewEnd: () => setState(() => _frameTempPreview = null),
        onToggleFav: (style) async {
          setState(() {
            if (_frameFavs.contains(style)) {
              _frameFavs.remove(style);
            } else {
              _frameFavs.add(style);
            }
          });
          await _persistUx();
        },
      ),
    );
    if (selected != null && selected.isNotEmpty) {
      _setFrame(selected);
    }
  }

  Future<void> _editStatusNote() async {
    final res = await Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => NoteEditorPage(
          initialText: _statusNote ?? '',
          textColor: _noteTextColor,
          bgColor: _noteBgColor,
          emoji: _statusEmoji,
          avatarImage: _currentAvatarImage(),
          avatarName: _nameCtrl.text.trim().isEmpty
              ? 'User'
              : _nameCtrl.text.trim(),
          frameStyle: _avatarFrame,
        ),
      ),
    );
    if (res == null) return;
    final p = await SharedPreferences.getInstance();
    if (res.deleted || (res.text == null || res.text!.trim().isEmpty)) {
      setState(() {
        _statusNote = null;
        _statusNoteExpires = null;
      });
      await p.remove('profile_status_note');
      await p.remove('profile_status_note_expires');
      await p.remove('profile_status_note_color');
      await p.remove('profile_status_note_bg');
      await p.remove('profile_status_note_emoji');
      _statusTicker?.cancel();
      _markDirty();
      return;
    }
    final txt = res.text!.trim();
    final exp = DateTime.now().add(const Duration(hours: 24));
    setState(() {
      _statusNote = txt;
      _statusNoteExpires = exp;
      _noteTextColor = res.textColor;
      _noteBgColor = res.bgColor;
    });
    await p.setString('profile_status_note', txt);
    await p.setString('profile_status_note_expires', exp.toIso8601String());
    await p.setString(
        'profile_status_note_color', _hexFromColor(_noteTextColor));
    await p.setString('profile_status_note_bg', _hexFromColor(_noteBgColor));
    if (_statusEmoji != null && _statusEmoji!.isNotEmpty) {
      await p.setString('profile_status_note_emoji', _statusEmoji!);
    } else {
      await p.remove('profile_status_note_emoji');
    }
    _markDirty();
    _startStatusTicker();
  }

  Future<void> _pickEmoji() async {
    final String? picked = await showEmojiPickerSheet(context);
    if (picked == null) return;
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _statusEmoji = picked;
    });
    if (picked.isNotEmpty) {
      await prefs.setString('profile_status_note_emoji', picked);
    } else {
      await prefs.remove('profile_status_note_emoji');
    }
    _markDirty();
  }

  Future<void> _saveLink(String key, String? value) async {
    final p = await SharedPreferences.getInstance();
    if (value == null || value.isEmpty) {
      p.remove(key);
    } else {
      p.setString(key, value);
    }
    setState(() {
      if (key == 'profile_facebook') _facebook = value;
      if (key == 'profile_instagram') _instagram = value;
      if (key == 'profile_tiktok') _tiktok = value;
      if (key == 'profile_youtube') _youtube = value;
    });
    _markDirty();
  }

  Future<void> _editLinkDialog(
      String title, String prefKey, String? current) async {
    final TextEditingController c = TextEditingController(text: current ?? '');
    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('${I18n.t(context, 'edit')}: $title'),
          content: TextField(
            controller: c,
            keyboardType: TextInputType.url,
            textInputAction: TextInputAction.done,
            decoration: const InputDecoration(
              hintText: 'Link sau @handle (ex. https://..., @user, user)',
            ),
            onSubmitted: (_) => Navigator.of(context).maybePop(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(I18n.t(context, 'cancel')),
            ),
            FilledButton(
              onPressed: () {
                final raw = c.text.trim();
                final val = _normalizeLinkForBrand(prefKey, raw);
                _saveLink(prefKey, val.isEmpty ? null : val);
                Navigator.of(context).pop();
                HapticFeedback.selectionClick();
              },
              child: Text(I18n.t(context, 'save')),
            ),
          ],
        );
      },
    );
  }

  String _normalizeLinkForBrand(String prefKey, String input) {
    final v = input.trim();
    if (v.isEmpty) return '';
    final isUrl = v.startsWith('http://') || v.startsWith('https://');
    String username = v.startsWith('@') ? v.substring(1) : v;
    if (isUrl) return v;

    switch (prefKey) {
      case 'profile_facebook':
        return 'https://facebook.com/$username';
      case 'profile_instagram':
        return 'https://instagram.com/$username';
      case 'profile_tiktok':
        if (username.contains('/')) return 'https://tiktok.com/$username';
        return 'https://www.tiktok.com/@$username';
      case 'profile_youtube':
        if (username.startsWith('@')) return 'https://youtube.com/$username';
        if (username.startsWith('UC')) {
          return 'https://youtube.com/channel/$username';
        }
        return 'https://youtube.com/@$username';
      default:
        return v;
    }
  }

  Future<void> _openLink(String? url) async {
    if (url == null || url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nu exista link setat pentru acest serviciu.')),
      );
      return;
    }
    final uri = Uri.tryParse(url);
    if (uri == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('URL invalid.')),
      );
      return;
    }
    if (!await canLaunchUrl(uri)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nu s-a putut deschide linkul.')),
      );
      return;
    }
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Widget _socialButton(
    String brand,
    IconData icon,
    String? link,
    String title,
    String prefKey,
  ) {
    final enabled = link != null && link.isNotEmpty;
    BoxDecoration decoFor(String b) {
      switch (b) {
        case 'facebook':
          const base = Color(0xFF1877F2);
          return BoxDecoration(
            color: enabled ? base : Colors.grey,
            shape: BoxShape.circle,
            boxShadow: enabled
                ? [
                    BoxShadow(
                      color: base.withOpacity(0.35),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    )
                  ]
                : [],
          );
        case 'instagram':
          return BoxDecoration(
            shape: BoxShape.circle,
            gradient: enabled
                ? const LinearGradient(
                    colors: [
                      Color(0xFFF58529),
                      Color(0xFFDD2A7B),
                      Color(0xFF8134AF),
                      Color(0xFF515BD4),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : LinearGradient(
                    colors: [Colors.grey.shade700, Colors.grey.shade600],
                  ),
            boxShadow: enabled
                ? [
                    const BoxShadow(
                      color: Color(0x55212121),
                      blurRadius: 12,
                      offset: Offset(0, 6),
                    )
                  ]
                : [],
          );
        case 'tiktok':
          return BoxDecoration(
            color: enabled ? Colors.black : Colors.grey,
            shape: BoxShape.circle,
            boxShadow: enabled
                ? [
                    BoxShadow(
                      color: const Color(0xFF69C9D0).withOpacity(0.4),
                      blurRadius: 14,
                      offset: const Offset(-2, 4),
                    ),
                    BoxShadow(
                      color: const Color(0xFFEE1D52).withOpacity(0.4),
                      blurRadius: 14,
                      offset: const Offset(2, 4),
                    ),
                  ]
                : [],
          );
        case 'youtube':
          const base = Color(0xFFFF0000);
          return BoxDecoration(
            color: enabled ? base : Colors.grey,
            shape: BoxShape.circle,
            boxShadow: enabled
                ? [
                    BoxShadow(
                      color: base.withOpacity(0.35),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    )
                  ]
                : [],
          );
        default:
          return BoxDecoration(
            color: enabled ? Colors.blueAccent : Colors.grey,
            shape: BoxShape.circle,
          );
      }
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          button: true,
          label: enabled
              ? '$title megnyitása'
              : '$title nincs beállítva',
          child: GestureDetector(
            onTap: enabled
                ? () {
                    _openLink(link);
                    HapticFeedback.selectionClick();
                  }
                : null,
            onLongPress: enabled
                ? () async {
                    await Clipboard.setData(ClipboardData(text: link));
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(I18n.t(context, 'link_copied'))),
                      );
                    }
                    HapticFeedback.lightImpact();
                  }
                : null,
            child: AnimatedScale(
              duration: const Duration(milliseconds: 140),
              scale: enabled ? 1.0 : 0.95,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                width: 60,
                height: 60,
                decoration: decoFor(brand),
                alignment: Alignment.center,
                child: FaIcon(icon, color: Colors.white, size: 26),
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit, size: 18),
              onPressed: () => _editLinkDialog(title, prefKey, link),
              tooltip: I18n.t(context, 'edit_link'),
            ),
            IconButton(
              icon: const Icon(Icons.open_in_new, size: 18),
              onPressed: enabled ? () => _openLink(link) : null,
              tooltip: I18n.t(context, 'open_link'),
            ),
          ],
        )
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final theme = Theme.of(context);
    final media = MediaQuery.of(context);
    final width = media.size.width;
    final textScale = media.textScaleFactor.clamp(0.9, 1.2);
    final isSmall = width < 420;
    final avatarRadius = isSmall ? 52.0 : 64.0;
    final bubbleSpace = isSmall ? 48.0 : 56.0;
    final tileWidth = (avatarRadius * 2) + (isSmall ? 164.0 : 240.0);
    final bubbleRightInset = (tileWidth / 2) - avatarRadius - 4;
    final name = _nameCtrl.text.trim();
    final completeness = _computeCompleteness();
    final topPadding = media.padding.top;
    final horizontalPadding = isSmall ? 16.0 : 24.0;

    return WillPopScope(
      onWillPop: _onBackPressed,
      child: MediaQuery(
        data: media.copyWith(textScaler: TextScaler.linear(textScale)),
        child: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF161623), Color(0xFF0B111E)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: Scaffold(
            backgroundColor: Colors.transparent,
            extendBodyBehindAppBar: true,
            appBar: AppBar(
              systemOverlayStyle: Theme.of(context).brightness == Brightness.dark
                  ? SystemUiOverlayStyle.light
                  : SystemUiOverlayStyle.dark,
              backgroundColor: Colors.transparent,
              elevation: 0,
              toolbarHeight: 70,
              titleSpacing: horizontalPadding,
              centerTitle: false,
              flexibleSpace: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0x661D1F33), Color(0x331D1F33)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    I18n.t(context, 'profile'),
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Fresh profile vibes · 2025',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.65),
                    ),
                  ),
                ],
              ),
            ),
            body: RefreshIndicator(
              onRefresh: _loadProfile,
              edgeOffset: topPadding + kToolbarHeight,
              child: SingleChildScrollView(
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.fromLTRB(
                  horizontalPadding,
                  topPadding + kToolbarHeight + 20,
                  horizontalPadding,
                  120,
                ),
                child: Column(
                  children: [
                    _glassField(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.wallpaper, size: 18),
                              const SizedBox(width: 8),
                              Text(
                                'Banner / Cover',
                                style: theme.textTheme.titleMedium,
                              ),
                              const Spacer(),
                              FilledButton.icon(
                                onPressed: _showBannerOptions,
                                icon: const Icon(Icons.edit, size: 18),
                                label: Text(I18n.t(context, 'edit')),
                                style: FilledButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 10,
                                  ),
                                  textStyle: theme.textTheme.labelLarge,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          AspectRatio(
                            aspectRatio: 3 / 1,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  Builder(
                                    builder: (context) {
                                      ImageProvider? img;
                                      if (_bannerUrl != null &&
                                          _bannerUrl!.isNotEmpty &&
                                          _bannerBytes == null &&
                                          (_bannerPath == null ||
                                              _bannerPath!.isEmpty)) {
                                        img = NetworkImage(
                                            UiUtils.normalizeUploadUrl(
                                                _bannerUrl!));
                                      }
                                      if (kIsWeb) {
                                        if (_bannerBytes != null &&
                                            _bannerBytes!.isNotEmpty) {
                                          img = MemoryImage(_bannerBytes!);
                                        }
                                      } else {
                                        if (_bannerPath != null &&
                                            _bannerPath!.isNotEmpty &&
                                            File(_bannerPath!).existsSync()) {
                                          img = FileImage(File(_bannerPath!));
                                        }
                                      }
                                      if (img != null) {
                                        return Image(
                                          image: img,
                                          fit: BoxFit.cover,
                                        );
                                      }
                                      return Container(
                                        alignment: Alignment.center,
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: [
                                              theme.colorScheme.primary
                                                  .withOpacity(0.12),
                                              theme.colorScheme.primary
                                                  .withOpacity(0.04),
                                            ],
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                          ),
                                        ),
                                        child: Text(
                                          'Nincs beállított banner',
                                          style: theme.textTheme.bodyMedium,
                                        ),
                                      );
                                    },
                                  ),
                                  Positioned(
                                    right: 12,
                                    bottom: 12,
                                    child: FloatingActionButton.small(
                                      heroTag: 'banner_edit',
                                      onPressed: _showBannerOptions,
                                      child: const Icon(Icons.edit),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: bubbleSpace + avatarRadius * 2 + 36,
                      child: Center(
                        child: SizedBox(
                          width: tileWidth,
                          height: bubbleSpace + avatarRadius * 2,
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Positioned(
                                top: bubbleSpace - 8,
                                left: (tileWidth - (avatarRadius * 2)) / 2 - 8,
                                child: RepaintBoundary(
                                  child: SizedBox(
                                    width: (avatarRadius * 2) + 16,
                                    height: (avatarRadius * 2) + 16,
                                    child: AnimatedBuilder(
                                      animation: _haloCtrl,
                                      builder: (context, _) {
                                        return CustomPaint(
                                          painter: _HaloPainter(
                                            rotation: _reduceMotion
                                                ? 0
                                                : _haloCtrl.value *
                                                    2 *
                                                    math.pi,
                                            colors: _colorsForFrame(
                                                _frameTempPreview ??
                                                    _avatarFrame),
                                            strength: _haloStrength,
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ),
                              ),
                              Positioned(
                                top: bubbleSpace,
                                left: (tileWidth - (avatarRadius * 2)) / 2,
                                child: GestureDetector(
                                  onTap: _showImageOptions,
                                  onDoubleTap: _randomizeFrame,
                                  onLongPress: _openAvatarViewer,
                                  onHorizontalDragEnd: (d) {
                                    final v = d.primaryVelocity ?? 0;
                                    if (v.abs() < 80) return;
                                    _cycleFrame(v < 0 ? 1 : -1);
                                  },
                                  child: Builder(builder: (_) {
                                    ImageProvider? img = _currentAvatarImage();
                                    final effectiveFrame =
                                        _frameTempPreview ?? _avatarFrame;
                                    return Stack(
                                      alignment: Alignment.center,
                                      children: [
                                        Hero(
                                          tag: 'profile_avatar_hero',
                                          child: FramedAvatar(
                                            image: img,
                                            name: name,
                                            radius: avatarRadius,
                                            frameStyle: effectiveFrame,
                                            stickerImage: (_avatarStickerAsset ==
                                                        null ||
                                                    _avatarStickerAsset!
                                                        .isEmpty)
                                                ? null
                                                : (_avatarStickerAsset!
                                                        .startsWith('http')
                                                    ? NetworkImage(
                                                        _avatarStickerAsset!)
                                                    : AssetImage(
                                                        'assets/stickers/${_avatarStickerAsset!}')),
                                          ),
                                        ),
                                        if (_statusNote != null &&
                                            _statusNoteExpires != null)
                                          RepaintBoundary(
                                            child: GestureDetector(
                                              onTap: () {
                                                if (_statusNoteExpires ==
                                                    null) return;
                                                final left = _statusNoteExpires!
                                                    .difference(DateTime.now());
                                                final h = left.inHours;
                                                final m =
                                                    left.inMinutes.remainder(60);
                                                ScaffoldMessenger.of(context)
                                                    .showSnackBar(
                                                  SnackBar(
                                                    content: Text(
                                                      'Hátralévő idő: ${h}h ${m}m',
                                                    ),
                                                  ),
                                                );
                                              },
                                              child: SizedBox(
                                                width: avatarRadius * 2 + 12,
                                                height: avatarRadius * 2 + 12,
                                                child: CustomPaint(
                                                  painter: _CountdownRingPainter(
                                                    progress: _statusProgress,
                                                    trackColor: Colors.white
                                                        .withOpacity(0.12),
                                                    glowColor:
                                                        theme.colorScheme.primary,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                      ],
                                    );
                                  }),
                                ),
                              ),
                              Positioned(
                                top: bubbleSpace + (avatarRadius * 2) - 36,
                                left: (tileWidth + (avatarRadius * 2)) / 2 - 36,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.primary,
                                    shape: BoxShape.circle,
                                    border:
                                        Border.all(color: Colors.white, width: 2),
                                  ),
                                  padding: const EdgeInsets.all(6),
                                  child: const Icon(Icons.camera_alt,
                                      color: Colors.white, size: 18),
                                ),
                              ),
                              Positioned(
                                top: 8,
                                right: bubbleRightInset,
                                child: NoteOverlay(
                                  text: (_statusNote != null &&
                                          (_statusNoteExpires == null ||
                                              _statusNoteExpires!
                                                  .isAfter(DateTime.now())))
                                      ? _statusNote!
                                      : '',
                                  textColor: _noteTextColor,
                                  bgColor: _noteBgColor,
                                  maxWidth: isSmall ? 180 : 240,
                                  onEdit: _editStatusNote,
                                  emoji: _statusEmoji,
                                  onPickEmoji: _pickEmoji,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _QuickActionButton(
                          icon: Icons.brush_outlined,
                          label: 'Rame',
                          onTap: () {
                            _openFramePickerSheet();
                          },
                        ),
                        const SizedBox(width: 12),
                        _QuickActionButton(
                          icon: Icons.casino_outlined,
                          label: 'Random',
                          onTap: _randomizeFrame,
                        ),
                        const SizedBox(width: 12),
                        _QuickActionButton(
                          icon: Icons.edit_note_outlined,
                          label: 'Stare',
                          onTap: () {
                            _editStatusNote();
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _CompletionCard(percent: completeness),
                    const SizedBox(height: 12),
                    _glassField(
                      child: TextField(
                        controller: _nameCtrl,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Nume',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.person),
                        ),
                        onChanged: (_) => _markDirty(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _glassField(
                      child: TextField(
                        controller: _descCtrl,
                        maxLines: 4,
                        textInputAction: TextInputAction.newline,
                        decoration: const InputDecoration(
                          labelText: 'Descriere',
                          border: OutlineInputBorder(),
                          alignLabelWithHint: true,
                        ),
                        onChanged: (_) => _markDirty(),
                      ),
                    ),
                    SizedBox(height: isSmall ? 14 : 18),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text('Rama avatar',
                          style: Theme.of(context).textTheme.titleMedium),
                    ),
                    const SizedBox(height: 8),
                    FramePreviewStrip(
                      styles: kFrameStyles,
                      selected: _avatarFrame,
                      image: _currentAvatarImage(),
                      name: name,
                      onSelected: (s) => _setFrame(s),
                    ),
                    const SizedBox(height: 10),
                    _glassField(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.auto_fix_high, size: 18),
                              const SizedBox(width: 8),
                              const Text('Puterea haloului'),
                              const Spacer(),
                              Text('${(_haloStrength * 100).round()}%'),
                            ],
                          ),
                          Slider(
                            value: _haloStrength,
                            onChanged: (v) => setState(() => _haloStrength = v),
                            onChangeEnd: (_) => _persistUx(),
                          ),
                          const SizedBox(height: 6),
                          SwitchListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Reduce motion (efecte minime)'),
                            value: _reduceMotion,
                            onChanged: (b) {
                              setState(() => _reduceMotion = b);
                              if (b) {
                                _haloCtrl.stop();
                              } else if (!_haloCtrl.isAnimating) {
                                _haloCtrl.repeat();
                              }
                              _persistUx();
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    _glassField(
                      child: FutureBuilder<List<Sticker>>(
                        future: StickerService().loadStickers(),
                        builder: (context, snap) {
                          final list = snap.data ?? const <Sticker>[];
                          _stickers = list;
                          if (list.isEmpty) {
                            return const Padding(
                              padding: EdgeInsets.all(12),
                              child: Text(
                                  'Nu există autocolante disponibile. Adăugați PNG-uri în dosarul cu materiale/autocolante.'),
                            );
                          }
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: const [
                                  Icon(Icons.emoji_emotions_outlined, size: 18),
                                  SizedBox(width: 8),
                                  Text('Sticker'),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 12,
                                runSpacing: 12,
                                children: [
                                  for (final st in list)
                                    GestureDetector(
                                      onTap: () async {
                                        setState(() =>
                                            _avatarStickerAsset = st.asset ?? st.url);
                                        final sp =
                                            await SharedPreferences.getInstance();
                                        await sp.setString(
                                            'profile_avatar_sticker_asset',
                                            _avatarStickerAsset!);
                                        _markDirty();
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withOpacity(0.06),
                                          borderRadius: BorderRadius.circular(14),
                                          border: Border.all(
                                            color: (_avatarStickerAsset ==
                                                    (st.asset ?? st.url))
                                                ? Theme.of(context)
                                                    .colorScheme
                                                    .primary
                                                : Colors.white24,
                                          ),
                                        ),
                                        child: SizedBox(
                                          width: 72,
                                          height: 72,
                                          child: ClipRRect(
                                            borderRadius:
                                                BorderRadius.circular(12),
                                            child: st.asset != null
                                                ? Image.asset(
                                                    'assets/stickers/${st.asset!}',
                                                    fit: BoxFit.contain,
                                                    filterQuality:
                                                        FilterQuality.high,
                                                  )
                                                : Image.network(
                                                    st.url!,
                                                    fit: BoxFit.contain,
                                                    filterQuality:
                                                        FilterQuality.high,
                                                  ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  GestureDetector(
                                    onTap: () async {
                                      setState(() => _avatarStickerAsset = null);
                                      final sp = await SharedPreferences.getInstance();
                                      await sp.remove('profile_avatar_sticker_asset');
                                      _markDirty();
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 14, vertical: 10),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.06),
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(color: Colors.white24),
                                      ),
                                      child: const Icon(Icons.close, size: 18),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text('Social media',
                          style: Theme.of(context).textTheme.titleMedium),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 18,
                      runSpacing: 8,
                      alignment: WrapAlignment.center,
                      children: [
                        _socialButton('facebook', FontAwesomeIcons.facebookF,
                            _facebook, 'Facebook', 'profile_facebook'),
                        _socialButton('instagram', FontAwesomeIcons.instagram,
                            _instagram, 'Instagram', 'profile_instagram'),
                        _socialButton('tiktok', FontAwesomeIcons.tiktok, _tiktok,
                            'TikTok', 'profile_tiktok'),
                        _socialButton('youtube', FontAwesomeIcons.youtube,
                            _youtube, 'YouTube', 'profile_youtube'),
                      ],
                    ),
                    const SizedBox(height: 80),
                  ],
                ),
              ),
            ),
            bottomNavigationBar: SafeArea(
              top: false,
              child: AnimatedSlide(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOut,
                offset:
                    (_dirty && _authToken != null) ? Offset.zero : const Offset(0, 1),
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 220),
                  opacity: (_dirty && _authToken != null) ? 1 : 0,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: BackdropFilter(
                        filter: ui.ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                theme.colorScheme.surface.withOpacity(0.92),
                                theme.colorScheme.surface.withOpacity(0.82),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.12),
                            ),
                          ),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          child: Row(
                            children: [
                              const Icon(Icons.info_outline, size: 18),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Ai modificări nesalvate.',
                                  style: theme.textTheme.bodyMedium,
                                ),
                              ),
                              TextButton(
                                onPressed: _revertLocal,
                                child: const Text('Renunta'),
                              ),
                              const SizedBox(width: 6),
                              FilledButton.icon(
                                onPressed: _saving ? null : _saveProfileToServer,
                                icon: const Icon(Icons.save),
                                label: const Text('Salveaza'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<bool> _onBackPressed() async {
    if (!_dirty) return true;
    final r = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Modificări nesalvate'),
        content: const Text('Vrei să părăsești pagina fără să salvezi?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Rămâi')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Părăsește')),
        ],
      ),
    );
    return r ?? false;
  }

  Widget _glassField({required Widget child}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.white.withOpacity(0.18),
                Colors.white.withOpacity(0.05),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(color: Colors.white.withOpacity(0.16)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.28),
                blurRadius: 20,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          padding: const EdgeInsets.all(16),
          child: child,
        ),
      ),
    );
  }

  ImageProvider? _currentAvatarImage() {
    ImageProvider? img;
    if (_avatarUrl != null &&
        _avatarUrl!.isNotEmpty &&
        _avatarBytes == null &&
        (_avatarPath == null || _avatarPath!.isEmpty)) {
      final normalized = UiUtils.normalizeUploadUrl(_avatarUrl!);
      img = NetworkImage(normalized);
    }
    if (kIsWeb) {
      if (_avatarBytes != null && _avatarBytes!.isNotEmpty) {
        img = MemoryImage(_avatarBytes!);
      }
    } else {
      if (_avatarPath != null &&
          _avatarPath!.isNotEmpty &&
          File(_avatarPath!).existsSync()) {
        img = FileImage(File(_avatarPath!));
      }
    }
    return img;
  }

  List<Color> _colorsForFrame(String style) {
    switch (style) {
      case 'gradient-sunset':
        return const [Color(0xFFFF512F), Color(0xFFF09819)];
      case 'gradient-ocean':
        return const [Color(0xFF36D1DC), Color(0xFF5B86E5)];
      case 'gradient-forest':
        return const [Color(0xFF11998E), Color(0xFF38EF7D)];
      case 'gradient-violet':
        return const [Color(0xFF8E2DE2), Color(0xFF4A00E0)];
      case 'gradient-royal':
        return const [Color(0xFF141E30), Color(0xFF243B55)];
      case 'gradient-aurora':
        return const [Color(0xFF00C9FF), Color(0xFF92FE9D)];
      case 'gradient-plasma':
        return const [Color(0xFF12C2E9), Color(0xFFC471ED), Color(0xFFF64F59)];
      case 'gradient-gold':
        return const [Color(0xFFFFD700), Color(0xFFFFB700)];
      case 'gradient-silver':
        return const [Color(0xFFBCC6CC), Color(0xFFE5E4E2)];
      case 'rainbow':
        return const [
          Colors.red,
          Colors.orange,
          Colors.yellow,
          Colors.green,
          Colors.blue,
          Colors.indigo,
          Colors.purple,
        ];
      default:
        return [
          Theme.of(context).colorScheme.primary,
          Theme.of(context).colorScheme.primary.withOpacity(0.55),
        ];
    }
  }

  double _computeCompleteness() {
    int have = 0;
    const total = 4;
    if (_nameCtrl.text.trim().isNotEmpty) have++;
    if (_descCtrl.text.trim().isNotEmpty) have++;
    if ((_avatarUrl != null && _avatarUrl!.isNotEmpty) ||
        (!kIsWeb && _avatarPath != null && _avatarPath!.isNotEmpty) ||
        (kIsWeb && _avatarBytes != null && _avatarBytes!.isNotEmpty)) {
      have++;
    }
    if ((_facebook ?? '').isNotEmpty ||
        (_instagram ?? '').isNotEmpty ||
        (_tiktok ?? '').isNotEmpty ||
        (_youtube ?? '').isNotEmpty) {
      have++;
    }
    return have / total;
  }

  Color _colorFromHex(String? hex, Color fallback) {
    if (hex == null || hex.isEmpty) return fallback;
    final v = hex.replaceAll('#', '');
    try {
      if (v.length == 6) {
        return Color(int.parse('FF$v', radix: 16));
      } else if (v.length == 8) {
        return Color(int.parse(v, radix: 16));
      }
    } catch (_) {}
    return fallback;
  }

  String _hexFromColor(Color c) {
    final v = c.value.toRadixString(16).padLeft(8, '0');
    return '#${v.substring(2)}';
  }

  void _openAvatarViewer() {
    final img = _currentAvatarImage();
    if (img == null) return;
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => _AvatarViewer(image: img)));
  }
}

class _CompletionCard extends StatelessWidget {
  const _CompletionCard({required this.percent});
  final double percent;

  @override
  Widget build(BuildContext context) {
    final p = (percent * 100).round();
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.white.withOpacity(0.16),
                Colors.white.withOpacity(0.05),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(color: Colors.white.withOpacity(0.14)),
          ),
          child: Row(
            children: [
              const Icon(Icons.check_circle, size: 20),
              const SizedBox(width: 10),
              Expanded(child: Text('Profil completitudine: $p%')),
              const SizedBox(width: 12),
              SizedBox(
                width: 120,
                height: 8,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: percent.clamp(0, 1),
                    backgroundColor: Colors.white.withOpacity(0.12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HaloPainter extends CustomPainter {
  _HaloPainter({required this.rotation, required this.colors, required this.strength});

  final double rotation;
  final List<Color> colors;
  final double strength;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = math.min(size.width, size.height) / 2;

    final th = (radius * (0.10 + 0.22 * strength));
    final blur = 4 + 10 * strength;

    final shader = SweepGradient(
      colors: colors + [colors.first],
      startAngle: rotation,
      endAngle: rotation + math.pi * 2,
    ).createShader(Rect.fromCircle(center: center, radius: radius));

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = th
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, blur)
      ..shader = shader;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius - th / 2),
      0,
      math.pi * 2,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _HaloPainter old) =>
      old.rotation != rotation || old.colors != colors || old.strength != strength;
}

class _CountdownRingPainter extends CustomPainter {
  _CountdownRingPainter({
    required this.progress,
    required this.trackColor,
    required this.glowColor,
  });

  final double progress;
  final Color trackColor;
  final Color glowColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = math.min(size.width, size.height) / 2;
    final stroke = math.max(3.0, radius * 0.07);

    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = trackColor;

    final active = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = stroke
      ..color = glowColor.withOpacity(0.9)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);

    final arcRect = Rect.fromCircle(center: center, radius: radius - stroke / 2);
    canvas.drawArc(arcRect, -math.pi / 2, math.pi * 2, false, track);

    final sweep = (math.pi * 2) * progress.clamp(0, 1);
    if (sweep > 0) {
      canvas.drawArc(arcRect, -math.pi / 2, sweep, false, active);
    }
  }

  @override
  bool shouldRepaint(covariant _CountdownRingPainter old) =>
      old.progress != progress ||
      old.trackColor != trackColor ||
      old.glowColor != glowColor;
}

class _QuickActionButton extends StatelessWidget {
  const _QuickActionButton({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withOpacity(0.06),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              Icon(icon, size: 18),
              const SizedBox(width: 6),
              Text(label),
            ],
          ),
        ),
      ),
    );
  }
}

class _FramePickerSheet extends StatefulWidget {
  const _FramePickerSheet({
    required this.allStyles,
    required this.current,
    required this.favs,
    required this.categories,
    required this.colorsFor,
    required this.onPreviewStart,
    required this.onPreviewEnd,
    required this.onToggleFav,
  });
  final List<String> allStyles;
  final String current;
  final Set<String> favs;
  final Map<String, List<String>> categories;
  final List<Color> Function(String) colorsFor;
  final ValueChanged<String> onPreviewStart;
  final VoidCallback onPreviewEnd;
  final ValueChanged<String> onToggleFav;

  @override
  State<_FramePickerSheet> createState() => _FramePickerSheetState();
}

class _FramePickerSheetState extends State<_FramePickerSheet> {
  String _category = 'All';
  String _query = '';
  late List<String> _filtered;

  @override
  void initState() {
    super.initState();
    _filtered = _buildList();
  }

  List<String> _buildList() {
    Iterable<String> src = widget.allStyles;
    final prefixes = widget.categories[_category] ?? [];
    if (prefixes.isNotEmpty) {
      src = src.where((s) => prefixes.any((p) => s.startsWith(p)) ||
          (prefixes.contains('rainbow') && s == 'rainbow'));
    }
    if (_query.isNotEmpty) {
      src = src.where((s) => s.toLowerCase().contains(_query.toLowerCase()));
    }
    final favs = src.where((s) => widget.favs.contains(s)).toList();
    final rest = src.where((s) => !widget.favs.contains(s)).toList();
    return [...favs, ...rest];
  }

  void _applyFilters() => setState(() => _filtered = _buildList());

  int _calcCrossAxisCount(double w) {
    if (w < 340) return 3;
    if (w < 480) return 4;
    if (w < 680) return 5;
    return 6;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DraggableScrollableSheet(
      initialChildSize: 0.72,
      minChildSize: 0.45,
      maxChildSize: 0.95,
      builder: (ctx, scroll) {
        return Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.35), blurRadius: 24)],
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    const Icon(Icons.brush_outlined),
                    const SizedBox(width: 8),
                    Text('Keretválasztó', style: theme.textTheme.titleMedium),
                    const Spacer(),
                    if (widget.favs.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.06),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.star, size: 16),
                            const SizedBox(width: 6),
                            Text('${widget.favs.length}')
                          ],
                        ),
                      ),
                    const SizedBox(width: 6),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: TextField(
                  onChanged: (v) {
                    _query = v;
                    _applyFilters();
                  },
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search),
                    hintText: 'Keresés (pl. neon, violet, gold)',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    isDense: true,
                  ),
                ),
              ),
              SizedBox(
                height: 42,
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  scrollDirection: Axis.horizontal,
                  itemBuilder: (_, i) {
                    final name = widget.categories.keys.elementAt(i);
                    final selected = name == _category;
                    return ChoiceChip(
                      label: Text(name),
                      selected: selected,
                      onSelected: (_) {
                        _category = name;
                        _applyFilters();
                      },
                    );
                  },
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemCount: widget.categories.length,
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: LayoutBuilder(
                  builder: (_, c) {
                    final cols = _calcCrossAxisCount(c.maxWidth);
                    return GridView.builder(
                      controller: scroll,
                      padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: cols,
                        childAspectRatio: .88,
                        mainAxisSpacing: 10,
                        crossAxisSpacing: 10,
                      ),
                      itemCount: _filtered.length,
                      itemBuilder: (_, i) {
                        final style = _filtered[i];
                        final isFav = widget.favs.contains(style);
                        final isSelected = style == widget.current;
                        return GestureDetector(
                          onTap: () => Navigator.pop(context, style),
                          onLongPressStart: (_) => widget.onPreviewStart(style),
                          onLongPressEnd: (_) => widget.onPreviewEnd(),
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.03),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isSelected
                                    ? Theme.of(context).colorScheme.primary
                                    : Colors.white.withOpacity(0.08),
                                width: isSelected ? 2 : 1,
                              ),
                            ),
                            padding: const EdgeInsets.all(8),
                            child: Column(
                              children: [
                                Expanded(
                                  child: CustomPaint(
                                    painter: _SwatchPainter(
                                      colors: widget.colorsFor(style),
                                    ),
                                    child: const SizedBox.expand(),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        style.replaceAll('-', '\u200B-'),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontSize: 11),
                                      ),
                                    ),
                                    GestureDetector(
                                      onTap: () => widget.onToggleFav(style),
                                      child: Icon(
                                        isFav ? Icons.star : Icons.star_border,
                                        size: 16,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SwatchPainter extends CustomPainter {
  _SwatchPainter({required this.colors});
  final List<Color> colors;

  @override
  void paint(Canvas canvas, Size size) {
    final r = size.shortestSide / 2 - 4;
    final c = Offset(size.width / 2, size.height / 2);

    final bg = Paint()..color = Colors.black.withOpacity(0.35);
    canvas.drawCircle(c, r, bg);

    final stroke = (r * 0.32).clamp(6, 18).toDouble();
    final ringRect = Rect.fromCircle(center: c, radius: r - stroke / 2);
    final shader = SweepGradient(
      colors: [...colors, colors.first],
      startAngle: 0,
      endAngle: math.pi * 2,
    ).createShader(ringRect);

    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..shader = shader
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);

    canvas.drawArc(ringRect, 0, math.pi * 2, false, ring);
  }

  @override
  bool shouldRepaint(covariant _SwatchPainter oldDelegate) =>
      oldDelegate.colors != colors;
}

class _AvatarViewer extends StatefulWidget {
  const _AvatarViewer({required this.image});
  final ImageProvider image;

  @override
  State<_AvatarViewer> createState() => _AvatarViewerState();
}

class _AvatarViewerState extends State<_AvatarViewer> {
  final TransformationController _tc = TransformationController();

  @override
  void dispose() {
    _tc.dispose();
    super.dispose();
  }

  void _resetOrZoom() {
    final m = _tc.value;
    if ((m.storage[0] - 1).abs() < 0.01) {
      _tc.value = Matrix4.identity()..scale(2.2);
    } else {
      _tc.value = Matrix4.identity();
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onDoubleTap: _resetOrZoom,
      onTap: () => Navigator.pop(context),
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Stack(
            children: [
              Center(
                child: InteractiveViewer(
                  transformationController: _tc,
                  minScale: 1,
                  maxScale: 4,
                  child: Hero(
                    tag: 'profile_avatar_hero',
                    child: ClipOval(
                      child: Image(
                        image: widget.image,
                        width: 320,
                        height: 320,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 8,
                left: 8,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SheetAction {
  const _SheetAction({
    required this.icon,
    required this.label,
    this.onSelected,
    this.isDestructive = false,
  });

  final IconData icon;
  final String label;
  final FutureOr<void> Function()? onSelected;
  final bool isDestructive;
}
