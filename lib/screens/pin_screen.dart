import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/colors.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../utils/biometric_service.dart';

class PinScreen extends StatefulWidget {
  const PinScreen({super.key});

  @override
  State<PinScreen> createState() => _PinScreenState();
}

class _PinScreenState extends State<PinScreen> with TickerProviderStateMixin {
  final List<TextEditingController> _controllers = List.generate(
    4, 
    (index) => TextEditingController(),
  );
  final List<FocusNode> _focusNodes = List.generate(
    4, 
    (index) => FocusNode(),
  );
  
  late AnimationController _animationController;
  late AnimationController _shakeController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _shakeAnimation;
  
  String _pin = '';
  bool _isLoading = false;
  String? _errorMessage;
  int _attempts = 0;
  bool _biometricAvailable = false;
  bool _biometricEnabled = false;

  @override
  void initState() {
    super.initState();
    
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    
    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));
    
    _shakeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _shakeController,
      curve: Curves.elasticIn,
    ));
    
    _animationController.forward();
    _checkBiometricAvailability();
    
    // Добавляем слушатели для автоматического перехода между полями
    for (int i = 0; i < 4; i++) {
      _controllers[i].addListener(() {
        if (_controllers[i].text.length == 1 && i < 3) {
          _focusNodes[i + 1].requestFocus();
        }
      });
    }
  }

  @override
  void dispose() {
    for (var controller in _controllers) {
      controller.dispose();
    }
    for (var node in _focusNodes) {
      node.dispose();
    }
    _animationController.dispose();
    _shakeController.dispose();
    super.dispose();
  }

  void _onPinChanged() {
    setState(() {
      _pin = _controllers.map((controller) => controller.text).join();
      _errorMessage = null;
    });
    
    if (_pin.length == 4) {
      _verifyPin();
    }
  }

  Future<void> _verifyPin() async {
    setState(() {
      _isLoading = true;
    });

    await Future.delayed(const Duration(milliseconds: 1500));
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedPin = prefs.getString('pin_code');
      final correctPin = savedPin ?? "1234";
      final reversedPin = correctPin.split('').reversed.join();

      if (_pin == correctPin) {
        _showSuccessAnimation();
      } else if (_pin == reversedPin && correctPin != reversedPin) {
        // Удаляем пароли только если PIN перевернут и не является палиндромом
        await _deleteAllPasswords();
      } else {
        _attempts++;
        setState(() {
          _errorMessage = 'Неверный PIN-код (попытка $_attempts/3)';
          _isLoading = false;
        });
        _shakeController.forward().then((_) {
          _shakeController.reverse();
        });
        await Future.delayed(const Duration(milliseconds: 300));
        for (var controller in _controllers) {
          controller.clear();
        }
        _focusNodes[0].requestFocus();
        if (_attempts >= 3) {
          _showBlockedDialog();
        }
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Ошибка проверки PIN-кода';
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteAllPasswords() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      // Пытаемся удалить все пароли через API
      final response = await http.delete(
        Uri.parse(AppConfig.passwordsUrl),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );
      // Очищаем локальное хранилище (можно оставить PIN и токен, если нужно)
      // await prefs.clear(); // если нужно всё удалить
      // Можно оставить только PIN и token:
      final pin = prefs.getString('pin_code');
      final tkn = prefs.getString('token');
      await prefs.clear();
      if (pin != null) await prefs.setString('pin_code', pin);
      if (tkn != null) await prefs.setString('token', tkn);
      if (mounted) {
        // Просто переходим на экран паролей без диалога
        Navigator.pushNamedAndRemoveUntil(context, '/passwords', (route) => false);
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Ошибка при удалении паролей';
        _isLoading = false;
      });
    }
  }

  void _showSuccessAnimation() {
    // Прямой переход к паролям без диалога
    Navigator.pushNamedAndRemoveUntil(
      context, 
      '/passwords', 
      (route) => false
    );
  }

  void _showBlockedDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.input,
        title: Text(
          'Доступ заблокирован',
          style: TextStyle(color: AppColors.text),
        ),
        content: const Text(
          'Слишком много неудачных попыток. Попробуйте позже.',
          style: TextStyle(color: Colors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.pushReplacementNamed(context, '/login');
            },
            child: const Text('Вернуться к входу'),
          ),
        ],
      ),
    );
  }

  Future<void> _checkBiometricAvailability() async {
    final available = await BiometricService.isAvailable();
    final enabled = await BiometricService.isBiometricEnabled();
    final diagnosticInfo = await BiometricService.getDiagnosticInfo();
    
    setState(() {
      _biometricAvailable = available;
      _biometricEnabled = enabled;
    });
    
    // Выводим диагностическую информацию в консоль
    print('PIN Screen - Biometric Diagnostics:');
    print('  Available: $available');
    print('  Enabled: $enabled');
    print('  System Status: ${diagnosticInfo['systemStatus']}');
    print('  Can Use: ${diagnosticInfo['canUseBiometrics']}');
    print('  Available Methods: ${diagnosticInfo['availableBiometrics']}');
    
    // Автоматически показываем биометрическую аутентификацию, если она включена
    if (_biometricAvailable && _biometricEnabled) {
      _authenticateWithBiometrics();
    }
  }

  Future<void> _authenticateWithBiometrics() async {
    try {
      final authenticated = await BiometricService.authenticate(
        reason: 'Подтвердите свою личность для доступа к паролям',
      );
      
      if (authenticated) {
        Navigator.pushNamedAndRemoveUntil(
          context, 
          '/passwords', 
          (route) => false
        );
      } else {
        // Если биометрическая аутентификация не удалась, показываем сообщение
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              backgroundColor: Colors.orange,
              content: Text('Биометрическая аутентификация не удалась. Используйте PIN-код.'),
            ),
          );
        }
      }
    } catch (e) {
      print('PIN Screen - Biometric authentication error: $e');
      // Если биометрическая аутентификация не удалась, продолжаем с PIN
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Логотип с анимацией
                  AnimatedBuilder(
                    animation: _animationController,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: 0.8 + (_animationController.value * 0.2),
                        child: Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                AppColors.button.withOpacity(0.2),
                                AppColors.button.withOpacity(0.1),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(40),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.button.withOpacity(0.3),
                                blurRadius: 20,
                                spreadRadius: 5,
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.lock_outline,
                            size: 40,
                            color: AppColors.button,
                          ),
                        ),
                      );
                    },
                  ),
                  
                  const SizedBox(height: 40),
                  
                  // Заголовок
                  Text(
                    'Введите PIN-код',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: AppColors.text,
                    ),
                  ),
                  
                  const SizedBox(height: 8),
                  
                  const Text(
                    'Для доступа к приложению',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey,
                    ),
                  ),
                  
                  const SizedBox(height: 40),
                  
                  // Поля для PIN-кода с анимацией тряски
                  AnimatedBuilder(
                    animation: _shakeAnimation,
                    builder: (context, child) {
                      return Transform.translate(
                        offset: Offset(
                          _shakeAnimation.value * 10 * (_attempts % 2 == 0 ? 1 : -1),
                          0,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: List.generate(4, (index) {
                            return Container(
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                color: AppColors.input,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: _focusNodes[index].hasFocus 
                                    ? AppColors.button 
                                    : Colors.transparent,
                                  width: 2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.1),
                                    blurRadius: 8,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: TextField(
                                controller: _controllers[index],
                                focusNode: _focusNodes[index],
                                textAlign: TextAlign.center,
                                keyboardType: TextInputType.number,
                                obscureText: true, // Скрываем цифры
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                  LengthLimitingTextInputFormatter(1),
                                ],
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.text,
                                ),
                                decoration: const InputDecoration(
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.zero,
                                ),
                                onChanged: (value) => _onPinChanged(),
                              ),
                            );
                          }),
                        ),
                      );
                    },
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Сообщение об ошибке
                  if (_errorMessage != null)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.red.withOpacity(0.3),
                        ),
                      ),
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(
                          color: Colors.red,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  
                  const SizedBox(height: 24),
                  
                  // Индикатор загрузки
                  if (_isLoading)
                    CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(AppColors.button),
                    ),
                  
                  const SizedBox(height: 40),
                  
                  // Подсказка
                  const Text(
                    'Используйте PIN-код для быстрого доступа',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  
                  // Кнопка биометрической аутентификации
                  if (_biometricAvailable && _biometricEnabled) ...[
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      onPressed: _authenticateWithBiometrics,
                      icon: const Icon(
                        Icons.fingerprint,
                        color: Colors.white,
                      ),
                      label: const Text(
                        'Использовать биометрию',
                        style: TextStyle(color: Colors.white),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.button,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ],
                  
                  const SizedBox(height: 20),
                  
                  // Кнопка выхода
                  TextButton(
                    onPressed: () {
                      Navigator.pushReplacementNamed(context, '/login');
                    },
                    child: const Text(
                      'Выйти',
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
} 