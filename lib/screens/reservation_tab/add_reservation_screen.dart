// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import '../../common_widgets/app_colors.dart';
import '../../common_widgets/app_text_styles.dart';
import '../../models/reservation_model.dart';
import '../../models/offer_model.dart';
import '../../services/reservation_service.dart';
import '../../services/offer_service.dart';
import '../../services/auth_service.dart';
import '../../models/table_booking_model.dart';
import '../../services/table_booking_service.dart';

class AddReservationScreen extends StatefulWidget {
  AddReservationScreen({super.key});

  @override
  State<AddReservationScreen> createState() => _AddReservationScreenState();
}

class _AddReservationScreenState extends State<AddReservationScreen> {
  final ReservationService _reservationService = ReservationService();
  final OfferService _offerService = OfferService();
  final AuthService _authService = AuthService();
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
  bool _isSubmitting = false;

  // Options
  final List<int> _guestOptions = [1, 2, 3, 4, 5, 6, 7, 8];

  // Offers
  List<OfferModel> _activeOffers = [];

  @override
  void initState() {
    super.initState();
    // Initialize validation state for prefilled values
    _onEmailChanged(_emailController.text);
    _loadOffers();
  }

  Future<void> _loadOffers() async {
    try {
      final offers = await _offerService.getActiveOffersForCustomers();
      if (mounted) {
        setState(() {
          _activeOffers = offers
              .where(
                (offer) => offer.applyTo.contains(OfferApplyTo.reservations),
              )
              .toList();
        });
      }
    } catch (e) {
      debugPrint('Error loading offers: $e');
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

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(Duration(days: 365)),
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
        SnackBar(
          content: Text('Please select a date first'),
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
      // Check if reservation matches date
      final matchesDate = reservationDate.isAtSameMomentAs(selectedDateOnly);
      // Skip cancelled and completed reservations
      final isActive =
          reservation.status != ReservationStatus.cancelled &&
          reservation.status != ReservationStatus.completed;

      return matchesDate && isActive;
    }).toList();

    // Get booked time slots from reservations - compare by hour and minute
    final bookedTimes = <TimeOfDay>{};
    for (final reservation in selectedDateReservations) {
      bookedTimes.add(
        TimeOfDay(
          hour: reservation.startTime.hour,
          minute: reservation.startTime.minute,
        ),
      );
    }

    // Allowed time window: 9:30 AM to 9:30 PM
    final minAllowedTime = TimeOfDay(hour: 9, minute: 30);
    final maxAllowedTime = TimeOfDay(hour: 21, minute: 30);

    final now = DateTime.now();

    // Calculate minimum time (2 hours from now) if reservation is today
    TimeOfDay? minTime;
    final isToday =
        _selectedDate!.year == now.year &&
        _selectedDate!.month == now.month &&
        _selectedDate!.day == now.day;

    if (isToday) {
      final minDateTime = now.add(Duration(hours: 2));
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
        SnackBar(
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
          SnackBar(
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
        SnackBar(
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
        SnackBar(
          content: Text(
            'This time slot is already booked. Please select a different time.',
          ),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    // Check for reservations within 1 hour before or after the selected time
    final selectedTimeMinutes = picked.hour * 60 + picked.minute;
    final oneHourInMinutes = 60;

    final hasConflictWithinOneHour = bookedTimes.any((bookedTime) {
      final bookedMinutes = bookedTime.hour * 60 + bookedTime.minute;
      final timeDifference = (selectedTimeMinutes - bookedMinutes).abs();
      return timeDifference < oneHourInMinutes;
    });

    if (hasConflictWithinOneHour) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Please select a time at least 1 hour from existing reservations',
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

  // ... inside _AddReservationScreenState

  // Add this variable
  int? _selectedTable;
  final TableBookingService _tableBookingService = TableBookingService();

  // Helper for seat count (same as in TableBookingsScreen)
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

  // Build the table grid
  Widget _buildTableSelectionSection(double screenWidth) {
    return FutureBuilder<List<int>>(
      future: _getUnavailableTables(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }

        final unavailableTables = snapshot.data ?? [];
        // Limit to first 20 tables
        final allTableNumbers = List.generate(20, (index) => index + 1);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader(
              icon: Icons.table_restaurant,
              title: 'Table Selection',
            ),
            if (_selectedDate == null || _selectedTime == null)
              Padding(
                padding: EdgeInsets.symmetric(vertical: 8.0),
                child: Text(
                  'Select date and time to see real-time availability',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.warning,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              )
            else
              SizedBox(height: 16),
            GridView.builder(
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: screenWidth > 600 ? 8 : 5,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.85,
              ),
              itemCount: allTableNumbers.length,
              itemBuilder: (context, index) {
                final tableNumber = allTableNumbers[index];
                final seatCount = _getSeatCount(tableNumber);
                final isUnavailable = unavailableTables.contains(tableNumber);
                final isCapacityInsufficient = seatCount < _numberOfGuests;
                final isSelected = _selectedTable == tableNumber;

                return _buildTableOption(
                  tableNumber: tableNumber,
                  seatCount: seatCount,
                  isUnavailable: isUnavailable,
                  isCapacityInsufficient: isCapacityInsufficient,
                  isSelected: isSelected,
                );
              },
            ),
          ],
        );
      },
    );
  }

  Future<List<int>> _getUnavailableTables() async {
    if (_selectedDate == null || _selectedTime == null) return [];

    final selectedStart = DateTime(
      _selectedDate!.year,
      _selectedDate!.month,
      _selectedDate!.day,
      _selectedTime!.hour,
      _selectedTime!.minute,
    );
    // Assume 2 hour default duration for the new reservation
    final selectedEnd = selectedStart.add(Duration(hours: 2));

    final unavailableTables = <int>{};

    // Check Reservartions
    final reservations = await _reservationService.getReservations();
    for (final reservation in reservations) {
      if (reservation.tableNumber != null &&
          reservation.status != ReservationStatus.cancelled) {
        final resStart = reservation.startTime;
        // Assume 2 hours duration for existing reservations too
        final resEnd = resStart.add(Duration(hours: 2));

        // specific check: existing.start < new.end && new.start < existing.end
        if (resStart.isBefore(selectedEnd) && selectedStart.isBefore(resEnd)) {
          unavailableTables.add(reservation.tableNumber!);
        }
      }
    }

    // Check Table Bookings
    final bookings = await _tableBookingService.getTableBookings();
    for (final booking in bookings) {
      if (booking.tableNumber != null &&
          booking.status != TableBookingStatus.cancelled &&
          booking.status != TableBookingStatus.completed) {
        final bookingStart = DateTime(
          booking.bookingDate.year,
          booking.bookingDate.month,
          booking.bookingDate.day,
          booking.bookingTime.hour,
          booking.bookingTime.minute,
        );

        // Use actual duration from booking model
        final durationMinutes = (booking.durationHours * 60).round();
        final bookingEnd = bookingStart.add(Duration(minutes: durationMinutes));

        if (bookingStart.isBefore(selectedEnd) &&
            selectedStart.isBefore(bookingEnd)) {
          unavailableTables.add(booking.tableNumber!);
        }
      }
    }

    return unavailableTables.toList();
  }

  Widget _buildTableOption({
    required int tableNumber,
    required int seatCount,
    required bool isUnavailable,
    required bool isCapacityInsufficient,
    required bool isSelected,
  }) {
    // Determine status colors
    Color borderColor;
    Color backgroundColor;
    Color textColor;

    final isDisabled = isUnavailable || isCapacityInsufficient;

    if (isDisabled) {
      borderColor = AppColors.border;
      backgroundColor = AppColors.surface.withOpacity(0.5);
      textColor = AppColors.textSecondary.withOpacity(0.5);
    } else if (isSelected) {
      borderColor = AppColors.primary;
      backgroundColor = AppColors.primary.withOpacity(0.15);
      textColor = AppColors.primary;
    } else {
      borderColor = AppColors.success;
      backgroundColor = AppColors.cardBackground;
      textColor = AppColors.textPrimary;
    }

    return InkWell(
      onTap: isDisabled
          ? null
          : () {
              setState(() {
                if (_selectedTable == tableNumber) {
                  _selectedTable = null;
                } else {
                  _selectedTable = tableNumber;
                }
              });
            },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor, width: isSelected ? 2 : 1),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'T$tableNumber',
              style: AppTextStyles.bodyLarge.copyWith(
                color: textColor,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            if (isUnavailable)
              Text(
                'Booked',
                style: AppTextStyles.bodySmall.copyWith(
                  color: textColor,
                  fontSize: 10,
                ),
              )
            else if (isCapacityInsufficient)
              Text(
                'Too Small',
                style: AppTextStyles.bodySmall.copyWith(
                  color: textColor,
                  fontSize: 10,
                ),
              )
            else
              Text(
                '$seatCount seats',
                style: AppTextStyles.bodySmall.copyWith(
                  color: textColor,
                  fontSize: 11,
                ),
              ),
          ],
        ),
      ),
    );
  }

