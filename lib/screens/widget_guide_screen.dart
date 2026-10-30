import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:icnative/services/locale_service.dart';
import 'package:icnative/settings/theme_colors.dart';

class WidgetGuideScreen extends StatefulWidget {
  const WidgetGuideScreen({super.key});

  @override
  State<WidgetGuideScreen> createState() => _WidgetGuideScreenState();
}

class _WidgetGuideScreenState extends State<WidgetGuideScreen> {
  static const MethodChannel _pinChannel = MethodChannel('com.abom.utas.utas/widget_pin');

  bool _isPinning = false;
  String? _statusMessage;

  Future<void> _pinWidget(String widgetType) async {
    setState(() {
      _isPinning = true;
      _statusMessage = null;
    });

    try {
      final bool? success = await _pinChannel.invokeMethod<bool>(
        'requestPinWidget',
        {'type': widgetType},
      );

      if (!mounted) return;

      if (success == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: OrbitColors.buttonPrimary,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    tr('wg_pin_success'),
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        );
      } else {
        setState(() {
          _statusMessage = tr('wg_pin_not_supported');
        });
      }
    } catch (e) {
      debugPrint('Widget pin exception: $e');
      if (mounted) {
        setState(() {
          _statusMessage = tr('wg_pin_not_supported');
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isPinning = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: OrbitColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: OrbitColors.deepOlive),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          tr('wg_title'),
          style: const TextStyle(
            color: OrbitColors.deepOlive,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Description Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: OrbitColors.surfaceCream,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: OrbitColors.buttonPrimary.withValues(alpha: 0.25)),
                boxShadow: [
                  BoxShadow(
                    color: OrbitColors.deepOlive.withValues(alpha: 0.06),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: OrbitColors.buttonPrimary.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.widgets_rounded,
                      color: OrbitColors.buttonPrimary,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Orbit Widgets',
                          style: TextStyle(
                            color: OrbitColors.deepOlive,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          tr('wg_subtitle'),
                          style: TextStyle(
                            color: OrbitColors.deepOlive.withValues(alpha: 0.75),
                            fontSize: 12,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // SECTION 1: 1-Tap Quick Pinning
            Text(
              tr('wg_quick_pin_section'),
              style: const TextStyle(
                color: OrbitColors.deepOlive,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 12),

            // Card 1: Galaxy Orbit Widget (Kiểu 10)
            _buildWidgetActionCard(
              title: 'Kiểu 10: Thiên Hà Vệ Tinh Nổi',
              subtitle: 'Lõi ảnh trung tâm sắc nét cùng các vệ tinh bạn bè quay quanh, tương phản cao trên nền sáng.',
              tag: 'Phổ biến nhất',
              icon: Icons.flare_rounded,
              color: OrbitColors.deepOlive,
              onPin: () => _pinWidget('galaxy'),
              btnLabel: tr('wg_pin_galaxy_btn'),
            ),

            const SizedBox(height: 16),

            // Card 2: Zen Pebble Widget (Kiểu 3)
            _buildWidgetActionCard(
              title: 'Kiểu 3: Đá Cuội Gợn Sóng Tự Nhiên',
              subtitle: 'Đường cong đá cuội hữu cơ kết hợp các gợn sóng lan tỏa màu đất nung đậm chất nghệ thuật.',
              tag: 'Tối giản & Nghệ thuật',
              icon: Icons.water_drop_rounded,
              color: OrbitColors.terracotta,
              onPin: () => _pinWidget('pebble'),
              btnLabel: tr('wg_pin_pebble_btn'),
            ),

            if (_statusMessage != null) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.amber.shade700),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline_rounded, color: Colors.amber.shade900, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _statusMessage!,
                        style: TextStyle(color: Colors.amber.shade900, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 28),

            // SECTION 2: Manual Guide
            Text(
              tr('wg_manual_guide_title'),
              style: const TextStyle(
                color: OrbitColors.deepOlive,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 12),

            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: OrbitColors.surfaceCream,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: OrbitColors.buttonPrimary.withValues(alpha: 0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildStepItem(tr('wg_step_1')),
                  const SizedBox(height: 10),
                  _buildStepItem(tr('wg_step_2')),
                  const SizedBox(height: 10),
                  _buildStepItem(tr('wg_step_3')),
                  const SizedBox(height: 10),
                  _buildStepItem(tr('wg_step_4')),
                ],
              ),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildWidgetActionCard({
    required String title,
    required String subtitle,
    required String tag,
    required IconData icon,
    required Color color,
    required VoidCallback onPin,
    required String btnLabel,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: OrbitColors.surfaceCream,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.35), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: OrbitColors.deepOlive,
                    fontWeight: FontWeight.bold,
                    fontSize: 14.5,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  tag,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(
              color: OrbitColors.deepOlive.withValues(alpha: 0.7),
              fontSize: 12,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton.icon(
              onPressed: _isPinning ? null : onPin,
              style: ElevatedButton.styleFrom(
                backgroundColor: color,
                foregroundColor: OrbitColors.textLight,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 2,
              ),
              icon: const Icon(Icons.touch_app_rounded, size: 18),
              label: Text(
                btnLabel,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepItem(String stepText) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.check_circle_outline_rounded, size: 16, color: OrbitColors.buttonPrimary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            stepText,
            style: const TextStyle(
              color: OrbitColors.deepOlive,
              fontSize: 12.5,
              height: 1.35,
            ),
          ),
        ),
      ],
    );
  }
}
