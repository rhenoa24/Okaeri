import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../../models/profile_details.dart';

class BasicInfoTab extends StatelessWidget {
  final bool isEditing;
  final ProfileDetails details;
  final ValueChanged<ProfileDetails> onChanged;

  const BasicInfoTab({
    super.key,
    required this.isEditing,
    required this.details,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return isEditing
        ? _BasicInfoEditView(details: details, onChanged: onChanged)
        : _BasicInfoReadView(details: details);
  }
}

// ───────────────────────── Read view ─────────────────────────

class _BasicInfoReadView extends StatelessWidget {
  final ProfileDetails details;
  const _BasicInfoReadView({required this.details});

  @override
  Widget build(BuildContext context) {
    if (details.isEmpty) {
      return const _EmptyBasicInfo();
    }

    final heightLabel = details.heightCm == null
        ? null
        : '${details.heightCm!.toStringAsFixed(0)} cm';
    final weightLabel = details.weightKg == null
        ? null
        : '${details.weightKg!.toStringAsFixed(0)} kg';
    final birthdayLabel = details.birthday == null
        ? null
        : DateFormat('MMMM d, yyyy').format(details.birthday!);

    return ListView(
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        32 + MediaQuery.of(context).padding.bottom,
      ),
      children: [
        _InfoRow(
          icon: Icons.cake_outlined,
          label: 'Birthday',
          value: birthdayLabel,
        ),
        _InfoRow(icon: Icons.straighten, label: 'Height', value: heightLabel),
        _InfoRow(
          icon: Icons.monitor_weight_outlined,
          label: 'Weight',
          value: weightLabel,
        ),
        _InfoRow(
          icon: Icons.home_outlined,
          label: 'Home Address',
          value: _orNull(details.homeAddress),
        ),
        _InfoRow(
          icon: Icons.work_outline,
          label: 'Occupation',
          value: _orNull(details.occupation),
        ),
        _InfoRow(
          icon: Icons.business_outlined,
          label: 'Company',
          value: _orNull(details.company),
        ),
        _InfoRow(
          icon: Icons.phone_outlined,
          label: 'Contact Number',
          value: _orNull(details.contactNumber),
        ),
        _InfoRow(
          icon: Icons.psychology_outlined,
          label: 'MBTI',
          value: details.mbti,
        ),
        _InfoRow(
          icon: Icons.auto_awesome_outlined,
          label: 'Zodiac',
          value: details.zodiac,
        ),
        const SizedBox(height: 4),
        _HobbiesRow(hobbies: details.hobbies),
      ],
    );
  }

