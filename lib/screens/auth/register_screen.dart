import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/api_service.dart';
import 'package:flutter/gestures.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../utils/phone_formatter.dart';
import 'otp_screen.dart';

class RegisterScreen extends StatefulWidget {
  final String identifier;
  final String type;
  final Map<String, String>? prefillData;
  
  const RegisterScreen({
    super.key,
    required this.identifier,
    required this.type,
    this.prefillData,
  });

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  bool _termsAccepted = false;
  bool _newsletterAccepted = true;
  bool _isLoading = false;
  String? _error;
  String _countryCode = '7';
  String _countryDial = '+7';
  String _countryFlag = '🇷🇺';

  static const String _consentText = 'Настоящим в соответствии с Федеральным законом № 152-ФЗ «О персональных данных» от 27.07.2006 года свободно, своей волей и в своём интересе выражаю своё безусловное согласие на обработку моих персональных данных ИП Рощин Александр Александрович, зарегистрированным в соответствии с законодательством РФ по адресу: Брянская область, Почепский район, г. Почеп, ул. Стародубская, д. 17, кв. 14 (далее — Оператор).\n\nПерсональные данные — любая информация, относящаяся к определённому или определяемому на основании такой информации физическому лицу.\n\nНастоящее Согласие выдано мною на обработку следующих персональных данных:\n\nфамилия, имя Клиента;\nадрес электронной почты (e-mail) Клиента;\nномер телефона Клиента;\n\nСогласие дано Оператору для совершения следующих действий с моими персональными данными с использованием средств автоматизации и/или без использования таких средств: сбор, систематизация, накопление, хранение, уточнение (обновление, изменение), использование для указанных ниже целей, а также осуществление любых иных действий, предусмотренных действующим законодательством РФ как неавтоматизированными, так и автоматизированными способами.\n\nДанное согласие даётся Оператору для обработки моих персональных данных в целях продажи товаров, а также сбора информации для дальнейшего осуществления услуг (продвижение товаров, работ, услуг на рынке).\n\nНастоящее согласие действует до момента его отзыва путём направления соответствующего обращения. Либо срок хранения составляет 10 лет.\n\nВ случае отзыва согласия на обработку персональных данных Оператор вправе продолжить обработку персональных данных без моего согласия при наличии оснований, указанных в пунктах 2 – 11 части 1 статьи 6, части 2 статьи 10 и части 2 статьи 11 Федерального закона №152-ФЗ «О персональных данных» от 26.06.2006 г.';

  final List<Map<String, dynamic>> _countries = [
    {'code': 'ru', 'dial_code': '7', 'flag': '🇷🇺', 'name': 'Россия', 'max_digits': 10},
    {'code': 'by', 'dial_code': '375', 'flag': '🇧🇾', 'name': 'Беларусь', 'max_digits': 9},
    {'code': 'kz', 'dial_code': '7', 'flag': '🇰🇿', 'name': 'Казахстан', 'max_digits': 10},
    {'code': 'ua', 'dial_code': '380', 'flag': '🇺🇦', 'name': 'Украина', 'max_digits': 9},
    {'code': 'de', 'dial_code': '49', 'flag': '🇩🇪', 'name': 'Германия', 'max_digits': 11},
    {'code': 'us', 'dial_code': '1', 'flag': '🇺🇸', 'name': 'США', 'max_digits': 10},
  ];

  int get _maxDigits {
    final country = _countries.firstWhere((c) => c['dial_code'] == _countryCode, orElse: () => _countries.first);
    return country['max_digits'] as int;
  }

