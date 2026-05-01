import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import '../app/app_theme.dart';
import '../services/farm_advisory_service.dart';

class CropAdvisorScreen extends StatefulWidget {
  const CropAdvisorScreen({super.key});
  @override
  State<CropAdvisorScreen> createState() => _CropAdvisorScreenState();
}

class _CropAdvisorScreenState extends State<CropAdvisorScreen>
    with TickerProviderStateMixin {
  // ── Controllers ────────────────────────────────────────────────────────────
  final _landCtrl    = TextEditingController();
  final _cropCtrl    = TextEditingController();
  final _pincodeCtrl = TextEditingController();
  final _formKey     = GlobalKey<FormState>();

  String _soil  = 'black';
  String _water = 'medium';

  bool   _loading = false;
  String _error   = '';
  FarmAdvisoryResult? _result;

  late final AnimationController _shimmerAnim;
  late final FarmAdvisoryService _service;

  static const _soils  = ['alluvial','black','red','laterite','sandy','loamy','clay','other'];
  static const _waters = ['low','medium','high'];

  @override
  void initState() {
    super.initState();
    _service = FarmAdvisoryService();
    _shimmerAnim = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..repeat();
  }

  @override
  void dispose() {
    _landCtrl.dispose(); _cropCtrl.dispose(); _pincodeCtrl.dispose();
    _shimmerAnim.dispose(); _service.dispose();
    super.dispose();
  }

  // ── Submit ─────────────────────────────────────────────────────────────────
  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() { _loading = true; _error = ''; _result = null; });
    try {
      final res = await _service.analyze(
        land:    double.parse(_landCtrl.text.trim()),
        crop:    _cropCtrl.text.trim(),
        soil:    _soil,
        water:   _water,
        pincode: _pincodeCtrl.text.trim(),
      );
      if (!mounted) return;
      setState(() { _result = res; _loading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = e.toString().replaceFirst('Exception: ', ''); _loading = false; });
    }
  }

  void _reset() => setState(() { _result = null; _error = ''; });

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppTheme.background : AppTheme.backgroundLight;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: _result != null
            ? _ResultView(result: _result!, isDark: isDark, onReset: _reset)
            : _FormView(
                formKey:     _formKey,
                landCtrl:    _landCtrl,
                cropCtrl:    _cropCtrl,
                pincodeCtrl: _pincodeCtrl,
                soil:        _soil,
                water:       _water,
                soils:       _soils,
                waters:      _waters,
                loading:     _loading,
                error:       _error,
                shimmer:     _shimmerAnim,
                isDark:      isDark,
                onSoilChanged:  (v) => setState(() => _soil  = v!),
                onWaterChanged: (v) => setState(() => _water = v!),
                onSubmit:        _submit,
              ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// FORM VIEW
// ═══════════════════════════════════════════════════════════════════════════════
class _FormView extends StatelessWidget {
  const _FormView({
    required this.formKey, required this.landCtrl, required this.cropCtrl,
    required this.pincodeCtrl, required this.soil, required this.water,
    required this.soils, required this.waters, required this.loading,
    required this.error, required this.shimmer, required this.isDark,
    required this.onSoilChanged, required this.onWaterChanged, required this.onSubmit,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController landCtrl, cropCtrl, pincodeCtrl;
  final String soil, water;
  final List<String> soils, waters;
  final bool loading;
  final String error;
  final AnimationController shimmer;
  final bool isDark;
  final ValueChanged<String?> onSoilChanged, onWaterChanged;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final card = isDark ? AppTheme.surface : Colors.white;
    final border = isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.07);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      child: Form(
        key: formKey,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          // ── Hero header
          _HeroHeader(isDark: isDark),
          const SizedBox(height: 20),

          // ── Input card
          _Card(isDark: isDark, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _SectionTitle('Farm Details', Icons.agriculture_rounded),
            const SizedBox(height: 14),
            _Field(ctrl: landCtrl, label: 'Land Size (acres)', hint: 'e.g. 2.5',
              icon: Icons.straighten_rounded, isDark: isDark,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              validator: (v) {
                final n = double.tryParse(v ?? '');
                if (n == null || n < 0.1) return 'Enter valid land size (min 0.1)';
                return null;
              }),
            const SizedBox(height: 12),
            _Field(ctrl: cropCtrl, label: 'Crop Type', hint: 'e.g. paddy, wheat, cotton',
              icon: Icons.grass_rounded, isDark: isDark,
              validator: (v) => (v?.trim().length ?? 0) < 2 ? 'Enter a valid crop name' : null),
            const SizedBox(height: 12),
            _Field(ctrl: pincodeCtrl, label: 'Pincode', hint: '6-digit pincode',
              icon: Icons.location_on_rounded, isDark: isDark,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)],
              validator: (v) => (v?.length ?? 0) != 6 ? 'Enter 6-digit pincode' : null),
            const SizedBox(height: 16),
            _DropdownRow(
              label: 'Soil Type', icon: Icons.layers_rounded,
              value: soil, items: soils, isDark: isDark, onChanged: onSoilChanged,
              card: card, border: border,
            ),
            const SizedBox(height: 12),
            _DropdownRow(
              label: 'Water Availability', icon: Icons.water_drop_rounded,
              value: water, items: waters, isDark: isDark, onChanged: onWaterChanged,
              card: card, border: border,
            ),
          ])),

          const SizedBox(height: 16),

          // ── Error
          if (error.isNotEmpty) _ErrorBanner(error),
          if (error.isNotEmpty) const SizedBox(height: 12),

          // ── Submit button
          loading ? _LoadingCard(shimmer: shimmer, isDark: isDark) : _SubmitButton(onSubmit),
        ]),
      ),
    );
  }
}

