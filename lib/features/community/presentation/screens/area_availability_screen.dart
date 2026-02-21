import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:condomeet/core/design_system/design_system.dart';
import 'package:condomeet/core/errors/result.dart';
import 'package:condomeet/features/community/domain/models/common_area.dart';
import 'package:condomeet/features/community/data/repositories/booking_repository_impl.dart';

class AreaAvailabilityScreen extends StatefulWidget {
  final CommonArea area;

  const AreaAvailabilityScreen({super.key, required this.area});

  @override
  State<AreaAvailabilityScreen> createState() => _AreaAvailabilityScreenState();
}

class _AreaAvailabilityScreenState extends State<AreaAvailabilityScreen> {
  late DateTime _focusedDay;
  List<AvailabilitySlot> _availability = [];
  bool _isLoading = true;
  DateTime? _selectedDate;

  @override
  void initState() {
    super.initState();
    _focusedDay = DateTime.now();
    _loadAvailability();
  }

  Future<void> _loadAvailability() async {
    setState(() => _isLoading = true);
    final result = await bookingRepository.getAvailability(
      areaId: widget.area.id,
      startDate: DateTime(_focusedDay.year, _focusedDay.month, 1),
      endDate: DateTime(_focusedDay.year, _focusedDay.month + 1, 0),
    );
    
    if (mounted) {
      setState(() {
        if (result is Success<List<AvailabilitySlot>>) {
          _availability = result.data;
        }
        _isLoading = false;
      });
    }
  }

  Future<void> _handleBookingRequest() async {
    if (_selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, selecione uma data no calendário.')),
      );
      return;
    }

    _showConfirmationBottomSheet();
  }

  void _showConfirmationBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _BookingConfirmationBottomSheet(
        area: widget.area,
        selectedDate: _selectedDate!,
        onConfirm: _confirmBooking,
      ),
    );
  }

  Future<void> _confirmBooking() async {
    Navigator.of(context).pop(); // Close bottom sheet
    
    setState(() => _isLoading = true);
    HapticFeedback.mediumImpact();

    final result = await bookingRepository.createBooking(
      residentId: 'res123', // Hardcoded for MVP
      areaId: widget.area.id,
      date: _selectedDate!,
    );

    if (mounted) {
      if (result is Success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Reserva solicitada com sucesso!'),
            backgroundColor: Colors.green,
          ),
        );
        _selectedDate = null;
        _loadAvailability(); // Refresh calendar
      } else if (result is Failure) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.message),
            backgroundColor: Colors.red,
          ),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.area.name),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildAreaInfo(),
            const SizedBox(height: 32),
            Text('Disponibilidade', style: AppTypography.h2),
            const SizedBox(height: 16),
            _buildCalendarHeader(),
            const SizedBox(height: 16),
            _isLoading 
              ? const SizedBox(height: 200, child: Center(child: CircularProgressIndicator()))
              : _buildAvailabilityGrid(),
            const SizedBox(height: 40),
            CondoButton(
              label: 'Solicitar Reserva',
              isLoading: _isLoading && _selectedDate != null,
              onPressed: _handleBookingRequest,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAreaInfo() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.info_outline, color: AppColors.primary, size: 20),
              const SizedBox(width: 8),
              Text('Regras de Uso', style: AppTypography.label.copyWith(color: AppColors.primary)),
            ],
          ),
          const SizedBox(height: 12),
          Text(widget.area.rules, style: AppTypography.bodySmall),
        ],
      ),
    );
  }

  Widget _buildCalendarHeader() {
    final months = [
      '', 'Janeiro', 'Fevereiro', 'Março', 'Abril', 'Maio', 'Junho',
      'Julho', 'Agosto', 'Setembro', 'Outubro', 'Novembro', 'Dezembro'
    ];
    
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          '${months[_focusedDay.month]} ${_focusedDay.year}',
          style: AppTypography.h3,
        ),
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left),
              onPressed: () {
                setState(() => _focusedDay = DateTime(_focusedDay.year, _focusedDay.month - 1));
                _loadAvailability();
              },
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right),
              onPressed: () {
                setState(() => _focusedDay = DateTime(_focusedDay.year, _focusedDay.month + 1));
                _loadAvailability();
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAvailabilityGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
      ),
      itemCount: _availability.length,
      itemBuilder: (context, index) {
        final slot = _availability[index];
        return _buildDayCard(slot);
      },
    );
  }

  Widget _buildDayCard(AvailabilitySlot slot) {
    final isSelected = _selectedDate != null &&
        slot.date.year == _selectedDate!.year &&
        slot.date.month == _selectedDate!.month &&
        slot.date.day == _selectedDate!.day;

    final isToday = slot.date.day == DateTime.now().day && 
        slot.date.month == DateTime.now().month &&
        slot.date.year == DateTime.now().year;

    return InkWell(
      onTap: slot.isAvailable ? () {
        setState(() {
          if (isSelected) {
            _selectedDate = null;
          } else {
            _selectedDate = slot.date;
          }
        });
        HapticFeedback.lightImpact();
      } : null,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: isSelected 
              ? AppColors.primary 
              : (slot.isAvailable ? Colors.transparent : AppColors.surface),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected 
                ? AppColors.primary 
                : (isToday ? AppColors.primary : (slot.isAvailable ? AppColors.border : Colors.transparent)),
            width: (isToday || isSelected) ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '${slot.date.day}',
              style: AppTypography.label.copyWith(
                color: isSelected 
                    ? Colors.white 
                    : (slot.isAvailable ? AppColors.textMain : AppColors.textSecondary),
                fontWeight: (isToday || isSelected) ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            if (!slot.isAvailable && !isSelected)
              Container(
                margin: const EdgeInsets.only(top: 2),
                width: 4,
                height: 4,
                decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
              ),
          ],
        ),
      ),
    );
  }
}

class _BookingConfirmationBottomSheet extends StatelessWidget {
  final CommonArea area;
  final DateTime selectedDate;
  final VoidCallback onConfirm;

  const _BookingConfirmationBottomSheet({
    required this.area,
    required this.selectedDate,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    final dateStr = '${selectedDate.day}/${selectedDate.month}/${selectedDate.year}';

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text('Confirmar Reserva', style: AppTypography.h2),
          const SizedBox(height: 8),
          Text(
            'Você está solicitando o uso de um espaço comum.',
            style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 24),
          _buildInfoRow(Icons.location_on_outlined, 'Espaço', area.name),
          const SizedBox(height: 12),
          _buildInfoRow(Icons.calendar_today_outlined, 'Data', dateStr),
          const SizedBox(height: 12),
          _buildInfoRow(Icons.people_outline, 'Capacidade', '${area.capacity} pessoas'),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Lembrete de Regras', style: AppTypography.label),
                const SizedBox(height: 8),
                Text(area.rules, style: AppTypography.bodySmall),
              ],
            ),
          ),
          const SizedBox(height: 32),
          CondoButton(
            label: 'Confirmar e Reservar',
            onPressed: onConfirm,
          ),
          const SizedBox(height: 16),
          Center(
            child: TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Cancelar',
                style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.primary),
        const SizedBox(width: 12),
        Text('$label:', style: AppTypography.label.copyWith(color: AppColors.textSecondary)),
        const SizedBox(width: 4),
        Text(value, style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.bold)),
      ],
    );
  }
}