  String? _orNull(String s) => s.isEmpty ? null : s;
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? value;
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final outline = Theme.of(context).colorScheme.outline;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 12, color: outline)),
                const SizedBox(height: 2),
                Text(
                  value ?? 'Not set',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    fontStyle: value == null
                        ? FontStyle.italic
                        : FontStyle.normal,
                    color: value == null ? outline : null,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HobbiesRow extends StatelessWidget {
  final List<String> hobbies;
  const _HobbiesRow({required this.hobbies});

  @override
  Widget build(BuildContext context) {
    final outline = Theme.of(context).colorScheme.outline;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.interests_outlined,
            size: 20,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Hobbies', style: TextStyle(fontSize: 12, color: outline)),
                const SizedBox(height: 6),
                hobbies.isEmpty
                    ? Text(
                        'Not set',
                        style: TextStyle(
                          fontSize: 15,
                          fontStyle: FontStyle.italic,
                          color: outline,
                        ),
                      )
                    : Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: hobbies
                            .map(
                              (h) => Chip(
                                label: Text(h),
                                visualDensity: VisualDensity.compact,
                                backgroundColor: Theme.of(
                                  context,
                                ).colorScheme.surfaceContainer,
                                side: BorderSide.none,
                              ),
                            )
                            .toList(),
                      ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyBasicInfo extends StatelessWidget {
  const _EmptyBasicInfo();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.badge_outlined,
              size: 40,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 12),
            Text(
              'No basic info yet',
              style: TextStyle(color: Theme.of(context).colorScheme.outline),
            ),
            const SizedBox(height: 4),
            Text(
              'Tap the pencil to add birthday, height, and more.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ───────────────────────── Edit view ─────────────────────────

class _BasicInfoEditView extends StatefulWidget {
  final ProfileDetails details;
  final ValueChanged<ProfileDetails> onChanged;
  const _BasicInfoEditView({required this.details, required this.onChanged});

  @override
  State<_BasicInfoEditView> createState() => _BasicInfoEditViewState();
}

class _BasicInfoEditViewState extends State<_BasicInfoEditView> {
  late final TextEditingController _heightController;
  late final TextEditingController _weightController;
  late final TextEditingController _occupationController;
  late final TextEditingController _homeAddressController;
  late final TextEditingController _companyController;
  late final TextEditingController _contactNumberController;
  late final TextEditingController _hobbyInputController;

  @override
  void initState() {
    super.initState();
    _heightController = TextEditingController(
      text: widget.details.heightCm?.toStringAsFixed(0) ?? '',
    );
    _weightController = TextEditingController(
      text: widget.details.weightKg?.toStringAsFixed(0) ?? '',
    );
    _occupationController = TextEditingController(
      text: widget.details.occupation,
    );
    _homeAddressController = TextEditingController(
      text: widget.details.homeAddress,
    );

    _companyController = TextEditingController(text: widget.details.company);

    _contactNumberController = TextEditingController(
      text: widget.details.contactNumber,
    );
    _hobbyInputController = TextEditingController();
  }

  @override
  void dispose() {
    _heightController.dispose();
    _weightController.dispose();
    _occupationController.dispose();
    _homeAddressController.dispose();
    _companyController.dispose();
    _contactNumberController.dispose();
    _hobbyInputController.dispose();
    super.dispose();
  }

  void _emit(ProfileDetails next) => widget.onChanged(next);

  Future<void> _pickBirthday() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: widget.details.birthday ?? DateTime(now.year - 25),
      firstDate: DateTime(now.year - 100),
      lastDate: now,
    );
    if (picked != null) _emit(widget.details.copyWith(birthday: picked));
  }

  void _addHobby() {
    final value = _hobbyInputController.text.trim();
    if (value.isEmpty) return;
    if (widget.details.hobbies.contains(value)) {
      _hobbyInputController.clear();
      return;
    }
    _emit(widget.details.copyWith(hobbies: [...widget.details.hobbies, value]));
    _hobbyInputController.clear();
  }

  void _removeHobby(String hobby) {
    _emit(
      widget.details.copyWith(
        hobbies: widget.details.hobbies.where((h) => h != hobby).toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final birthdayLabel = widget.details.birthday == null
        ? 'Select date'
        : DateFormat('MMMM d, yyyy').format(widget.details.birthday!);

    return ListView(
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        32 + MediaQuery.of(context).padding.bottom,
      ),
      children: [
        _FieldLabel('Birthday'),
        InkWell(
          onTap: _pickBirthday,
          borderRadius: BorderRadius.circular(12),
          child: InputDecorator(
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              isDense: true,
              prefixIcon: Icon(Icons.cake_outlined, size: 20),
            ),
            child: Text(birthdayLabel),
          ),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _FieldLabel('Height'),
                  TextField(
                    controller: _heightController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    onChanged: (v) {
                      final parsed = double.tryParse(v);
                      _emit(
                        parsed == null
                            ? widget.details.copyWith(clearHeight: true)
                            : widget.details.copyWith(heightCm: parsed),
                      );
                    },
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      isDense: true,
                      suffixText: 'cm',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _FieldLabel('Weight'),
                  TextField(
                    controller: _weightController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    onChanged: (v) {
                      final parsed = double.tryParse(v);
                      _emit(
                        parsed == null
                            ? widget.details.copyWith(clearWeight: true)
                            : widget.details.copyWith(weightKg: parsed),
                      );
                    },
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      isDense: true,
                      suffixText: 'kg',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        _FieldLabel('Home Address'),
        TextField(
          controller: _homeAddressController,
          onChanged: (v) => _emit(widget.details.copyWith(homeAddress: v)),
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            isDense: true,
            prefixIcon: Icon(Icons.home_outlined, size: 20),
          ),
        ),
        const SizedBox(height: 20),

        _FieldLabel('Occupation'),
        TextField(
          controller: _occupationController,
          onChanged: (v) => _emit(widget.details.copyWith(occupation: v)),
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            isDense: true,
            prefixIcon: Icon(Icons.work_outline, size: 20),
          ),
        ),
        const SizedBox(height: 20),

        _FieldLabel('Company'),
        TextField(
          controller: _companyController,
          onChanged: (v) => _emit(widget.details.copyWith(company: v)),
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            isDense: true,
            prefixIcon: Icon(Icons.business_outlined, size: 20),
          ),
        ),
        const SizedBox(height: 20),

        _FieldLabel('Contact Number'),
        TextField(
          controller: _contactNumberController,
          keyboardType: TextInputType.phone,
          onChanged: (v) => _emit(widget.details.copyWith(contactNumber: v)),
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            isDense: true,
            prefixIcon: Icon(Icons.phone_outlined, size: 20),
          ),
        ),
        const SizedBox(height: 20),

        _FieldLabel('MBTI'),
        DropdownButtonFormField<String>(
          value: widget.details.mbti,
          isExpanded: true,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            isDense: true,
            prefixIcon: Icon(Icons.psychology_outlined, size: 20),
          ),
          hint: const Text('Not set'),
          items: kMbtiTypes
              .map((t) => DropdownMenuItem(value: t, child: Text(t)))
              .toList(),
          onChanged: (v) => _emit(
            v == null
                ? widget.details.copyWith(clearMbti: true)
                : widget.details.copyWith(mbti: v),
          ),
        ),
        const SizedBox(height: 20),
        _FieldLabel('Zodiac'),
        DropdownButtonFormField<String>(
          value: widget.details.zodiac,
          isExpanded: true,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            isDense: true,
            prefixIcon: Icon(Icons.auto_awesome_outlined, size: 20),
          ),
          hint: const Text('Not set'),
          items: kZodiacSigns
              .map((z) => DropdownMenuItem(value: z, child: Text(z)))
              .toList(),
          onChanged: (v) => _emit(
            v == null
                ? widget.details.copyWith(clearZodiac: true)
                : widget.details.copyWith(zodiac: v),
          ),
        ),
        const SizedBox(height: 20),
        _FieldLabel('Hobbies'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: widget.details.hobbies
              .map(
                (h) => Chip(
                  label: Text(h),
                  visualDensity: VisualDensity.compact,
                  onDeleted: () => _removeHobby(h),
                  backgroundColor: Theme.of(
                    context,
                  ).colorScheme.surfaceContainerHigh,
                  side: BorderSide.none,
                ),
              )
              .toList(),
        ),
        if (widget.details.hobbies.isNotEmpty) const SizedBox(height: 12),
        TextField(
          controller: _hobbyInputController,
          onSubmitted: (_) => _addHobby(),
          decoration: InputDecoration(
            border: const OutlineInputBorder(),
            isDense: true,
            hintText: 'Add a hobby',
            prefixIcon: const Icon(Icons.interests_outlined, size: 20),
            suffixIcon: IconButton(
              icon: const Icon(Icons.add),
              onPressed: _addHobby,
            ),
          ),
        ),
      ],
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Theme.of(context).colorScheme.outline,
        ),
      ),
    );
  }
}