// ── Hero Header ───────────────────────────────────────────────────────────────
class _HeroHeader extends StatelessWidget {
  const _HeroHeader({required this.isDark});
  final bool isDark;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.primary.withOpacity(isDark ? 0.18 : 0.12),
                   const Color(0xFF00A3FF).withOpacity(isDark ? 0.10 : 0.06)],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.primary.withOpacity(0.20)),
      ),
      child: Row(children: [
        Container(
          width: 52, height: 52,
          decoration: BoxDecoration(gradient: AppTheme.primaryGradient, borderRadius: BorderRadius.circular(14),
            boxShadow: [BoxShadow(color: AppTheme.primary.withOpacity(0.4), blurRadius: 16, offset: const Offset(0, 4))]),
          child: const Icon(Icons.agriculture_rounded, color: Colors.white, size: 26),
        ),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('AI Crop Advisor', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 3),
          Text('Personalised weather-aware farming plan powered by Groq AI',
            style: Theme.of(context).textTheme.bodySmall),
        ])),
      ]),
    );
  }
}

// ── Reusable card ─────────────────────────────────────────────────────────────
class _Card extends StatelessWidget {
  const _Card({required this.isDark, required this.child});
  final bool isDark; final Widget child;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: isDark ? AppTheme.surface : Colors.white,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.07)),
      boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.30 : 0.06), blurRadius: 20, offset: const Offset(0, 4))],
    ),
    child: child,
  );
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text, this.icon);
  final String text; final IconData icon;
  @override
  Widget build(BuildContext context) => Row(children: [
    Icon(icon, size: 18, color: AppTheme.primary),
    const SizedBox(width: 8),
    Text(text, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700, color: AppTheme.primary)),
  ]);
}

class _Field extends StatelessWidget {
  const _Field({required this.ctrl, required this.label, required this.hint,
    required this.icon, required this.isDark, this.keyboardType,
    this.inputFormatters, this.validator});
  final TextEditingController ctrl;
  final String label, hint;
  final IconData icon;
  final bool isDark;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final String? Function(String?)? validator;
  @override
  Widget build(BuildContext context) => TextFormField(
    controller: ctrl, keyboardType: keyboardType, inputFormatters: inputFormatters,
    validator: validator, textCapitalization: TextCapitalization.words,
    style: Theme.of(context).textTheme.bodyMedium,
    decoration: InputDecoration(label: Text(label), hintText: hint, prefixIcon: Icon(icon, size: 20)),
  );
}

class _DropdownRow extends StatelessWidget {
  const _DropdownRow({required this.label, required this.icon, required this.value,
    required this.items, required this.isDark, required this.onChanged,
    required this.card, required this.border});
  final String label; final IconData icon; final String value;
  final List<String> items; final bool isDark;
  final ValueChanged<String?> onChanged;
  final Color card, border;
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Row(children: [Icon(icon, size: 16, color: AppTheme.primary), const SizedBox(width: 6),
      Text(label, style: Theme.of(context).textTheme.labelMedium?.copyWith(color: AppTheme.primary, fontWeight: FontWeight.w600))]),
    const SizedBox(height: 8),
    DropdownButtonFormField<String>(
      value: value,
      dropdownColor: isDark ? AppTheme.surface : Colors.white,
      style: Theme.of(context).textTheme.bodyMedium,
      decoration: InputDecoration(contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14)),
      items: items.map((s) => DropdownMenuItem(value: s, child: Text(s[0].toUpperCase() + s.substring(1)))).toList(),
      onChanged: onChanged,
    ),
  ]);
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner(this.message);
  final String message;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    decoration: BoxDecoration(color: Colors.redAccent.withOpacity(0.10),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: Colors.redAccent.withOpacity(0.30))),
    child: Row(children: [
      const Icon(Icons.error_outline_rounded, size: 18, color: Colors.redAccent),
      const SizedBox(width: 10),
      Expanded(child: Text(message, style: const TextStyle(color: Colors.redAccent, fontSize: 13))),
    ]),
  );
}