  @override
  void initState() {
    super.initState();
    
    // Заполняем сохранённые данные
    if (widget.prefillData != null) {
      _firstNameController.text = widget.prefillData!['first_name'] ?? '';
      _lastNameController.text = widget.prefillData!['last_name'] ?? '';
      _emailController.text = widget.prefillData!['email'] ?? '';
      
      if (widget.prefillData!['phone']?.isNotEmpty ?? false) {
        String phone = widget.prefillData!['phone']!.replaceAll(RegExp(r'\D'), '');
        if (phone.startsWith('7') && phone.length > 10) phone = phone.substring(1);
        if (phone.startsWith('375')) phone = phone.substring(3);
        if (phone.length > _maxDigits) phone = phone.substring(0, _maxDigits);
        _phoneController.text = phone;
        _onPhoneChanged(phone);
      }
    }
    
    if (widget.type == 'phone' && widget.prefillData == null) {
      String phone = widget.identifier.replaceAll(RegExp(r'\D'), '');
      if (phone.startsWith('7') && phone.length > 10) phone = phone.substring(1);
      _phoneController.text = phone;
      _onPhoneChanged(phone);
    } else if (widget.type == 'email' && widget.prefillData == null) {
      _emailController.text = widget.identifier;
    }
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  bool get _isValid {
    final isPhone = widget.type == 'phone';
    return _firstNameController.text.trim().length >= 2 &&
        _lastNameController.text.trim().length >= 2 &&
        _termsAccepted &&
        (isPhone ? _isEmailValid() : _isPhoneValid());
  }

  bool _isEmailValid() => RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(_emailController.text.trim());
  bool _isPhoneValid() => PhoneFormatter.isValid(_phoneController.text, _maxDigits);

  String _cleanPhone() => PhoneFormatter.normalizeForApi(_phoneController.text, '+$_countryCode');

  void _onPhoneChanged(String value) {
    String digits = PhoneFormatter.clean(value);
    if (digits.length > _maxDigits) digits = digits.substring(0, _maxDigits);
    String formatted = PhoneFormatter.formatRu(digits);
    _phoneController.value = TextEditingValue(text: formatted, selection: TextSelection.collapsed(offset: formatted.length));
    setState(() => _error = null);
  }

  void _register() async {
    if (_firstNameController.text.trim().length < 2) {
      setState(() => _error = 'Введите имя (минимум 2 символа)');
      return;
    }
    if (_lastNameController.text.trim().length < 2) {
      setState(() => _error = 'Введите фамилию (минимум 2 символа)');
      return;
    }
    if (!_isEmailValid()) {
      setState(() => _error = 'Введите корректный email');
      return;
    }
    if (!_isPhoneValid()) {
      setState(() => _error = 'Введите номер телефона полностью');
      return;
    }
    if (!_termsAccepted) {
      setState(() => _error = 'Примите условия обработки данных');
      return;
    }

    setState(() { _isLoading = true; _error = null; });

    try {
      final phone = _cleanPhone();
      final email = _emailController.text.trim();

      // Проверяем телефон
      final checkPhone = await ApiService.checkUser(phone, 'phone');
      if (checkPhone['success'] == true && checkPhone['data']?['exists'] == true) {
        if (mounted) {
          setState(() {
            _error = 'Пользователь с таким телефоном уже существует';
            _isLoading = false;
          });
        }
        return;
      }

      // Проверяем email
      final checkEmail = await ApiService.checkUser(email, 'email');
      if (checkEmail['success'] == true && checkEmail['data']?['exists'] == true) {
        if (mounted) {
          setState(() {
            _error = 'Пользователь с таким email уже существует';
            _isLoading = false;
          });
        }
        return;
      }

      // Регистрация — отправка OTP, пользователь НЕ создаётся
      final result = await ApiService.register(
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
        email: email,
        phone: phone,
        subscribe: _newsletterAccepted,
        termsAccepted: _termsAccepted,
      );

      if (!mounted) return;

      if (result['success'] == true) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => OtpScreen(
              userId: 0,
              email: email,
              isRegistration: true,
              firstName: _firstNameController.text.trim(),
              lastName: _lastNameController.text.trim(),
              phone: phone,
            ),
          ),
        );
      } else {
        setState(() => _error = result['message'] ?? 'Ошибка регистрации');
      }
    } catch (e) {
      setState(() => _error = 'Ошибка соединения');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _extractCountryInfo(String phone) {
    if (phone.startsWith('375') || phone.startsWith('+375')) return '375|🇧🇾|+375';
    if (phone.startsWith('380') || phone.startsWith('+380')) return '380|🇺🇦|+380';
    if (phone.startsWith('7') || phone.startsWith('+7')) return '7|🇷🇺|+7';
    return '7|🇷🇺|+7';
  }

  void _showConsentPopup() {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Согласие на обработку персональных данных', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                  IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close, color: Colors.grey)),
                ],
              ),
              const SizedBox(height: 16),
              Flexible(
                child: SingleChildScrollView(
                  child: Text(_consentText, style: const TextStyle(fontSize: 13, height: 1.7, color: Color(0xFF333333))),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isPhone = widget.type == 'phone';
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Регистрация', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: Colors.grey[900]), textAlign: TextAlign.center),
                const SizedBox(height: 8),
                Text('Заполните данные для создания аккаунта', style: TextStyle(fontSize: 14, color: Colors.grey[600]), textAlign: TextAlign.center),
                const SizedBox(height: 28),
                _buildField(_firstNameController, 'Имя'),
                const SizedBox(height: 12),
                _buildField(_lastNameController, 'Фамилия'),
                const SizedBox(height: 12),
                _buildField(_emailController, 'Email', keyboardType: TextInputType.emailAddress),
                const SizedBox(height: 12),
                _buildPhoneField(),
                const SizedBox(height: 20),
                _buildConsentCheckbox(),
                const SizedBox(height: 12),
                _buildNewsletterCheckbox(),
                if (_error != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 13), textAlign: TextAlign.center)),
                const SizedBox(height: 24),
                SizedBox(height: 52, child: ElevatedButton(
                  onPressed: (_isValid && !_isLoading) ? _register : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFDD1847),
                    disabledBackgroundColor: const Color(0xFFDD1847),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: _isLoading
                      ? const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white,
                              ),
                            ),
                            SizedBox(width: 12),
                            Text(
                              'Отправка кода...',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        )
                      : const Text('Зарегистрироваться', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
                )),
                const SizedBox(height: 12),
                SizedBox(height: 52, child: OutlinedButton(onPressed: () => Navigator.pop(context), style: OutlinedButton.styleFrom(foregroundColor: Colors.grey[600], side: BorderSide(color: Colors.grey[300]!), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: const Text('Назад к входу', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)))),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildField(TextEditingController c, String hint, {TextInputType? keyboardType}) {
    return Container(
      decoration: BoxDecoration(color: const Color(0xFFF8F8F8), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE0E0E0))),
      child: TextField(controller: c, keyboardType: keyboardType, onChanged: (_) => setState(() {}), style: const TextStyle(fontSize: 16), decoration: InputDecoration(hintText: hint, hintStyle: const TextStyle(color: Colors.grey, fontSize: 16), border: InputBorder.none, contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16))),
    );
  }

  Widget _buildPhoneField() {
    return Container(
      decoration: BoxDecoration(color: const Color(0xFFF8F8F8), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE0E0E0))),
      child: Row(children: [
        GestureDetector(
          onTap: () => _showCountryPicker(),
          child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16), decoration: const BoxDecoration(border: Border(right: BorderSide(color: Color(0x1A000000), width: 1))), child: Row(children: [Text(_countryFlag, style: const TextStyle(fontSize: 20)), const SizedBox(width: 4), Text(_countryDial, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFF666666)))])),
        ),
        Expanded(child: TextField(controller: _phoneController, keyboardType: TextInputType.phone, inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d\s]'))], onChanged: _onPhoneChanged, style: const TextStyle(fontSize: 16), decoration: const InputDecoration(hintText: '987 654 32 10', hintStyle: TextStyle(color: Colors.grey, fontSize: 16), border: InputBorder.none, contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16)))),
      ]),
    );
  }

  Widget _buildConsentCheckbox() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 24, height: 24,
          child: Checkbox(value: _termsAccepted, onChanged: (v) => setState(() => _termsAccepted = v ?? false), activeColor: const Color(0xFFDD1847)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: GestureDetector(
            onTap: () => setState(() => _termsAccepted = !_termsAccepted),
            child: Text.rich(
              TextSpan(
                style: TextStyle(fontSize: 13, color: Colors.grey[600], height: 1.4),
                children: [
                  const TextSpan(text: 'Я принимаю '),
                  TextSpan(
                    text: 'условия обработки данных',
                    style: const TextStyle(color: Color(0xFFDD1847), decoration: TextDecoration.underline),
                    recognizer: TapGestureRecognizer()..onTap = () async {
                      final uri = Uri.parse('https://запись.бьютироща.рф/privacy');
                      try {
                        await launchUrl(uri, mode: LaunchMode.externalApplication);
                      } catch (_) {}
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNewsletterCheckbox() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 24, height: 24, child: Checkbox(value: _newsletterAccepted, onChanged: (v) => setState(() => _newsletterAccepted = v ?? false), activeColor: const Color(0xFFDD1847))),
        const SizedBox(width: 10),
        Expanded(child: Text('Согласен(а) получать информационную и рекламную рассылку', style: TextStyle(fontSize: 13, color: Colors.grey[600], height: 1.4))),
      ],
    );
  }

  void _showCountryPicker() {
    showModalBottomSheet(
      context: context, backgroundColor: Colors.white, isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => SafeArea(child: Padding(padding: const EdgeInsets.all(20), child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 16),
        Align(alignment: Alignment.centerLeft, child: Text('Выберите страну', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: Colors.grey[900]))),
        const SizedBox(height: 16),
        Flexible(child: ListView.builder(shrinkWrap: true, itemCount: _countries.length, itemBuilder: (_, i) {
          final c = _countries[i];
          return ListTile(
            leading: Text(c['flag'] as String, style: const TextStyle(fontSize: 28)),
            title: Text(c['name'] as String, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            trailing: Text('+${c['dial_code']}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF666666))),
            onTap: () { setState(() { _countryCode = c['dial_code'] as String; _countryDial = '+${c['dial_code']}'; _countryFlag = c['flag'] as String; _phoneController.clear(); }); Navigator.pop(ctx); },
          );
        })),
      ]))),
    );
  }
}