// lib/screens/client/booking/booking_state.dart
//
// Иммутабельная модель состояния онлайн-записи.
//
// Используется для:
//   - Единого источника правды о выборе пользователя.
//   - Удобной передачи между шагами wizard.
//   - Тестирования логики (можно создавать копии с разными полями).

class BookingState {
  /// Выбранные услуги (полные объекты).
  final List<Map<String, dynamic>> selectedServices;

  /// Выбранный мастер (если пользователь выбрал его вручную через "Выбор мастеров").
  /// null — если путь был "Выбор услуг" (тогда мастер подбирается автоматически).
  final Map<String, dynamic>? selectedMaster;

  /// Маппинг serviceId -> masterId (для случаев, когда мастер назначен на конкретную услугу).
  final Map<int, int> serviceMasters;

  /// Выбранная дата визита.
  final DateTime? selectedDate;

  /// Выбранное время (строка вида "15:30").
  final String? selectedTime;

  /// Контактные данные клиента (заполняются на шаге contact).
  final Map<String, dynamic>? contactData;

  /// Согласие на обработку персональных данных.
  final bool agreeData;

  /// Согласие на маркетинговые рассылки.
  final bool agreeMarketing;

  const BookingState({
    this.selectedServices = const [],
    this.selectedMaster,
    this.serviceMasters = const {},
    this.selectedDate,
    this.selectedTime,
    this.contactData,
    this.agreeData = false,
    this.agreeMarketing = true,
  });

  /// Копия с заменой отдельных полей.
  BookingState copyWith({
    List<Map<String, dynamic>>? selectedServices,
    Map<String, dynamic>? selectedMaster,
    bool clearMaster = false,
    Map<int, int>? serviceMasters,
    DateTime? selectedDate,
    bool clearDate = false,
    String? selectedTime,
    bool clearTime = false,
    Map<String, dynamic>? contactData,
    bool? agreeData,
    bool? agreeMarketing,
  }) {
    return BookingState(
      selectedServices: selectedServices ?? this.selectedServices,
      selectedMaster: clearMaster ? null : (selectedMaster ?? this.selectedMaster),
      serviceMasters: serviceMasters ?? this.serviceMasters,
      selectedDate: clearDate ? null : (selectedDate ?? this.selectedDate),
      selectedTime: clearTime ? null : (selectedTime ?? this.selectedTime),
      contactData: contactData ?? this.contactData,
      agreeData: agreeData ?? this.agreeData,
      agreeMarketing: agreeMarketing ?? this.agreeMarketing,
    );
  }

  /// Есть ли выбранная дата и время (можно переходить к контактам).
  bool get hasDateTime => selectedDate != null && selectedTime != null;

  /// Суммарная стоимость всех выбранных услуг.
  int get totalPrice =>
      selectedServices.fold(0, (sum, s) => sum + ((s['price'] as num?)?.toInt() ?? 0));

  /// Суммарная длительность всех выбранных услуг (в минутах).
  int get totalDuration =>
      selectedServices.fold(0, (sum, s) => sum + ((s['duration'] as num?)?.toInt() ?? 0));

  @override
  String toString() =>
      'BookingState(services=${selectedServices.length}, master=${selectedMaster?['id']}, '
      'date=$selectedDate, time=$selectedTime)';
}