class _SubmitButton extends StatelessWidget {
  const _SubmitButton(this.onTap);
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      height: 56,
      decoration: BoxDecoration(gradient: AppTheme.primaryGradient, borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: AppTheme.primary.withOpacity(0.40), blurRadius: 18, offset: const Offset(0, 6))]),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 20),
        const SizedBox(width: 10),
        Text('Generate Crop Advisory', style: Theme.of(context).textTheme.labelLarge?.copyWith(color: Colors.white, fontSize: 15)),
      ]),
    ),
  );
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard({required this.shimmer, required this.isDark});
  final AnimationController shimmer; final bool isDark;
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: shimmer,
    builder: (_, __) {
      final t = shimmer.value;
      return Container(
        height: 56,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [AppTheme.primary.withOpacity(0.5), AppTheme.primary, AppTheme.primary.withOpacity(0.5)],
            stops: [(t - 0.3).clamp(0.0, 1.0), t.clamp(0.0, 1.0), (t + 0.3).clamp(0.0, 1.0)],
            begin: Alignment.centerLeft, end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          const SizedBox(width: 20, height: 20,
            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
          const SizedBox(width: 12),
          Text('Analyzing your farm…', style: Theme.of(context).textTheme.labelLarge?.copyWith(color: Colors.white)),
        ]),
      );
    },
  );
}

// ═══════════════════════════════════════════════════════════════════════════════
// RESULT VIEW  (stateful — manages PDF download state)
// ═══════════════════════════════════════════════════════════════════════════════
class _ResultView extends StatefulWidget {
  const _ResultView({required this.result, required this.isDark, required this.onReset});
  final FarmAdvisoryResult result;
  final bool isDark;
  final VoidCallback onReset;
  @override
  State<_ResultView> createState() => _ResultViewState();
}

class _ResultViewState extends State<_ResultView> {
  bool _pdfLoading = false;

  Future<void> _downloadPDF() async {
    setState(() => _pdfLoading = true);
    try {
      final service = FarmAdvisoryService();
      final bytes = await service.downloadPDF(
        input:    widget.result.inputSnapshot,
        location: widget.result.location,
        weather:  widget.result.weather,
        plan:     widget.result.plan,
      );
      service.dispose();

      // Save to temp dir and open
      final dir  = await getTemporaryDirectory();
      final crop = (widget.result.inputSnapshot['crop'] ?? 'advisory')
          .toString().replaceAll(' ', '-');
      final file = File('${dir.path}/KrishiMitra-$crop.pdf');
      await file.writeAsBytes(bytes);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('PDF saved: ${file.path.split('/').last}'),
          action: SnackBarAction(
            label: 'OK',
            onPressed: () {},
          ),
          duration: const Duration(seconds: 4),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('PDF failed: ${e.toString().replaceFirst('Exception: ', '')}'),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) setState(() => _pdfLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final w = widget.result.weather.current;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        // ── Location + weather banner
        _InfoBanner(result: widget.result, isDark: widget.isDark),
        const SizedBox(height: 14),

        // ── Weather chips
        _WeatherRow(current: w),
        const SizedBox(height: 14),

        // ── 5-day forecast
        if (widget.result.weather.forecast.isNotEmpty) ...[
          _ForecastStrip(forecast: widget.result.weather.forecast, isDark: widget.isDark),
          const SizedBox(height: 14),
        ],

        // ── Advisory plan card
        _PlanCard(plan: widget.result.plan, isDark: widget.isDark),
        const SizedBox(height: 16),

        // ── Download PDF button (full width, accent style)
        _PdfButton(loading: _pdfLoading, onTap: _downloadPDF),
        const SizedBox(height: 10),

        // ── Secondary actions row
        Row(children: [
          Expanded(child: OutlinedButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: widget.result.plan));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Advisory copied to clipboard!')));
            },
            icon: const Icon(Icons.copy_rounded, size: 18),
            label: const Text('Copy Text'),
          )),
          const SizedBox(width: 12),
          Expanded(child: ElevatedButton.icon(
            onPressed: widget.onReset,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('New Query'),
          )),
        ]),
      ]),
    );
  }
}

