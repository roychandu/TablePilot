// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import '../../common_widgets/app_colors.dart';
import '../../common_widgets/app_text_styles.dart';
import '../../models/reservation_model.dart';
import '../../models/table_booking_model.dart';
import '../../services/reservation_service.dart';
import '../../services/table_booking_service.dart';

class EditReservationScreen extends StatefulWidget {
  const EditReservationScreen({super.key, required this.event});

  final dynamic event; // Accepts ReservationModel or EventModel

  @override
  State<EditReservationScreen> createState() => _EditReservationScreenState();
}

class _EditReservationScreenState extends State<EditReservationScreen> {
  final ReservationService _reservationService = ReservationService();
  final TableBookingService _tableBookingService = TableBookingService();
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final _guestNameController = TextEditingController();
  final _phoneNumberController = TextEditingController();
  final _emailController = TextEditingController();
  final _specialPreferencesController = TextEditingController();
  String? _emailError;
  String? _phoneError;

  // Form fields
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  int _numberOfGuests = 2;
  int? _selectedTable;
  bool _isSubmitting = false;

  // Options
  final List<int> _guestOptions = [1, 2, 3, 4, 5, 6, 7, 8];

  // Get table numbers across all floors (4 floors * 10 tables)
  // Filtered based on number of guests
  List<int> get _tableOptions {
    // Limit to first 20 tables (T1–T20)
    const maxTable = 20;
    return List.generate(
      maxTable,
      (index) => index + 1,
    ).where((tableNum) => _getSeatCount(tableNum) >= _numberOfGuests).toList();
  }

  // Get seat count for a table number
  // Pattern: 1-3 (2 seats), 4-6 (4 seats), 7-8 (6 seats), 9-10 (8 seats)
  // This pattern repeats for each floor
  int _getSeatCount(int tableNumber) {
    // Get the position within the floor (1-10)
    final positionInFloor = ((tableNumber - 1) % 10) + 1;

    if (positionInFloor >= 1 && positionInFloor <= 3) {
      return 2;
    } else if (positionInFloor >= 4 && positionInFloor <= 6) {
      return 4;
    } else if (positionInFloor >= 7 && positionInFloor <= 8) {
      return 6;
    } else if (positionInFloor >= 9 && positionInFloor <= 10) {
      return 8;
    }
    return 2; // Default fallback
  }

  @override
  void initState() {
    super.initState();
    _initializeFields();
    // Initialize validation state for prefilled values
    _onEmailChanged(_emailController.text);
    _onPhoneChanged(_phoneNumberController.text);
  }

  void _initializeFields() {
    final event = widget.event;

    // Guest Information
    _guestNameController.text = event.reservationName;
    _phoneNumberController.text = event.phone;
    _emailController.text = event.email;
    _specialPreferencesController.text = event.specialDietaryRequirements;

    // Booking Details
    _selectedDate = event.reservationDate;
    _selectedTime = TimeOfDay.fromDateTime(event.startTime);
    _numberOfGuests = event.numberOfGuests;
    _selectedTable = event.tableNumber;

    // Set default table if not set
    if (_selectedTable == null) {
      _selectedTable = _tableOptions.isNotEmpty ? _tableOptions.first : null;
    }
  }

  @override
  void dispose() {
    _guestNameController.dispose();
    _phoneNumberController.dispose();
    _emailController.dispose();
    _specialPreferencesController.dispose();
    super.dispose();
  }

  void _onEmailChanged(String value) {
    final email = value.trim();
    String? error;
    if (email.isNotEmpty) {
      final emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
      if (!emailPattern.hasMatch(email)) {
        error = 'Enter a valid email';
      } else if (!email.toLowerCase().endsWith('@gmail.com')) {
        error = 'Email must be a @gmail.com address';
      } else {
        // Ensure local part (before @) starts with 4–5 alphabetic characters
        final localPart = email.split('@').first;
        final leading = localPart.length >= 4
            ? localPart.substring(
                0,
                localPart.length >= 5 ? 5 : localPart.length,
              )
            : localPart;
        final alphaOnly = RegExp(r'^[A-Za-z]{4,5}$');
        if (!alphaOnly.hasMatch(leading)) {
          error = 'First 4–5 characters must be letters';
        }
      }
    }
    setState(() {
      _emailError = error;
    });
  }