  // Updated submit logic
  Future<void> _submitReservation() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please select a date'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    if (_selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please select a time'),
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

      // Check if user is admin - admin reservations should be auto-confirmed
      final currentUserEmail = _authService.currentUser?.email;
      final isAdmin = currentUserEmail == 'test-admin@gmail.com';

      final reservation = ReservationModel(
        reservationName: _guestNameController.text.trim(),
        contactPerson: _guestNameController.text.trim(),
        email: _emailController.text.trim().isEmpty
            ? ''
            : _emailController.text.trim(),
        phone: _phoneNumberController.text.trim(),
        reservationDate: _selectedDate!,
        startTime: startDateTime,
        numberOfGuests: _numberOfGuests,
        specialDietaryRequirements: _specialPreferencesController.text.trim(),

        // Use selected table (can be null)
        tableNumber: _selectedTable,

        // Admin reservations are auto-confirmed, non-admin are pending
        status: isAdmin
            ? ReservationStatus.completed
            : ReservationStatus.upcoming,
      );

      final reservationId = await _reservationService.createReservation(
        reservation,
      );

      if (reservationId != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Reservation created successfully'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context, true);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to create reservation'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
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
          icon: Icon(Icons.close, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'New Reservation',
              style: AppTextStyles.h4.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              'Create a new event reservation',
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
                SizedBox(height: 20),
                // Active Offers Banner
                if (_activeOffers.isNotEmpty) ...[
                  _buildOffersBanner(),
                  SizedBox(height: 20),
                ],
                // Guest Information Section
                _buildSectionHeader(
                  icon: CupertinoIcons.person_fill,
                  title: 'Guest Information',
                ),
                SizedBox(height: 16),
                _buildTextField(
                  controller: _guestNameController,
                  label: 'Guest Name',
                  isRequired: true,
                  hintText: 'John Doe',
                ),
                SizedBox(height: 16),
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
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'This field is required';
                    }
                    final digitsOnly = value.replaceAll(RegExp(r'[^0-9]'), '');
                    if (digitsOnly.length != 10) {
                      return 'Phone must be exactly 10 digits';
                    }
                    return null;
                  },
                ),
                SizedBox(height: 16),
                _buildTextField(
                  controller: _emailController,
                  label: 'Email (Optional)',
                  isRequired: false,
                  hintText: 'john.doe@gmail.com',
                  keyboardType: TextInputType.emailAddress,
                  errorText: _emailError,
                  onChanged: _onEmailChanged,
                  validator: (value) {
                    if (value != null &&
                        value.trim().isNotEmpty &&
                        _emailError != null) {
                      return _emailError;
                    }
                    return null;
                  },
                ),
                SizedBox(height: 32),
                // Booking Details Section
                _buildSectionHeader(
                  icon: CupertinoIcons.calendar,
                  title: 'Booking Details',
                ),
                SizedBox(height: 16),
                _buildDateField(),
                SizedBox(height: 32),
                // Guest Information Section
                _buildSectionHeader(
                  icon: CupertinoIcons.person_2_fill,
                  title: 'Guest Details',
                ),
                SizedBox(height: 16),
                _buildDropdownField<int>(
                  label: 'Number of Guests',
                  isRequired: true,
                  value: _numberOfGuests,
                  items: _guestOptions,
                  onChanged: (value) {
                    setState(() {
                      _numberOfGuests = value!;
                      // Clear selected time when guests change
                      _selectedTime = null;
                      // Clear table selection
                      _selectedTable = null;
                    });
                  },
                  displayText: (value) =>
                      '$value ${value == 1 ? 'Guest' : 'Guests'}',
                ),
                SizedBox(height: 16),
                _buildTimeField(),
                SizedBox(height: 32),

                // Special Preferences
                _buildSectionHeader(
                  icon: CupertinoIcons.info,
                  title: 'Special Preferences',
                ),
                SizedBox(height: 16),
                _buildTextArea(
                  controller: _specialPreferencesController,
                  hintText: 'preferences, or special occasions...',
                ),
                SizedBox(height: 32),
                // Table Selection Section (New)
                _buildTableSelectionSection(screenWidth),
                SizedBox(height: 32),

                // Action Buttons
                Row(
                  children: [
                    Expanded(child: _buildCancelButton(isTablet)),
                    SizedBox(width: 12),
                    Expanded(flex: 2, child: _buildCreateButton(isTablet)),
                  ],
                ),
                SizedBox(height: 32),
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
        SizedBox(width: 8),
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
    String? Function(String?)? validator,
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
        SizedBox(height: 8),
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
            contentPadding: EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
          ),
          validator:
              validator ??
              (value) {
                if (isRequired && (value == null || value.trim().isEmpty)) {
                  return 'This field is required';
                }
                return null;
              },
        ),
      ],
    );
  }

  void _onEmailChanged(String value) {
    final email = value.trim();
    String? error;
    if (email.isNotEmpty) {
      // Simple email validation
      final emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
      if (!emailPattern.hasMatch(email)) {
        error = 'Enter a valid email';
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
        SizedBox(height: 8),
        InkWell(
          onTap: _selectDate,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
        SizedBox(height: 8),
        InkWell(
          onTap: _selectTime,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
        SizedBox(height: 8),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 16),
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
        contentPadding: EdgeInsets.all(16),
      ),
    );
  }

  Widget _buildOffersBanner() {
    if (_activeOffers.isEmpty) {
      return SizedBox.shrink();
    }

    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withOpacity(0.3), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.local_offer, color: AppColors.primary, size: 20),
              SizedBox(width: 8),
              Text(
                'Special Offers',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          ..._activeOffers.take(3).map((offer) {
            return Padding(
              padding: EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      offer.title,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
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

  Widget _buildCreateButton(bool isTablet) {
    return SizedBox(
      height: isTablet ? 56.0 : 48.0,
      child: ElevatedButton(
        onPressed: _isSubmitting ? null : _submitReservation,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: _isSubmitting
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.white),
                ),
              )
            : Text(
                'Create Reservation',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
      ),
    );
  }
}