class _InfoBanner extends StatelessWidget {
  const _InfoBanner({required this.result, required this.isDark});
  final FarmAdvisoryResult result; final bool isDark;
  @override
  Widget build(BuildContext context) {
    final loc = result.location;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.primary.withOpacity(isDark ? 0.18 : 0.12),
                   const Color(0xFF00A3FF).withOpacity(isDark ? 0.10 : 0.07)],
          begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.primary.withOpacity(0.22)),
      ),
      child: Row(children: [
        Container(width: 46, height: 46,
          decoration: BoxDecoration(gradient: AppTheme.primaryGradient, shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: AppTheme.primary.withOpacity(0.35), blurRadius: 12, offset: const Offset(0,3))]),
          child: const Icon(Icons.location_on_rounded, color: Colors.white, size: 22)),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${loc.district}, ${loc.state}',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
          Text('📍 ${loc.postOfficeName} · ${loc.pincode}',
            style: Theme.of(context).textTheme.bodySmall),
          Text('⚡ Generated in ${(result.processingTimeMs / 1000).toStringAsFixed(1)}s',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppTheme.primary)),
        ])),
      ]),
    );
  }
}

class _WeatherRow extends StatelessWidget {
  const _WeatherRow({required this.current});
  final FarmWeatherCurrent current;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      _WChip(Icons.thermostat_rounded, '${current.temperature}°C', Colors.orange),
      const SizedBox(width: 8),
      _WChip(Icons.water_drop_rounded, '${current.humidity}%', Colors.blue),
      const SizedBox(width: 8),
      // Expanded absorbs remaining row space — condition text can be long
      Expanded(
        child: _WChip(Icons.cloud_rounded, current.condition, Colors.blueGrey),
      ),
    ],
  );
}

class _WChip extends StatelessWidget {
  const _WChip(this.icon, this.label, this.color);
  final IconData icon;
  final String   label;
  final Color    color;
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color:  color.withOpacity(isDark ? 0.14 : 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ForecastStrip extends StatelessWidget {
  const _ForecastStrip({required this.forecast, required this.isDark});
  final List<FarmWeatherDay> forecast; final bool isDark;
  @override
  Widget build(BuildContext context) => SizedBox(
    height: 82,
    child: ListView.separated(
      scrollDirection: Axis.horizontal,
      itemCount: forecast.length,
      separatorBuilder: (_, __) => const SizedBox(width: 8),
      itemBuilder: (ctx, i) {
        final d = forecast[i];
        final dateStr = d.date.length >= 5 ? d.date.substring(5) : d.date;
        return Container(
          width: 72,
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isDark ? AppTheme.surface : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.07))),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text(dateStr, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text('${d.temperature}°', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppTheme.primary)),
            const SizedBox(height: 2),
            Text('${d.humidity}%', style: const TextStyle(fontSize: 10, color: Colors.blueGrey)),
          ]),
        );
      },
    ),
  );
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({required this.plan, required this.isDark});
  final String plan; final bool isDark;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: isDark ? AppTheme.surface : Colors.white,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.07)),
      boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.30 : 0.06), blurRadius: 20, offset: const Offset(0,4))],
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Container(width: 36, height: 36,
          decoration: BoxDecoration(gradient: AppTheme.primaryGradient, borderRadius: BorderRadius.circular(10)),
          child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 18)),
        const SizedBox(width: 10),
        Text('Your Personalised Advisory', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
      ]),
      const SizedBox(height: 14),
      const Divider(height: 1),
      const SizedBox(height: 14),
      SelectableText(plan,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.6, fontSize: 13.5)),
    ]),
  );
}

// ── PDF Download Button ───────────────────────────────────────────────────────
class _PdfButton extends StatelessWidget {
  const _PdfButton({required this.loading, required this.onTap});
  final bool loading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: loading ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 54,
        decoration: BoxDecoration(
          gradient: loading
              ? null
              : const LinearGradient(
                  colors: [Color(0xFF00A3FF), Color(0xFF0066CC)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
          color: loading ? const Color(0xFF00A3FF).withOpacity(0.40) : null,
          borderRadius: BorderRadius.circular(16),
          boxShadow: loading
              ? null
              : [
                  BoxShadow(
                    color: const Color(0xFF00A3FF).withOpacity(0.40),
                    blurRadius: 16,
                    offset: const Offset(0, 5),
                  )
                ],
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          if (loading)
            const SizedBox(
              width: 18, height: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            )
          else
            const Icon(Icons.picture_as_pdf_rounded, color: Colors.white, size: 20),
          const SizedBox(width: 10),
          Text(
            loading ? 'Generating PDF…' : 'Download PDF Report',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700),
          ),
        ]),
      ),
    );
  }
}