  void _onPhoneChanged(String value) {
    final phone = value.trim();
    String? error;
    if (phone.isEmpty) {
      error = 'This field is required';
    } else {
      final digitsOnly = phone.replaceAll(RegExp(r'[^0-9]'), '');
      if (digitsOnly.length != 10) {
        error = 'Phone must be exactly 10 digits';
      }
    }
    setState(() {
      _phoneError = error;
    });
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.dark(
              primary: AppColors.primary,
              onPrimary: AppColors.white,
              surface: AppColors.cardBackground,
              onSurface: AppColors.white,
              background: AppColors.background,
              onBackground: AppColors.white,
            ),
            textTheme: Theme.of(context).textTheme.apply(
              bodyColor: AppColors.white,
              displayColor: AppColors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _selectTime() async {
    if (_selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a date first'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    if (_selectedTable == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a table first'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    // Get existing reservations for the selected date
    final existingReservations = await _reservationService.getReservations();
    final selectedDateOnly = DateTime(
      _selectedDate!.year,
      _selectedDate!.month,
      _selectedDate!.day,
    );

    final selectedDateReservations = existingReservations.where((reservation) {
      final reservationDate = DateTime(
        reservation.reservationDate.year,
        reservation.reservationDate.month,
        reservation.reservationDate.day,
      );
      // Check if reservation matches date and table number
      final matchesDate = reservationDate.isAtSameMomentAs(selectedDateOnly);
      final matchesTable = reservation.tableNumber == _selectedTable;
      // Skip cancelled and completed reservations
      final isActive =
          reservation.status != ReservationStatus.cancelled &&
          reservation.status != ReservationStatus.completed;
      // Skip current reservation being edited
      final isNotCurrent = reservation.id != widget.event.id;

      return matchesDate && matchesTable && isActive && isNotCurrent;
    }).toList();

    // Get existing table bookings for the selected date and table
    final existingBookings = await _tableBookingService.getTableBookings();
    final selectedDateBookings = existingBookings.where((booking) {
      final bookingDate = DateTime(
        booking.bookingDate.year,
        booking.bookingDate.month,
        booking.bookingDate.day,
      );
      // Check if booking matches date and table number
      final matchesDate = bookingDate.isAtSameMomentAs(selectedDateOnly);
      final matchesTable = booking.tableNumber == _selectedTable;
      final isActive = booking.status != TableBookingStatus.cancelled;

      return matchesDate && matchesTable && isActive;
    }).toList();

    // Get booked time slots from both reservations and bookings
    final bookedTimes = <TimeOfDay>{};
    for (final reservation in selectedDateReservations) {
      bookedTimes.add(
        TimeOfDay(
          hour: reservation.startTime.hour,
          minute: reservation.startTime.minute,
        ),
      );
    }
    for (final booking in selectedDateBookings) {
      bookedTimes.add(
        TimeOfDay(
          hour: booking.bookingTime.hour,
          minute: booking.bookingTime.minute,
        ),
      );
    }

    // Allowed time window: 9:30 AM to 9:30 PM
    const minAllowedTime = TimeOfDay(hour: 9, minute: 30);
    const maxAllowedTime = TimeOfDay(hour: 21, minute: 30);

    final now = DateTime.now();

    // Calculate minimum time (2 hours from now) if reservation is today
    TimeOfDay? minTime;
    final isToday =
        _selectedDate!.year == now.year &&
        _selectedDate!.month == now.month &&
        _selectedDate!.day == now.day;

    if (isToday) {
      final minDateTime = now.add(const Duration(hours: 2));
      minTime = TimeOfDay.fromDateTime(minDateTime);
    }

    // Choose an initial time within allowed range
    TimeOfDay initialTime;
    if (_selectedTime != null) {
      initialTime = _selectedTime!;
    } else {
      // If reservation is today, start from 2 hours from now; otherwise from minAllowedTime
      TimeOfDay candidateTime;
      if (isToday && minTime != null) {
        candidateTime = minTime;
      } else {
        candidateTime = minAllowedTime;
      }

      int toMinutes(TimeOfDay t) => t.hour * 60 + t.minute;

      final candidateMinutes = toMinutes(candidateTime);
      final minAllowedMinutes = toMinutes(minAllowedTime);
      final maxAllowedMinutes = toMinutes(maxAllowedTime);

      if (candidateMinutes < minAllowedMinutes) {
        initialTime = minAllowedTime;
      } else if (candidateMinutes > maxAllowedMinutes) {
        initialTime = maxAllowedTime;
      } else {
        initialTime = candidateTime;
      }
    }

    final picked = await showTimePicker(
      context: context,
      initialTime: initialTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.dark(
              primary: AppColors.primary,
              onPrimary: AppColors.white,
              surface: AppColors.cardBackground,
              onSurface: AppColors.white,
              background: AppColors.background,
              onBackground: AppColors.white,
            ),
            textTheme: Theme.of(context).textTheme.apply(
              bodyColor: AppColors.white,
              displayColor: AppColors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked == null) return;

    int toMinutes(TimeOfDay t) => t.hour * 60 + t.minute;

    final pickedMinutes = toMinutes(picked);
    final minAllowedMinutes = toMinutes(minAllowedTime);
    final maxAllowedMinutes = toMinutes(maxAllowedTime);

    // Enforce 9:30 AM – 9:30 PM window
    if (pickedMinutes < minAllowedMinutes ||
        pickedMinutes > maxAllowedMinutes) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Time must be between 9:30 AM and 9:30 PM'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    // Validate 2-hour rule if reservation is today
    if (isToday && minTime != null) {
      int toMinutes(TimeOfDay t) => t.hour * 60 + t.minute;
      final pickedMinutes = toMinutes(picked);
      final minMinutes = toMinutes(minTime);
      if (pickedMinutes < minMinutes) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Reservation time must be at least 2 hours from now'),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }
    }

    // Prevent selecting a past time when booking for today
    final selectedDateTime = DateTime(
      _selectedDate!.year,
      _selectedDate!.month,
      _selectedDate!.day,
      picked.hour,
      picked.minute,
    );
    if (isToday && selectedDateTime.isBefore(now)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selected time is in the past'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    // Prevent selecting the same time slot
    final isAlreadyBooked = bookedTimes.any(
      (t) => t.hour == picked.hour && t.minute == picked.minute,
    );
    if (isAlreadyBooked) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'This time slot is already booked or reserved for this table, If you want to book this table, please wait for 1 hour from the existing bookings/reservations',
          ),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    // Check for bookings/reservations within 1 hour before or after the selected time
    final selectedTimeMinutes = picked.hour * 60 + picked.minute;
    final oneHourInMinutes = 60;

    final hasConflictWithinOneHour = bookedTimes.any((bookedTime) {
      final bookedMinutes = bookedTime.hour * 60 + bookedTime.minute;
      final timeDifference = (selectedTimeMinutes - bookedMinutes).abs();
      return timeDifference < oneHourInMinutes;
    });

    if (hasConflictWithinOneHour) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'This table should be booked after 1 hour from existing bookings/reservations',
          ),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() {
      _selectedTime = picked;
    });
  }

  Future<void> _updateReservation() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a date'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    if (_selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a time'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    if (_selectedTable == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a table'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final startDateTime = DateTime(
        _selectedDate!.year,
        _selectedDate!.month,
        _selectedDate!.day,
        _selectedTime!.hour,
        _selectedTime!.minute,
      );

      // Menu categories and items are not required
      final menuCategories = <String>[];
      final totalCost = 0.0;

      final updatedReservation = (widget.event as ReservationModel).copyWith(
        reservationName: _guestNameController.text.trim(),
        reservationType: ReservationType.other,
        contactPerson: _guestNameController.text.trim(),
        email: _emailController.text.trim().isEmpty
            ? ''
            : _emailController.text.trim(),
        phone: _phoneNumberController.text.trim(),
        reservationDate: _selectedDate!,
        startTime: startDateTime,
        numberOfGuests: _numberOfGuests,
        requiredTables: 1,
        tableNumber: _selectedTable,
        parkingRequired: false,
        menuCategories: menuCategories,
        menuItems: [],
        specialDietaryRequirements: _specialPreferencesController.text.trim(),
        decorPackage: '',
        additionalServices: [],
        assignedStaffIds: [],
        paymentMethod: PaymentMethod.cash,
        estimatedTotalCost: totalCost,
        updatedAt: DateTime.now(),
      );

      final success = await _reservationService.updateReservation(
        updatedReservation,
      );

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Reservation updated successfully'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context, true);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to update reservation'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('An error occurred'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;
    final horizontalPadding = isTablet ? 24.0 : 16.0;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.cardBackground,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Edit Reservation',
              style: AppTextStyles.h4.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              'Update reservation details',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: EdgeInsets.all(horizontalPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),
                // Guest Information Section
                _buildSectionHeader(
                  icon: CupertinoIcons.person_fill,
                  title: 'Guest Information',
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  controller: _guestNameController,
                  label: 'Guest Name',
                  isRequired: true,
                  hintText: 'John Doe',
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  controller: _phoneNumberController,
                  label: 'Phone Number',
                  isRequired: true,
                  hintText: '1234567890',
                  keyboardType: TextInputType.phone,
                  errorText: _phoneError,
                  onChanged: _onPhoneChanged,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(10),
                  ],
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  controller: _emailController,
                  label: 'Email',
                  isRequired: false,
                  hintText: 'john.doe@gmail.com',
                  keyboardType: TextInputType.emailAddress,
                  errorText: _emailError,
                  onChanged: _onEmailChanged,
                ),
                const SizedBox(height: 32),
                // Booking Details Section
                _buildSectionHeader(
                  icon: CupertinoIcons.calendar,
                  title: 'Booking Details',
                ),
                const SizedBox(height: 16),
                _buildDateField(),
                const SizedBox(height: 32),
                // Table Selection Section
                _buildSectionHeader(
                  icon: CupertinoIcons.location_fill,
                  title: 'Table Selection',
                ),
                const SizedBox(height: 16),
                _buildDropdownField<int>(
                  label: 'Number of Guests',
                  isRequired: true,
                  value: _numberOfGuests,
                  items: _guestOptions,
                  onChanged: (value) {
                    setState(() {
                      _numberOfGuests = value!;
                      // Update table selection if current table cannot accommodate guests
                      if (_selectedTable != null &&
                          !_tableOptions.contains(_selectedTable)) {
                        _selectedTable = _tableOptions.isNotEmpty
                            ? _tableOptions.first
                            : null;
                      }
                      // Clear selected time when guests change
                      _selectedTime = null;
                    });
                  },
                  displayText: (value) =>
                      '$value ${value == 1 ? 'Guest' : 'Guests'}',
                ),
                const SizedBox(height: 16),
                // Table Selection Grid
                Text(
                  'Table *',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 12),
                _buildTableGrid(),
                const SizedBox(height: 16),
                _buildTimeField(),
                const SizedBox(height: 32),
                // Special Preferences
                _buildSectionHeader(
                  icon: CupertinoIcons.info,
                  title: 'Special Preferences',
                ),
                const SizedBox(height: 16),
                _buildTextArea(
                  controller: _specialPreferencesController,
                  hintText: 'preferences, or special occasions...',
                ),
                const SizedBox(height: 32),
                // Action Buttons
                Row(
                  children: [
                    Expanded(child: _buildCancelButton(isTablet)),
                    const SizedBox(width: 12),
                    Expanded(flex: 2, child: _buildUpdateButton(isTablet)),
                  ],
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader({required IconData icon, required String title}) {
    return Row(
      children: [
        Icon(icon, color: AppColors.success, size: 20),
        const SizedBox(width: 8),
        Text(
          title,
          style: AppTextStyles.h6.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required bool isRequired,
    String? hintText,
    TextInputType? keyboardType,
    ValueChanged<String>? onChanged,
    List<TextInputFormatter>? inputFormatters,
    String? errorText,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          isRequired ? '$label *' : label,
          style: AppTextStyles.bodyMedium.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          onChanged: onChanged,
          inputFormatters: inputFormatters,
          style: AppTextStyles.bodyMedium.copyWith(
            color: AppColors.textPrimary,
          ),
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textSecondary.withOpacity(0.5),
            ),
            errorText: errorText,
            filled: true,
            fillColor: AppColors.cardBackground,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.primary, width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
          ),
          validator: (value) {
            if (isRequired && (value == null || value.trim().isEmpty)) {
              return 'This field is required';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildDateField() {
    final dateText = _selectedDate == null
        ? 'mm/dd/yyyy'
        : '${_selectedDate!.month.toString().padLeft(2, '0')}/${_selectedDate!.day.toString().padLeft(2, '0')}/${_selectedDate!.year}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Date *',
          style: AppTextStyles.bodyMedium.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: _selectDate,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.cardBackground,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    dateText,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: _selectedDate == null
                          ? AppColors.textSecondary.withOpacity(0.5)
                          : AppColors.textPrimary,
                    ),
                  ),
                ),
                Icon(
                  CupertinoIcons.calendar,
                  color: AppColors.textSecondary,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTimeField() {
    final timeText = _selectedTime == null
        ? '--:--'
        : '${_selectedTime!.hour.toString().padLeft(2, '0')}:${_selectedTime!.minute.toString().padLeft(2, '0')}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Time *',
          style: AppTextStyles.bodyMedium.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: _selectTime,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.cardBackground,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    timeText,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: _selectedTime == null
                          ? AppColors.textSecondary.withOpacity(0.5)
                          : AppColors.textPrimary,
                    ),
                  ),
                ),
                Icon(
                  CupertinoIcons.clock,
                  color: AppColors.textSecondary,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdownField<T>({
    required String label,
    required bool isRequired,
    required T? value,
    required List<T> items,
    required ValueChanged<T?> onChanged,
    required String Function(T?) displayText,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          isRequired ? '$label *' : label,
          style: AppTextStyles.bodyMedium.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: AppColors.cardBackground,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<T>(
              value: value,
              isExpanded: true,
              icon: Icon(
                CupertinoIcons.chevron_down,
                color: AppColors.textSecondary,
                size: 18,
              ),
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textPrimary,
              ),
              dropdownColor: AppColors.cardBackground,
              items: items.map((T item) {
                return DropdownMenuItem<T>(
                  value: item,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(displayText(item)),
                      if (value == item)
                        Icon(Icons.check, color: AppColors.success, size: 18),
                    ],
                  ),
                );
              }).toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTableGrid() {
    final availableTables = _tableOptions;

    if (availableTables.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Center(
          child: Text(
            'No tables available for ${_numberOfGuests} ${_numberOfGuests == 1 ? 'guest' : 'guests'}',
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ),
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 5,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.85,
      ),
      itemCount: availableTables.length,
      itemBuilder: (context, index) {
        final tableNumber = availableTables[index];
        final seatCount = _getSeatCount(tableNumber);
        final isSelected = _selectedTable == tableNumber;

        return _buildTableCard(
          tableNumber: tableNumber,
          seatCount: seatCount,
          isSelected: isSelected,
        );
      },
    );
  }

  Widget _buildTableCard({
    required int tableNumber,
    required int seatCount,
    required bool isSelected,
  }) {
    return InkWell(
      onTap: () {
        setState(() {
          _selectedTable = tableNumber;
          // Clear selected time when table changes to ensure time sync
          _selectedTime = null;
        });
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withOpacity(0.2)
              : AppColors.cardBackground,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'T$tableNumber',
              style: AppTextStyles.bodyLarge.copyWith(
                color: isSelected ? AppColors.primary : AppColors.textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            Text(
              '$seatCount seats',
              style: AppTextStyles.bodySmall.copyWith(
                color: isSelected ? AppColors.primary : AppColors.textSecondary,
                fontSize: 11,
              ),
            ),
            if (isSelected)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Icon(
                  Icons.check_circle,
                  color: AppColors.primary,
                  size: 16,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextArea({
    required TextEditingController controller,
    required String hintText,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: 4,
      style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textPrimary),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: AppTextStyles.bodyMedium.copyWith(
          color: AppColors.textSecondary.withOpacity(0.5),
        ),
        filled: true,
        fillColor: AppColors.cardBackground,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.primary, width: 2),
        ),
        contentPadding: const EdgeInsets.all(16),
      ),
    );
  }

  Widget _buildCancelButton(bool isTablet) {
    return SizedBox(
      height: isTablet ? 56.0 : 48.0,
      child: OutlinedButton(
        onPressed: _isSubmitting ? null : () => Navigator.pop(context),
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: AppColors.border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: Text(
          'Cancel',
          style: AppTextStyles.bodyMedium.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildUpdateButton(bool isTablet) {
    return SizedBox(
      height: isTablet ? 56.0 : 48.0,
      child: ElevatedButton(
        onPressed: _isSubmitting ? null : _updateReservation,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: _isSubmitting
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.white),
                ),
              )
            : Text(
                'Update Reservation',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
      ),
    );
  }
}
